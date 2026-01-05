type WindowState = {
  timestampsMs: number[];
};

const windows = new Map<string, WindowState>();

export function checkRateLimit(opts: {
  key: string;
  rpm: number;
  nowMs?: number;
}): { ok: true } | { ok: false; retryAfterSeconds: number } {
  const now = opts.nowMs ?? Date.now();
  const windowMs = 60_000;
  const rpm = Math.max(1, Math.min(120, Math.floor(opts.rpm)));

  const state = windows.get(opts.key) ?? { timestampsMs: [] };
  const cutoff = now - windowMs;
  state.timestampsMs = state.timestampsMs.filter((t) => t > cutoff);

  if (state.timestampsMs.length >= rpm) {
    const oldest = Math.min(...state.timestampsMs);
    const retryAfterMs = Math.max(500, windowMs - (now - oldest));
    const retryAfterSeconds = Math.ceil(retryAfterMs / 1000);
    windows.set(opts.key, state);
    return { ok: false, retryAfterSeconds };
  }

  state.timestampsMs.push(now);
  windows.set(opts.key, state);
  return { ok: true };
}


