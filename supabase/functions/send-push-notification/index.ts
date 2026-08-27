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
          notification: { title, body },
          data,
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
    let dataPayload: Record<string, string> = {};

    if (table === "messages") {
      groupId = record.group_id;
      actorId = record.sender_id;
      const { data: sender } = await supabase.from("profiles")
        .select("full_name").eq("id", actorId).maybeSingle();
      const { data: group } = await supabase.from("groups")
        .select("name").eq("id", groupId).maybeSingle();
      title = group?.name ?? "New message";
      body = `${sender?.full_name ?? "Someone"}: ${record.content ?? "Sent an attachment"}`;
      dataPayload = { type: "message", group_id: groupId ?? "" };
    } else if (table === "expenses") {
      groupId = record.group_id;
      actorId = record.paid_by;
      const { data: payer } = await supabase.from("profiles")
        .select("full_name").eq("id", actorId).maybeSingle();
      const { data: group } = await supabase.from("groups")
        .select("name, currency").eq("id", groupId).maybeSingle();
      title = group?.name ?? "New expense";
      body = `${payer?.full_name ?? "Someone"} added "${record.title}" — ${group?.currency ?? ""} ${record.amount}`;
      dataPayload = { type: "expense", group_id: groupId ?? "" };
    } else if (table === "settlements") {
      groupId = record.group_id;
      actorId = record.paid_by;
      const { data: fromP } = await supabase.from("profiles")
        .select("full_name").eq("id", record.paid_by).maybeSingle();
      const { data: toP } = await supabase.from("profiles")
        .select("full_name").eq("id", record.paid_to).maybeSingle();
      const { data: group } = await supabase.from("groups")
        .select("name, currency").eq("id", groupId).maybeSingle();
      title = group?.name ?? "Settlement";
      body = `${fromP?.full_name ?? "Someone"} settled ${group?.currency ?? ""} ${record.amount} with ${toP?.full_name ?? "someone"}`;
      dataPayload = { type: "settlement", group_id: groupId ?? "" };
    } else if (table === "group_members") {
      groupId = record.group_id;
      actorId = record.user_id;
      const { data: joiner } = await supabase.from("profiles")
        .select("full_name").eq("id", actorId).maybeSingle();
      const { data: group } = await supabase.from("groups")
        .select("name").eq("id", groupId).maybeSingle();
      title = group?.name ?? "New member";
      body = `${joiner?.full_name ?? "Someone"} joined the group`;
      dataPayload = { type: "member_joined", group_id: groupId ?? "" };
    } else {
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }

    if (!groupId) {
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }

    // Recipients = other members of the group (exclude the actor)
    const { data: members } = await supabase
      .from("group_members")
      .select("user_id, profiles(fcm_token)")
      .eq("group_id", groupId)
      .neq("user_id", actorId ?? "");

    if (!members) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    let sent = 0;
    for (const m of members as any[]) {
      const token = m.profiles?.fcm_token;
      if (token) {
        await sendFcm(token, title, body, dataPayload);
        sent++;
      }
    }

    return new Response(JSON.stringify({ sent }), { status: 200 });
  } catch (e) {
    console.error("Edge function error:", e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
