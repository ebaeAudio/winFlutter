/// Supabase Edge Function: assistant
///
/// Contract (matches docs/AI_COMMANDS_IMPLEMENTATION_REQUIREMENTS.md):
/// POST { transcript, baseDateYmd } -> { say, commands[], debug? }
///
/// Guardrails:
/// - Auth required (verify user via Supabase JWT)
/// - Optional Origin allowlist
/// - Per-user RPM rate limit (in-memory)
/// - Input size limits
/// - Output validation (drop unknown/invalid commands)

import { createClient } from "npm:@supabase/supabase-js@2.45.4";

import type { AssistantResponse } from "../_shared/assistant_schema.ts";
import { heuristicTranslate } from "../_shared/heuristics.ts";
import { checkRateLimit } from "../_shared/rate_limit.ts";
import { parseAssistantRequestBodyStrict, validateAssistantResponse } from "../_shared/validation.ts";

function jsonResponse(status: number, body: unknown, headers?: HeadersInit): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...headers,
    },
  });
}

function getEnv(name: string, fallback = ""): string {
  try {
    return Deno.env.get(name) ?? fallback;
  } catch (_) {
    return fallback;
  }
}

function parseAllowedOrigins(raw: string): Set<string> {
  const set = new Set<string>();
  for (const part of raw.split(",")) {
    const o = part.trim();
    if (o) set.add(o);
  }
  return set;
}

function getClientIp(req: Request): string {
  // Prefer proxy-provided headers. On Supabase Edge Functions, `x-forwarded-for` is typical.
  const xff = req.headers.get("x-forwarded-for") ?? "";
  const first = xff.split(",")[0]?.trim();
  const direct = req.headers.get("cf-connecting-ip") ?? req.headers.get("x-real-ip") ?? "";
  const ip = (first || direct).trim();
  // Keep keys bounded (avoid unbounded memory/row growth on weird inputs).
  return ip.length > 0 && ip.length <= 80 ? ip : "unknown";
}

function buildCorsHeaders(origin: string | null, allowedOrigins: Set<string>): HeadersInit {
  if (!origin) return {};
  if (allowedOrigins.size > 0 && !allowedOrigins.has(origin)) return {};
  return {
    "Access-Control-Allow-Origin": origin,
    "Vary": "Origin",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, content-type",
    "Access-Control-Max-Age": "86400",
  };
}

function buildOpenAiPrompt(args: { transcript: string; baseDateYmd: string }): string {
  // Keep the prompt tightly scoped so the model can't invent commands.
  return [
    "You translate user transcript text into a strict JSON object with a small allowlisted command list.",
    "Return ONLY JSON (no markdown, no commentary).",
    "",
    "Schema:",
    `{`,
    `  "say": string,`,
    `  "commands": [`,
    `    { "kind": "date.shift", "days": integer },`,
    `    { "kind": "date.set", "ymd": "YYYY-MM-DD" },`,
    `    { "kind": "habit.create", "name": string },`,
    `    { "kind": "task.create", "title": string, "taskType"?: "must-win" | "nice-to-do" },`,
    `    { "kind": "task.setCompleted", "title": string, "completed": boolean },`,
    `    { "kind": "task.delete", "title": string },`,
    `    { "kind": "habit.setCompleted", "name": string, "completed": boolean },`,
    `    { "kind": "reflection.append", "text": string },`,
    `    { "kind": "reflection.set", "text": string }`,
    `  ]`,
    `}`,
    "",
    "Rules:",
    "- Output must be valid JSON.",
    "- Only include commands from the allowlist above.",
    "- Max 5 commands.",
    "- If the user says a relative date like tomorrow/yesterday/today, emit the date command FIRST, then the action(s).",
    "- Prefer task.create for ambiguous items; only use habit.create for clearly recurring behaviors (habit, track, every day, daily).",
    "- Do not invent names/titles; use the words the user provided.",
    "- If you can't safely map to a command, return an empty commands array and a helpful 'say'.",
    "",
    `baseDateYmd: ${args.baseDateYmd}`,
    `transcript: ${args.transcript}`,
  ].join("\n");
}

