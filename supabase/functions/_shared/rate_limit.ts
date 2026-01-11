import type { SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";

/**
 * Rate limiting helper for public endpoints (Supabase Edge Functions).
 *
 * OWASP alignment:
 * - Protects availability by throttling abuse (brute force, scraping, accidental loops).
 * - Server-side enforcement only (client limits are bypassable).
 *
 * Implementation strategy:
 * - Preferred: Postgres-backed counter via RPC (`public.rate_limit_check`) for durability across Edge instances.
 * - Fallback: in-memory sliding window (best-effort) if DB client isn't available.
 */

export type RateLimitResult = {
  ok: boolean;
  retryAfterSeconds: number;
  limit: number;
  remaining: number;
  resetSeconds: number;
  mode: "db" | "memory";
};

type WindowState = { timestampsMs: number[] };
const windows = new Map<string, WindowState>();

function clampInt(n: number, min: number, max: number): number {
  if (!Number.isFinite(n)) return min;
  return Math.max(min, Math.min(max, Math.floor(n)));
}

function checkRateLimitMemory(opts: {
  key: string;
  windowSeconds: number;
  maxRequests: number;
  nowMs?: number;
}): RateLimitResult {
  const now = opts.nowMs ?? Date.now();
  const windowMs = clampInt(opts.windowSeconds, 1, 86400) * 1000;
  const limit = clampInt(opts.maxRequests, 1, 10000);

  const state = windows.get(opts.key) ?? { timestampsMs: [] };
  const cutoff = now - windowMs;
  state.timestampsMs = state.timestampsMs.filter((t) => t > cutoff);

  const resetSeconds = Math.max(1, Math.ceil((windowMs - (now - (Math.min(...state.timestampsMs, now)))) / 1000));
  if (state.timestampsMs.length >= limit) {
    windows.set(opts.key, state);
    return {
      ok: false,
      retryAfterSeconds: resetSeconds,
      limit,
      remaining: 0,
      resetSeconds,
      mode: "memory",
    };
  }

  state.timestampsMs.push(now);
  windows.set(opts.key, state);
  return {
    ok: true,
    retryAfterSeconds: 0,
    limit,
    remaining: Math.max(0, limit - state.timestampsMs.length),
    resetSeconds,
    mode: "memory",
  };
}

export async function checkRateLimit(opts: {
  /**
   * Unique key for the limiter, e.g.:
   * - `assistant:user:<uuid>`
   * - `assistant:ip:<ip>`
   */
  key: string;
  /**
   * Window size for the limiter in seconds.
   * Defaults to 60 (per-minute).
   */
  windowSeconds?: number;
  /**
   * Max requests allowed in the window.
   */
  maxRequests: number;
  /**
   * Optional Supabase client (SERVICE ROLE recommended) to use DB-backed limiter.
   */
  client?: SupabaseClient;
  nowMs?: number;
}): Promise<RateLimitResult> {
  const windowSeconds = clampInt(opts.windowSeconds ?? 60, 1, 86400);
  const maxRequests = clampInt(opts.maxRequests, 1, 10000);

  // Durable, cross-instance enforcement.
  if (opts.client) {
    try {
      const { data, error } = await opts.client.rpc("rate_limit_check", {
        p_key: opts.key,
        p_window_seconds: windowSeconds,
        p_max_requests: maxRequests,
      });

      if (error) throw error;
      const row = Array.isArray(data) ? data[0] : data;
      if (!row || typeof row !== "object") throw new Error("rate_limit_bad_response");

      const ok = Boolean((row as any).ok);
      const retryAfterSeconds = clampInt(Number((row as any).retry_after_seconds ?? 0), 0, 86400);
      const limit = clampInt(Number((row as any).limit ?? maxRequests), 1, 10000);
      const remaining = clampInt(Number((row as any).remaining ?? 0), 0, 10000);
      const resetSeconds = clampInt(Number((row as any).reset_seconds ?? windowSeconds), 1, 86400);

      return { ok, retryAfterSeconds, limit, remaining, resetSeconds, mode: "db" };
    } catch (_) {
      // Fall through to best-effort memory limiter.
    }
  }

  return checkRateLimitMemory({
    key: opts.key,
    windowSeconds,
    maxRequests,
    nowMs: opts.nowMs,
  });
}


