/// Supabase Edge Function: remote_focus_push
///
/// Purpose:
/// - Send a silent APNs push to iOS devices for a user when a new
///   `remote_focus_commands` row is created, so the iPhone app wakes up and
///   processes the command.
///
/// Expected request body:
///   { "user_id": "<uuid>", "command_id": "<uuid>" }
///
/// Auth:
/// - Requires `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>`.
///
/// Env vars required:
/// - SUPABASE_URL
/// - SUPABASE_SERVICE_ROLE_KEY
/// - APNS_TEAM_ID
/// - APNS_KEY_ID
/// - APNS_PRIVATE_KEY_P8   (the .p8 content)
/// - APNS_BUNDLE_ID        (topic)
/// - APNS_USE_SANDBOX      ("true" for development, else production)

import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { importPKCS8, SignJWT } from "npm:jose@6.1.3";

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

function getEnv(name: string, fallback = ""): string {
  try {
    return Deno.env.get(name) ?? fallback;
  } catch (_) {
    return fallback;
  }
}

function requireServiceRoleAuth(req: Request, serviceRoleKey: string): boolean {
  const auth = (req.headers.get("Authorization") ?? "").trim();
  if (!auth.toLowerCase().startsWith("bearer ")) return false;
  const token = auth.slice("bearer ".length).trim();
  return token.length > 0 && token === serviceRoleKey;
}

async function makeApnsJwt(args: {
  teamId: string;
  keyId: string;
  privateKeyP8: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const key = await importPKCS8(args.privateKeyP8, "ES256");
  // Apple recommends short-lived JWTs (<= 60 min). We'll set 20 minutes.
  const exp = now + 20 * 60;
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: args.keyId })
    .setIssuer(args.teamId)
    .setIssuedAt(now)
    .setExpirationTime(exp)
    .sign(key);
}

async function sendSilentPush(args: {
  token: string;
  jwt: string;
  topic: string;
  useSandbox: boolean;
  commandId: string;
}): Promise<{ ok: boolean; status: number; body?: unknown }> {
  const base = args.useSandbox
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";

  const res = await fetch(`${base}/3/device/${encodeURIComponent(args.token)}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${args.jwt}`,
      "apns-topic": args.topic,
      "apns-push-type": "background",
      "apns-priority": "5",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      aps: { "content-available": 1 },
      remote_focus_command_id: args.commandId,
    }),
  });

  const text = await res.text().catch(() => "");
  let parsed: unknown = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch (_) {
    parsed = text;
  }
  return { ok: res.ok, status: res.status, body: parsed };
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return jsonResponse(405, { error: "Method not allowed" });

  const supabaseUrl = getEnv("SUPABASE_URL");
  const serviceRoleKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(500, { error: "Supabase env not configured" });
  }

  if (!requireServiceRoleAuth(req, serviceRoleKey)) {
    return jsonResponse(401, { error: "Unauthorized" });
  }

  let body: any = null;
  try {
    body = await req.json();
  } catch (_) {
    return jsonResponse(400, { error: "Invalid JSON" });
  }

  const userId = typeof body?.user_id === "string" ? body.user_id : "";
  const commandId = typeof body?.command_id === "string" ? body.command_id : "";
  if (!userId || !commandId) {
    return jsonResponse(400, { error: "Missing user_id or command_id" });
  }

  const teamId = getEnv("APNS_TEAM_ID");
  const keyId = getEnv("APNS_KEY_ID");
  const privateKeyP8 = getEnv("APNS_PRIVATE_KEY_P8");
  const topic = getEnv("APNS_BUNDLE_ID");
  const useSandbox = getEnv("APNS_USE_SANDBOX", "true").toLowerCase().trim() === "true";

  if (!teamId || !keyId || !privateKeyP8 || !topic) {
    return jsonResponse(500, { error: "APNs env not configured" });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } });

  // Fetch iOS device tokens for this user.
  const devicesRes = await supabase
    .from("user_devices")
    .select("push_token, platform, push_provider")
    .eq("user_id", userId)
    .eq("push_provider", "apns")
    .eq("platform", "ios");

  if (devicesRes.error) {
    return jsonResponse(500, { error: "device_query_failed", details: devicesRes.error.message });
  }

  const tokens = (devicesRes.data ?? [])
    .map((d: any) => (typeof d?.push_token === "string" ? d.push_token : ""))
    .filter((t: string) => t.length > 0);

  if (tokens.length === 0) {
    return jsonResponse(200, { ok: true, pushed: 0, note: "no_ios_devices" });
  }

  const jwt = await makeApnsJwt({ teamId, keyId, privateKeyP8 });

  const results: Array<{ tokenSuffix: string; ok: boolean; status: number; body?: unknown }> = [];
  for (const token of tokens) {
    const r = await sendSilentPush({ token, jwt, topic, useSandbox, commandId });
    results.push({
      tokenSuffix: token.slice(-8),
      ok: r.ok,
      status: r.status,
      body: r.body,
    });
  }

  return jsonResponse(200, { ok: true, pushed: tokens.length, results });
});

