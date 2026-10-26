// supabase/functions/send-debt-reminders/index.ts
//
// Runs once daily via pg_cron (see supabase/setup/webhooks_and_cron.sql).
// Gets every pairwise net debt from the database function
// debts_for_reminders() — the SAME balance math the app uses (group_debts,
// supabase/migrations/20261027140000_money_ledger.sql) — and sends a
// reminder push + logs an in-app notification for any debt that:
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
    // One query: every open debt in every non-archived group, already
    // netted per pair, plus how long it has existed (`since`).
    const { data: debts, error } = await supabase.rpc("debts_for_reminders");
    if (error) throw error;
    if (!debts) return new Response(JSON.stringify({ sent: 0 }), { status: 200 });

    let sent = 0;
    const now = Date.now();

    for (const d of debts as any[]) {
      const ageDays = (now - new Date(d.since).getTime()) / (1000 * 60 * 60 * 24);
      if (ageDays < REMINDER_MIN_AGE_DAYS) continue;

      const { data: lastSent } = await supabase.from("debt_reminders_sent")
        .select("last_reminded_at")
        .eq("group_id", d.group_id)
        .eq("debtor_id", d.debtor_id)
        .eq("creditor_id", d.creditor_id)
        .maybeSingle();

      if (lastSent) {
        const daysSince =
          (now - new Date(lastSent.last_reminded_at).getTime()) / (1000 * 60 * 60 * 24);
        if (daysSince < REMINDER_COOLDOWN_DAYS) continue;
      }

      const { data: debtorProfile } = await supabase.from("profiles")
        .select("fcm_token, notify_debt_reminders").eq("id", d.debtor_id).maybeSingle();
      const { data: creditorProfile } = await supabase.from("profiles")
        .select("full_name").eq("id", d.creditor_id).maybeSingle();

      if (debtorProfile?.notify_debt_reminders === false) continue;

      const title = d.group_name;
      const body = `Reminder: you owe ${creditorProfile?.full_name ?? "someone"} ${d.currency} ${Number(d.amount).toFixed(2)}`;

      await supabase.from("notifications").insert({
        user_id: d.debtor_id,
        type: "debt_reminder",
        title,
        body,
        group_id: d.group_id,
      });

      if (debtorProfile?.fcm_token) {
        await sendFcm(debtorProfile.fcm_token, title, body, {
          type: "debt_reminder",
          group_id: d.group_id,
        });
        sent++;
      }

      await supabase.from("debt_reminders_sent").upsert({
        group_id: d.group_id,
        debtor_id: d.debtor_id,
        creditor_id: d.creditor_id,
        last_reminded_at: new Date().toISOString(),
      });
    }

    return new Response(JSON.stringify({ sent }), { status: 200 });
  } catch (e) {
    console.error("Debt reminder function error:", e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});