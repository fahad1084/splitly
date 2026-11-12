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
//
// Built to scale: 3 queries in total (debts, reminder history, profiles),
// one insert for all notifications, one upsert for all reminder dates, and
// the pushes go out in parallel batches with ONE cached Google token.

import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")!;
const FIREBASE_CLIENT_EMAIL = Deno.env.get("FIREBASE_CLIENT_EMAIL")!;
const FIREBASE_PRIVATE_KEY = Deno.env.get("FIREBASE_PRIVATE_KEY")!.replace(/\\n/g, "\n");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WEBHOOK_SECRET = Deno.env.get("WEBHOOK_SECRET")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// "PKR 1,250.00" — same look as the app (2 decimals, thousands separators)
function formatMoney(currency: string, amount: unknown): string {
  const n = Number(amount).toLocaleString("en-US", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  return `${currency} ${n}`.trim();
}

const REMINDER_MIN_AGE_DAYS = 3;
const REMINDER_COOLDOWN_DAYS = 7;
const DAY_MS = 1000 * 60 * 60 * 24;
// Pushes sent at the same time; the next batch starts when one is done
const PUSH_BATCH_SIZE = 50;
// Rows per database request (keeps each request small)
const DB_CHUNK = 500;

// ── Google OAuth token, cached ─────────────────────────────────────────────
// Same as send-push-notification: a token is valid for 1 hour; keep it for
// 55 minutes so the whole run (and a warm instance) signs only one JWT.
const TOKEN_CACHE_MS = 55 * 60 * 1000;
let cachedToken: { token: string; expiresAt: number } | null = null;

async function getAccessToken(): Promise<string> {
  if (cachedToken && Date.now() < cachedToken.expiresAt) {
    return cachedToken.token;
  }
  const token = await fetchAccessToken();
  cachedToken = { token, expiresAt: Date.now() + TOKEN_CACHE_MS };
  return token;
}

// ── Build a signed JWT (RS256) and exchange it for an OAuth2 access token ──
async function fetchAccessToken(): Promise<string> {
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
  if (!data.access_token) {
    console.error("OAuth token error:", data);
    throw new Error("Failed to get Google OAuth access token");
  }
  return data.access_token;
}

async function sendFcm(
  accessToken: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<boolean> {
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
  if (!res.ok) {
    // Token rejected (e.g. revoked) → don't reuse it for the next run
    if (res.status === 401) cachedToken = null;
    console.error("FCM send error:", await res.text());
    return false;
  }
  return true;
}

function chunks<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

serve(async (req) => {
  if (req.headers.get("x-webhook-secret") !== WEBHOOK_SECRET) {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    // 1. Every open debt in every non-archived group, already netted per
    //    pair, plus how long it has existed (`since`). Keep the old ones.
    const { data: debts, error } = await supabase.rpc("debts_for_reminders");
    if (error) throw error;
    const now = Date.now();
    const old = ((debts ?? []) as any[])
      .filter((d) => (now - new Date(d.since).getTime()) / DAY_MS >= REMINDER_MIN_AGE_DAYS);
    if (old.length === 0) {
      return new Response(JSON.stringify({ reminders: 0, sent: 0 }), { status: 200 });
    }

    // 2. When each pair was last reminded (one query per 500 groups)
    const groupIds = [...new Set(old.map((d) => d.group_id as string))];
    const lastSent = new Map<string, number>();
    for (const ids of chunks(groupIds, DB_CHUNK)) {
      const { data, error } = await supabase.from("debt_reminders_sent")
        .select("group_id, debtor_id, creditor_id, last_reminded_at")
        .in("group_id", ids);
      if (error) throw error;
      for (const r of data ?? []) {
        lastSent.set(`${r.group_id}|${r.debtor_id}|${r.creditor_id}`,
          new Date(r.last_reminded_at).getTime());
      }
    }
    const due = old.filter((d) => {
      const at = lastSent.get(`${d.group_id}|${d.debtor_id}|${d.creditor_id}`);
      return at === undefined || (now - at) / DAY_MS >= REMINDER_COOLDOWN_DAYS;
    });

    // 3. Debtors' push token + setting, creditors' names (one query per 500)
    const userIds = [...new Set(due.flatMap((d) => [d.debtor_id, d.creditor_id]))];
    const profiles = new Map<string, any>();
    for (const ids of chunks(userIds, DB_CHUNK)) {
      const { data, error } = await supabase.from("profiles")
        .select("id, full_name, fcm_token, notify_debt_reminders")
        .in("id", ids);
      if (error) throw error;
      for (const p of data ?? []) profiles.set(p.id, p);
    }

    // Respect "mute debt reminders"
    const reminders = due
      .filter((d) => profiles.get(d.debtor_id)?.notify_debt_reminders !== false)
      .map((d) => ({
        debt: d,
        title: d.group_name as string,
        body: `Reminder: you owe ${profiles.get(d.creditor_id)?.full_name ?? "someone"} ${
          formatMoney(d.currency, d.amount)}`,
        fcmToken: profiles.get(d.debtor_id)?.fcm_token as string | null,
      }));

    // 4. In-app notifications + "reminded today", one write each per 500
    const stamp = new Date().toISOString();
    for (const part of chunks(reminders, DB_CHUNK)) {
      const { error: e1 } = await supabase.from("notifications").insert(part.map((r) => ({
        user_id: r.debt.debtor_id,
        type: "debt_reminder",
        title: r.title,
        body: r.body,
        group_id: r.debt.group_id,
      })));
      if (e1) throw e1;
      const { error: e2 } = await supabase.from("debt_reminders_sent").upsert(part.map((r) => ({
        group_id: r.debt.group_id,
        debtor_id: r.debt.debtor_id,
        creditor_id: r.debt.creditor_id,
        last_reminded_at: stamp,
      })));
      if (e2) throw e2;
    }

    // 5. Pushes: one token, parallel batches; one bad device token never
    //    stops the others (allSettled)
    const withToken = reminders.filter((r) => r.fcmToken);
    let sent = 0;
    if (withToken.length > 0) {
      const accessToken = await getAccessToken();
      for (const batch of chunks(withToken, PUSH_BATCH_SIZE)) {
        const results = await Promise.allSettled(batch.map((r) =>
          sendFcm(accessToken, r.fcmToken!, r.title, r.body, {
            type: "debt_reminder",
            group_id: r.debt.group_id,
          })
        ));
        sent += results.filter((x) => x.status === "fulfilled" && x.value).length;
      }
    }

    return new Response(JSON.stringify({ reminders: reminders.length, sent }), { status: 200 });
  } catch (e) {
    // Details only in the function log, not in the response
    console.error("Debt reminder function error:", e);
    return new Response(JSON.stringify({ error: "internal error" }), { status: 500 });
  }
});