async function callOpenAi(opts: {
  apiKey: string;
  model: string;
  transcript: string;
  baseDateYmd: string;
  timeoutMs: number;
}): Promise<unknown> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), opts.timeoutMs);
  try {
    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      signal: controller.signal,
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${opts.apiKey}`,
      },
      body: JSON.stringify({
        model: opts.model,
        temperature: 0,
        max_tokens: 350,
        messages: [
          { role: "system", content: "You are a strict JSON translator." },
          { role: "user", content: buildOpenAiPrompt({ transcript: opts.transcript, baseDateYmd: opts.baseDateYmd }) },
        ],
      }),
    });
    const data = await res.json().catch(() => null);
    if (!res.ok) throw new Error(`openai_http_${res.status}`);
    // Chat Completions response: choices[0].message.content is a JSON string.
    const content = data?.choices?.[0]?.message?.content;
    if (typeof content !== "string") throw new Error("openai_no_content");
    return JSON.parse(content);
  } finally {
    clearTimeout(timeout);
  }
}

Deno.serve(async (req: Request) => {
  const allowedOrigins = parseAllowedOrigins(getEnv("ASSISTANT_ALLOWED_ORIGINS", ""));
  const origin = req.headers.get("Origin");
  if (origin && allowedOrigins.size > 0 && !allowedOrigins.has(origin)) {
    return jsonResponse(403, { error: "Origin not allowed" });
  }
  const corsHeaders = buildCorsHeaders(origin, allowedOrigins);

  if (req.method === "OPTIONS") {
    // CORS preflight; never execute handler logic.
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed" }, { "Allow": "POST", ...corsHeaders });
  }

  const supabaseUrl = getEnv("SUPABASE_URL");
  const supabaseAnonKey = getEnv("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnonKey) {
    // Function isn't configured; for safety we still require auth header, but can't validate.
    return jsonResponse(500, { error: "Supabase env not configured for function" }, corsHeaders);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return jsonResponse(401, { error: "Missing Authorization" }, corsHeaders);
  }

  // Prefer durable rate limiting using the service role key (server-side only).
  // If not configured, we fall back to a best-effort in-memory limiter to avoid breaking functionality.
  const serviceRoleKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");
  const supabaseAdmin = serviceRoleKey
    ? createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } })
    : null;

  // Apply an IP-based limiter early to protect availability before any expensive work.
  const ip = getClientIp(req);
  const ipRpm = Number(getEnv("ASSISTANT_IP_RPM", "60")) || 60;
  const ipRl = await checkRateLimit({
    client: supabaseAdmin ?? undefined,
    key: `assistant:ip:${ip}`,
    windowSeconds: 60,
    maxRequests: ipRpm,
  });
  if (!ipRl.ok) {
    return jsonResponse(
      429,
      { error: "Rate limit exceeded" },
      {
        "Retry-After": String(ipRl.retryAfterSeconds),
        "X-RateLimit-Limit": String(ipRl.limit),
        "X-RateLimit-Remaining": String(ipRl.remaining),
        "X-RateLimit-Reset": String(ipRl.resetSeconds),
        ...corsHeaders,
      },
    );
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });

  const userRes = await supabase.auth.getUser().catch(() => null);
  const userId = userRes?.data?.user?.id;
  if (!userId) return jsonResponse(401, { error: "Unauthorized" }, corsHeaders);

  // Per-user limit (primary limiter). We keep the existing default RPM=20.
  const userRpm = Number(getEnv("ASSISTANT_RPM", "20")) || 20;
  const userRl = await checkRateLimit({
    client: supabaseAdmin ?? undefined,
    key: `assistant:user:${userId}`,
    windowSeconds: 60,
    maxRequests: userRpm,
  });
  if (!userRl.ok) {
    return jsonResponse(
      429,
      { error: "Rate limit exceeded" },
      {
        "Retry-After": String(userRl.retryAfterSeconds),
        "X-RateLimit-Limit": String(userRl.limit),
        "X-RateLimit-Remaining": String(userRl.remaining),
        "X-RateLimit-Reset": String(userRl.resetSeconds),
        ...corsHeaders,
      },
    );
  }

  const maxTranscriptChars = Number(getEnv("ASSISTANT_MAX_TRANSCRIPT_CHARS", "2000")) || 2000;
  const maxBodyBytes = Number(getEnv("ASSISTANT_MAX_BODY_BYTES", "20000")) || 20000;
  const debugEnabled = getEnv("ASSISTANT_DEBUG", "false").toLowerCase().trim() === "true";

  const contentLength = Number(req.headers.get("content-length") ?? "0") || 0;
  if (contentLength > maxBodyBytes) {
    return jsonResponse(413, { error: "Request too large" }, corsHeaders);
  }

  let parsedBody: any = null;
  try {
    parsedBody = await req.json();
  } catch (_) {
    return jsonResponse(400, { error: "Invalid JSON" }, corsHeaders);
  }

  const reqParsed = parseAssistantRequestBodyStrict(parsedBody, { maxTranscriptChars });
  if (!reqParsed.ok) {
    return jsonResponse(400, { error: reqParsed.error }, corsHeaders);
  }
  const { transcript, baseDateYmd } = reqParsed.value;

  // LLM mode if configured, otherwise heuristic fallback.
  const openAiKey = getEnv("OPENAI_API_KEY");
  const openAiModel = getEnv("OPENAI_MODEL", "gpt-4o-mini");
  const timeoutMs = Number(getEnv("ASSISTANT_OPENAI_TIMEOUT_MS", "12000")) || 12000;

  let out: AssistantResponse;
  if (openAiKey) {
    try {
      const raw = await callOpenAi({
        apiKey: openAiKey,
        model: openAiModel,
        transcript,
        baseDateYmd,
        timeoutMs,
      });
      out = validateAssistantResponse(raw, { debug: debugEnabled });
      if (debugEnabled) {
        out.debug = {
          ...(out.debug ?? {}),
          mode: "openai",
          model: openAiModel,
        };
      }
    } catch (e) {
      out = heuristicTranslate(transcript, baseDateYmd);
      if (debugEnabled) {
        out.debug = {
          ...(out.debug ?? {}),
          mode: "heuristic_fallback",
          openaiError: (e instanceof Error ? e.message : "openai_failed"),
        };
      }
    }
  } else {
    out = heuristicTranslate(transcript, baseDateYmd);
    if (debugEnabled) {
      out.debug = { ...(out.debug ?? {}), mode: "heuristic_no_key" };
    }
  }

  return jsonResponse(200, out, corsHeaders);
});


