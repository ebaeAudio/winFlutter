/// Supabase Edge Function: generate-prd
///
/// Contract:
/// POST { title, description } -> { path, url, sha }
///
/// Guardrails:
/// - Auth required (verify user via Supabase JWT)
/// - Optional Origin allowlist
/// - Per-user + per-IP RPM rate limit
/// - Input size limits
/// - Output size limits

import { createClient } from "npm:@supabase/supabase-js@2.45.4";

import type { GeneratePrdResponse } from "../_shared/prd_schema.ts";
import { checkRateLimit } from "../_shared/rate_limit.ts";
import { geminiGenerateText } from "../_shared/gemini_client.ts";
import { githubGetFileSha, githubPutFile } from "../_shared/github_contents.ts";
import { parseGeneratePrdRequestBodyStrict, stripUnsafeControlChars } from "../_shared/validation.ts";

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
  const xff = req.headers.get("x-forwarded-for") ?? "";
  const first = xff.split(",")[0]?.trim();
  const direct = req.headers.get("cf-connecting-ip") ?? req.headers.get("x-real-ip") ?? "";
  const ip = (first || direct).trim();
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

function slugify(raw: string): string {
  const s = stripUnsafeControlChars(raw).trim().toLowerCase();
  const replaced = s
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+/, "")
    .replace(/_+$/, "");
  const compact = replaced.length > 0 ? replaced : "feature";
  return compact.slice(0, 64);
}

function buildPrdPrompt(input: { title: string; description: string }): string {
  return [
    "Write a clear, structured product requirements document (PRD) in Markdown.",
    "",
    "Requirements:",
    "- Use the template headings exactly (H1 + H2/H3).",
    "- Be specific, concrete, and actionable.",
    "- Do not include any code blocks unless truly necessary.",
    "- Assume this is for a small team building a Flutter app with Supabase backend.",
    "",
    "Template:",
    "# [Feature Title]",
    "",
    "## Overview",
    "",
    "## Problem Statement",
    "",
    "## Proposed Solution",
    "",
    "## Requirements",
    "### Functional Requirements",
    "",
    "### Non-Functional Requirements",
    "",
    "## Technical Considerations",
    "",
    "## Success Metrics",
    "",
    "Input:",
    `Feature title: ${input.title}`,
    "",
    "Feature request / notes:",
    input.description,
  ].join("\n");
}

function normalizePrdMarkdown(title: string, raw: string): string {
  let text = (raw ?? "").trim();
  if (!text) {
    text = `# ${title}\n\n## Overview\n\n## Problem Statement\n\n## Proposed Solution\n\n## Requirements\n### Functional Requirements\n\n### Non-Functional Requirements\n\n## Technical Considerations\n\n## Success Metrics\n`;
  }
  // Ensure the document starts with an H1.
  if (!text.startsWith("# ")) {
    text = `# ${title}\n\n${text}`;
  }
  // Ensure trailing newline for nicer diffs.
  if (!text.endsWith("\n")) text += "\n";
  return text;
}

Deno.serve(async (req: Request) => {
  const allowedOrigins = parseAllowedOrigins(getEnv("PRD_ALLOWED_ORIGINS", ""));
  const origin = req.headers.get("Origin");
  if (origin && allowedOrigins.size > 0 && !allowedOrigins.has(origin)) {
    return jsonResponse(403, { error: "Origin not allowed" });
  }
  const corsHeaders = buildCorsHeaders(origin, allowedOrigins);

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed" }, { "Allow": "POST", ...corsHeaders });
  }

  const supabaseUrl = getEnv("SUPABASE_URL");
  const supabaseAnonKey = getEnv("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnonKey) {
    return jsonResponse(500, { error: "Supabase env not configured for function" }, corsHeaders);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return jsonResponse(401, { error: "Missing Authorization" }, corsHeaders);
  }

  const serviceRoleKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");
  const supabaseAdmin = serviceRoleKey
    ? createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } })
    : null;

  // Apply IP-based limiter early.
  const ip = getClientIp(req);
  const ipRpm = Number(getEnv("PRD_IP_RPM", "30")) || 30;
  const ipRl = await checkRateLimit({
    client: supabaseAdmin ?? undefined,
    key: `prd:ip:${ip}`,
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

  const userRpm = Number(getEnv("PRD_RPM", "10")) || 10;
  const userRl = await checkRateLimit({
    client: supabaseAdmin ?? undefined,
    key: `prd:user:${userId}`,
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

  const maxBodyBytes = Number(getEnv("PRD_MAX_BODY_BYTES", "20000")) || 20000;
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

  const maxTitleChars = Number(getEnv("PRD_MAX_TITLE_CHARS", "140")) || 140;
  const maxDescriptionChars = Number(getEnv("PRD_MAX_DESCRIPTION_CHARS", "8000")) || 8000;
  const reqParsed = parseGeneratePrdRequestBodyStrict(parsedBody, { maxTitleChars, maxDescriptionChars });
  if (!reqParsed.ok) {
    return jsonResponse(400, { error: reqParsed.error }, corsHeaders);
  }

  const { title, description } = reqParsed.value;

  const geminiKey = getEnv("GEMINI_API_KEY");
  if (!geminiKey) return jsonResponse(500, { error: "GEMINI_API_KEY not configured" }, corsHeaders);

  const githubToken = getEnv("GITHUB_TOKEN");
  const githubRepo = getEnv("GITHUB_REPO");
  if (!githubToken || !githubRepo) {
    return jsonResponse(500, { error: "GitHub not configured (GITHUB_TOKEN/GITHUB_REPO)" }, corsHeaders);
  }

  const model = getEnv("GEMINI_MODEL", "gemini-2.0-flash");
  const timeoutMs = Number(getEnv("PRD_GEMINI_TIMEOUT_MS", "20000")) || 20000;

  let prd = "";
  try {
    prd = await geminiGenerateText({
      apiKey: geminiKey,
      model,
      system: "You are a pragmatic product manager. Output clean Markdown only.",
      prompt: buildPrdPrompt({ title, description }),
      timeoutMs,
      maxOutputTokens: Number(getEnv("PRD_MAX_OUTPUT_TOKENS", "2200")) || 2200,
    });
  } catch (e) {
    return jsonResponse(502, { error: `Gemini failed: ${e instanceof Error ? e.message : "unknown"}` }, corsHeaders);
  }

  const prdMd = normalizePrdMarkdown(title, prd);
  const slug = slugify(title);

  const basePath = `docs/PRD_${slug}.md`;
  const branch = getEnv("GITHUB_BRANCH", "main").trim() || "main";

  // If the base path exists, avoid clobbering by suffixing.
  let finalPath = basePath;
  const baseSha = await githubGetFileSha({ token: githubToken, repo: githubRepo, branch, path: basePath });
  if (baseSha) {
    const stamp = new Date().toISOString().replace(/[:.]/g, "-");
    finalPath = `docs/PRD_${slug}_${stamp}.md`;
  }

  try {
    const res = await githubPutFile({
      token: githubToken,
      repo: githubRepo,
      branch,
      path: finalPath,
      contentUtf8: prdMd,
      message: `docs: add PRD for ${title}`,
    });

    const out: GeneratePrdResponse = {
      path: res.path,
      url: res.htmlUrl,
      sha: res.sha,
    };
    return jsonResponse(200, out, corsHeaders);
  } catch (e) {
    return jsonResponse(502, { error: `GitHub commit failed: ${e instanceof Error ? e.message : "unknown"}` }, corsHeaders);
  }
});

