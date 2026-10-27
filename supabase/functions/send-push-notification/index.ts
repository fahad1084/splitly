// supabase/functions/send-push-notification/index.ts
//
// Triggered by Supabase Database Webhooks on INSERT into:
//   messages, expenses, settlements, group_members
// and by the settlements_update_push trigger (migration
// 20261029000000_settlement_update_push.sql) when a pending payment is
// confirmed or cancelled.
//
// Sends a push notification (via FCM v1 API using a Firebase service
// account) to every OTHER member of the relevant group who has an
// fcm_token saved on their profile.

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

// ── Google OAuth token, cached ─────────────────────────────────────────────
// A token is valid for 1 hour; keep it for 55 minutes so a warm function
// instance doesn't sign a new JWT for every push.
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
    "pkcs8",
    keyBytes.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsigned),
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
) {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          // Data-only message (no top-level "notification" key) — this
          // stops Android/iOS from auto-displaying a bare-bones system
          // notification. Instead the client builds it manually via
          // flutter_local_notifications, giving full control over the
          // large icon (sender's avatar, WhatsApp-style).
          data: { ...data, title, body },
          android: { priority: "high" },
        },
      }),
    },
  );
  if (!res.ok) {
    // Token rejected (e.g. revoked) → don't reuse it for the next push
    if (res.status === 401) cachedToken = null;
    console.error("FCM send error:", await res.text());
  }
}

