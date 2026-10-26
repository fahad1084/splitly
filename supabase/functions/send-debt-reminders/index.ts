// supabase/functions/send-debt-reminders/index.ts
//
// Runs once daily via pg_cron (see debt_reminders_migration.sql).
// Computes pairwise net debts across every group (mirroring the client's
// balances_controller.dart logic), and sends a reminder push + logs an
// in-app notification for any debt that:
//   - has existed for at least 3 days (avoids nagging right after an
//     expense is added), and
//   - hasn't already had a reminder sent in the last 7 days.

import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")!;
const FIREBASE_CLIENT_EMAIL = Deno.env.get("FIREBASE_CLIENT_EMAIL")!;
const FIREBASE_PRIVATE_KEY = Deno.env.get("FIREBASE_PRIVATE_KEY")!.replace(/\\n/g, "\n");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WEBHOOK_SECRET = Deno.env.get("WEBHOOK_SECRET")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const REMINDER_MIN_AGE_DAYS = 3;
const REMINDER_COOLDOWN_DAYS = 7;

async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: FIREBASE_CLIENT_EMAIL,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const b64url = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const unsigned = `${b64url(header)}.${b64url(claimSet)}`;
  const pem = FIREBASE_PRIVATE_KEY
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const keyBytes = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8", keyBytes.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", cryptoKey, new TextEncoder().encode(unsigned),
  );
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const jwt = `${unsigned}.${sigB64}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const data = await res.json();
  if (!data.access_token) throw new Error("Failed to get access token");
  return data.access_token;
}

async function sendFcm(token: string, title: string, body: string, data: Record<string, string>) {
  const accessToken = await getAccessToken();
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: { token, data: { ...data, title, body }, android: { priority: "high" } },
      }),
    },
  );
  if (!res.ok) console.error("FCM send error:", await res.text());
}

serve(async (req) => {
  if (req.headers.get("x-webhook-secret") !== WEBHOOK_SECRET) {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    const { data: groups } = await supabase.from("groups")
      .select("id, name, currency").eq("is_archived", false);
    if (!groups) return new Response(JSON.stringify({ sent: 0 }), { status: 200 });

    let sent = 0;

    for (const group of groups) {
      const { data: expenses } = await supabase.from("expenses")
        .select("id, paid_by, created_at").eq("group_id", group.id);
      if (!expenses || expenses.length === 0) continue;

      const expenseIds = expenses.map((e: any) => e.id);
      const { data: splits } = await supabase.from("expense_splits")
        .select("expense_id, user_id, amount_owed, is_settled")
        .in("expense_id", expenseIds)
        .eq("is_settled", false);
      if (!splits || splits.length === 0) continue;

      const expenseById: Record<string, any> = {};
      for (const e of expenses) expenseById[e.id] = e;

      // ledger[debtor][creditor] = { amount, oldestCreatedAt }
      const ledger: Record<string, Record<string, { amount: number; oldest: string }>> = {};

      for (const s of splits) {
        const expense = expenseById[s.expense_id];
        if (!expense) continue;
        const debtor = s.user_id;
        const creditor = expense.paid_by;
        if (debtor === creditor) continue;

        ledger[debtor] ??= {};
        const existing = ledger[debtor][creditor];
        const amount = (existing?.amount ?? 0) + Number(s.amount_owed);
        const oldest = existing
          ? (expense.created_at < existing.oldest ? expense.created_at : existing.oldest)
          : expense.created_at;
        ledger[debtor][creditor] = { amount, oldest };
      }

      const seenPairs = new Set<string>();
      const now = Date.now();

      for (const a of Object.keys(ledger)) {
        for (const b of Object.keys(ledger[a])) {
          const pairKey = [a, b].sort().join("|");
          if (seenPairs.has(pairKey)) continue;
          seenPairs.add(pairKey);

          const aOwesB = ledger[a]?.[b]?.amount ?? 0;
          const bOwesA = ledger[b]?.[a]?.amount ?? 0;
          const net = aOwesB - bOwesA;
          if (Math.abs(net) < 0.01) continue;

          const debtorId = net > 0 ? a : b;
          const creditorId = net > 0 ? b : a;
          const amount = Math.round(Math.abs(net) * 100) / 100;
          const oldest = net > 0 ? ledger[a][b].oldest : ledger[b][a].oldest;

          const ageDays = (now - new Date(oldest).getTime()) / (1000 * 60 * 60 * 24);
          if (ageDays < REMINDER_MIN_AGE_DAYS) continue;

          const { data: lastSent } = await supabase.from("debt_reminders_sent")
            .select("last_reminded_at")
            .eq("group_id", group.id)
            .eq("debtor_id", debtorId)
            .eq("creditor_id", creditorId)
            .maybeSingle();

          if (lastSent) {
            const daysSince =
              (now - new Date(lastSent.last_reminded_at).getTime()) / (1000 * 60 * 60 * 24);
            if (daysSince < REMINDER_COOLDOWN_DAYS) continue;
          }

          const { data: debtorProfile } = await supabase.from("profiles")
            .select("fcm_token, notify_debt_reminders").eq("id", debtorId).maybeSingle();
          const { data: creditorProfile } = await supabase.from("profiles")
            .select("full_name").eq("id", creditorId).maybeSingle();

          if (debtorProfile?.notify_debt_reminders === false) continue;

          const title = group.name;
          const body = `Reminder: you owe ${creditorProfile?.full_name ?? "someone"} ${group.currency} ${amount}`;

          await supabase.from("notifications").insert({
            user_id: debtorId,
            type: "debt_reminder",
            title,
            body,
            group_id: group.id,
          });

          if (debtorProfile?.fcm_token) {
            await sendFcm(debtorProfile.fcm_token, title, body, {
              type: "debt_reminder",
              group_id: group.id,
            });
            sent++;
          }

          await supabase.from("debt_reminders_sent").upsert({
            group_id: group.id,
            debtor_id: debtorId,
            creditor_id: creditorId,
            last_reminded_at: new Date().toISOString(),
          });
        }
      }
    }

    return new Response(JSON.stringify({ sent }), { status: 200 });
  } catch (e) {
    console.error("Debt reminder function error:", e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});