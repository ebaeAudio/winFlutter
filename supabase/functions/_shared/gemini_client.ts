import { clampString, stripUnsafeControlChars } from "./validation.ts";

function getEnv(name: string, fallback = ""): string {
  try {
    return Deno.env.get(name) ?? fallback;
  } catch (_) {
    return fallback;
  }
}

export type GeminiGenerateOpts = {
  apiKey: string;
  model: string;
  /**
   * System-style instruction for the model (kept short).
   */
  system: string;
  /**
   * User prompt.
   */
  prompt: string;
  timeoutMs: number;
  maxOutputTokens?: number;
};

/**
 * Minimal Gemini generateContent wrapper.
 *
 * We intentionally use raw fetch (no deps) so it runs cleanly in Supabase Edge (Deno).
 * Endpoint: https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent
 */
export async function geminiGenerateText(opts: GeminiGenerateOpts): Promise<string> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), opts.timeoutMs);
  try {
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(opts.model)}:generateContent` +
      `?key=${encodeURIComponent(opts.apiKey)}`;

    const res = await fetch(url, {
      method: "POST",
      signal: controller.signal,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            role: "user",
            parts: [
              { text: `SYSTEM:\n${opts.system}\n\nUSER:\n${opts.prompt}` },
            ],
          },
        ],
        generationConfig: {
          temperature: 0.2,
          topP: 0.9,
          maxOutputTokens: opts.maxOutputTokens ?? 2048,
        },
      }),
    });

    const data = await res.json().catch(() => null);
    if (!res.ok) throw new Error(`gemini_http_${res.status}`);

    // Typical response shape:
    // { candidates: [ { content: { parts: [ { text: "..." } ] } } ] }
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof text !== "string") throw new Error("gemini_no_text");

    // Basic sanitization/size bound to avoid surprise payload sizes downstream.
    const maxChars = Number(getEnv("PRD_MAX_OUTPUT_CHARS", "20000")) || 20000;
    return clampString(stripUnsafeControlChars(text), maxChars);
  } finally {
    clearTimeout(timeout);
  }
}