serve(async (req) => {
  // Simple shared-secret check so this endpoint can't be spammed by
  // strangers even though it has to be publicly callable (webhooks don't
  // send a Supabase user JWT).
  if (req.headers.get("x-webhook-secret") !== WEBHOOK_SECRET) {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    const payload = await req.json();
    const table = payload.table as string;
    const record = payload.record as Record<string, any>;

    let groupId: string | null = null;
    let actorId: string | null = null;
    let title = "";
    let body = "";
    let notificationType = "";
    let dataPayload: Record<string, string> = {};
    // Confirm/cancel: the RPC already wrote the in-app notification
    // (_notify_settlement), so only the push is sent here.
    let pushOnly = false;

    if (table === "messages") {
      groupId = record.group_id;
      actorId = record.sender_id;
      notificationType = "message";
      const { data: sender } = await supabase.from("profiles")
        .select("full_name, avatar_url").eq("id", actorId).maybeSingle();
      const { data: group } = await supabase.from("groups")
        .select("name").eq("id", groupId).maybeSingle();
      title = group?.name ?? "New message";
      body = `${sender?.full_name ?? "Someone"}: ${record.content ?? "Sent an attachment"}`;
      dataPayload = {
        type: "message",
        group_id: groupId ?? "",
        avatar_url: sender?.avatar_url ?? "",
      };
    } else if (table === "expenses") {
      groupId = record.group_id;
      actorId = record.paid_by;
      notificationType = "expense";
      const { data: payer } = await supabase.from("profiles")
        .select("full_name, avatar_url").eq("id", actorId).maybeSingle();
      const { data: group } = await supabase.from("groups")
        .select("name, currency").eq("id", groupId).maybeSingle();
      title = group?.name ?? "New expense";
      body = `${payer?.full_name ?? "Someone"} added "${record.title}" — ${formatMoney(group?.currency ?? "", record.amount)}`;
      dataPayload = {
        type: "expense",
        group_id: groupId ?? "",
        avatar_url: payer?.avatar_url ?? "",
      };
    } else if (table === "settlements") {
      // INSERT from record_settlement():
      //  - 'pending'   — the debtor says "I paid" → ask the receiver to confirm
      //  - 'confirmed' — the receiver says "I got paid" → tell the debtor
      // UPDATE from confirm_settlement() / cancel_settlement() (pending →
      // confirmed / cancelled) → tell the other person.
      const isUpdate = payload.type === "UPDATE";
      const oldStatus = (payload.old_record as Record<string, any> | null)?.status;
      if (isUpdate) {
        if (oldStatus !== "pending" ||
            (record.status !== "confirmed" && record.status !== "cancelled")) {
          return new Response(JSON.stringify({ skipped: true }), { status: 200 });
        }
        pushOnly = true;
      } else if (record.status !== "pending" && record.status !== "confirmed") {
        return new Response(JSON.stringify({ skipped: true }), { status: 200 });
      }
      groupId = record.group_id;
      // Who did it. The other person (paid_by / paid_to) gets the push.
      actorId = !isUpdate
        ? (record.created_by ?? record.paid_by)
        : record.status === "confirmed"
        ? record.paid_to
        : record.cancelled_by;
      notificationType = "settlement";
      const { data: fromP } = await supabase.from("profiles")
        .select("full_name, avatar_url").eq("id", record.paid_by).maybeSingle();
      const { data: toP } = await supabase.from("profiles")
        .select("full_name, avatar_url").eq("id", record.paid_to).maybeSingle();
      const { data: group } = await supabase.from("groups")
        .select("name, currency").eq("id", groupId).maybeSingle();
      const money = formatMoney(group?.currency ?? "", record.amount);
      title = group?.name ?? "Settlement";
      const actorName =
        (actorId === record.paid_to ? toP?.full_name : fromP?.full_name) ?? "Someone";
      if (!isUpdate) {
        body = record.status === "pending"
          ? `${fromP?.full_name ?? "Someone"} says they paid you ${money}. Please confirm.`
          : `${toP?.full_name ?? "Someone"} recorded your payment of ${money}`;
      } else {
        body = record.status === "confirmed"
          ? `${actorName} confirmed your payment of ${money}`
          : `${actorName} cancelled the payment of ${money}`;
      }
      dataPayload = {
        type: "settlement",
        group_id: groupId ?? "",
        avatar_url: (actorId === record.paid_to ? toP?.avatar_url : fromP?.avatar_url) ?? "",
      };
    } else if (table === "notifications" && record.type === "recurring_skipped") {
      // From the notifications_push trigger: the daily job skipped a copy
      // of a recurring expense. The row IS the in-app notification, so
      // only the push goes to its owner (the expense's creator).
      groupId = record.group_id;
      notificationType = "recurring_skipped";
      pushOnly = true;
      title = record.title;
      body = record.body;
      dataPayload = {
        type: "recurring_skipped",
        group_id: groupId ?? "",
      };
    } else if (table === "group_members") {
      groupId = record.group_id;
      actorId = record.user_id;
      notificationType = "member_joined";
      const { data: joiner } = await supabase.from("profiles")
        .select("full_name, avatar_url").eq("id", actorId).maybeSingle();
      const { data: group } = await supabase.from("groups")
        .select("name").eq("id", groupId).maybeSingle();
      title = group?.name ?? "New member";
      body = `${joiner?.full_name ?? "Someone"} joined the group`;
      dataPayload = {
        type: "member_joined",
        group_id: groupId ?? "",
        avatar_url: joiner?.avatar_url ?? "",
      };
    } else {
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }

    if (!groupId) {
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }

    const prefColumn: Record<string, string> = {
      message: "notify_messages",
      expense: "notify_expenses",
      settlement: "notify_settlements",
      member_joined: "notify_members",
      recurring_skipped: "notify_expenses",
    };

    // Recipients depend on the event type:
    // - message / member_joined → the whole group (excluding the actor)
    // - expense → only the people actually included in that expense's split
    // - settlement → only the other party in that specific settlement
    let recipientIds: string[];

    if (notificationType === "expense") {
      const { data: splitRows } = await supabase
        .from("expense_splits")
        .select("user_id")
        .eq("expense_id", record.id);
      recipientIds = (splitRows ?? [])
        .map((r: any) => r.user_id as string)
        .filter((id: string) => id !== actorId);
    } else if (notificationType === "settlement") {
      recipientIds = [record.paid_by, record.paid_to]
        .filter((id: string) => id && id !== actorId);
    } else if (notificationType === "recurring_skipped") {
      recipientIds = [record.user_id];
    } else {
      const { data: allMembers } = await supabase
        .from("group_members")
        .select("user_id")
        .eq("group_id", groupId);
      recipientIds = (allMembers ?? [])
        .map((r: any) => r.user_id as string)
        .filter((id: string) => id !== actorId);
    }

    // De-duplicate (e.g. a person could appear twice in edge cases)
    recipientIds = [...new Set(recipientIds)];

    if (recipientIds.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    const { data: members } = await supabase
      .from("profiles")
      .select(`id, fcm_token, ${prefColumn[notificationType]}`)
      .in("id", recipientIds);

    if (!members) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    const historyRows: Record<string, unknown>[] = [];
    const tokens: string[] = [];

    for (const m of members as any[]) {
      const prefEnabled = m[prefColumn[notificationType]] ?? true;
      if (!prefEnabled) continue; // this user muted this notification category

      // Always log to history (in-app inbox), even if they have no push
      // token (e.g. denied permission) — they can still see it in-app.
      if (!pushOnly) {
        historyRows.push({
          user_id: m.id,
          type: notificationType,
          title,
          body,
          group_id: groupId,
          entity_id: record.id ?? null,
        });
      }

      if (m.fcm_token) tokens.push(m.fcm_token);
    }

    // One OAuth token for all, and all pushes at the same time
    if (tokens.length > 0) {
      const accessToken = await getAccessToken();
      // allSettled: one bad token must not stop the others (or the history)
      await Promise.allSettled(
        tokens.map((t) => sendFcm(accessToken, t, title, body, dataPayload)),
      );
    }
    const sent = tokens.length;

    if (historyRows.length > 0) {
      await supabase.from("notifications").insert(historyRows);
    }

    return new Response(JSON.stringify({ sent, logged: historyRows.length }), { status: 200 });
  } catch (e) {
    console.error("Edge function error:", e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});