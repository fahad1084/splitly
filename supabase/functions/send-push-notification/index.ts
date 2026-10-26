// supabase/functions/send-push-notification/index.ts
//
// Triggered by Supabase Database Webhooks on INSERT into:
//   messages, expenses, settlements, group_members
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

// ── Build a signed JWT (RS256) and exchange it for an OAuth2 access token ──
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
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
) {
  const accessToken = await getAccessToken();
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
      body = `${payer?.full_name ?? "Someone"} added "${record.title}" — ${group?.currency ?? ""} ${record.amount}`;
      dataPayload = {
        type: "expense",
        group_id: groupId ?? "",
        avatar_url: payer?.avatar_url ?? "",
      };
    } else if (table === "settlements") {
      // record_settlement() inserts either:
      //  - 'pending'   — the debtor says "I paid" → ask the receiver to confirm
      //  - 'confirmed' — the receiver says "I got paid" → tell the debtor
      // Confirm / cancel are UPDATEs (no webhook); those RPCs write the
      // in-app notification themselves.
      if (record.status !== "pending" && record.status !== "confirmed") {
        return new Response(JSON.stringify({ skipped: true }), { status: 200 });
      }
      groupId = record.group_id;
      actorId = record.created_by ?? record.paid_by;
      notificationType = "settlement";
      const { data: fromP } = await supabase.from("profiles")
        .select("full_name, avatar_url").eq("id", record.paid_by).maybeSingle();
      const { data: toP } = await supabase.from("profiles")
        .select("full_name, avatar_url").eq("id", record.paid_to).maybeSingle();
      const { data: group } = await supabase.from("groups")
        .select("name, currency").eq("id", groupId).maybeSingle();
      const money = `${group?.currency ?? ""} ${Number(record.amount).toFixed(2)}`;
      title = group?.name ?? "Settlement";
      body = record.status === "pending"
        ? `${fromP?.full_name ?? "Someone"} says they paid you ${money}. Please confirm.`
        : `${toP?.full_name ?? "Someone"} recorded your payment of ${money}`;
      dataPayload = {
        type: "settlement",
        group_id: groupId ?? "",
        avatar_url: (actorId === record.paid_to ? toP?.avatar_url : fromP?.avatar_url) ?? "",
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

    let sent = 0;
    const historyRows: Record<string, unknown>[] = [];

    for (const m of members as any[]) {
      const prefEnabled = m[prefColumn[notificationType]] ?? true;
      if (!prefEnabled) continue; // this user muted this notification category

      // Always log to history (in-app inbox), even if they have no push
      // token (e.g. denied permission) — they can still see it in-app.
      historyRows.push({
        user_id: m.id,
        type: notificationType,
        title,
        body,
        group_id: groupId,
        entity_id: record.id ?? null,
      });

      const token = m.fcm_token;
      if (token) {
        await sendFcm(token, title, body, dataPayload);
        sent++;
      }
    }

    if (historyRows.length > 0) {
      await supabase.from("notifications").insert(historyRows);
    }

    return new Response(JSON.stringify({ sent, logged: historyRows.length }), { status: 200 });
  } catch (e) {
    console.error("Edge function error:", e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});