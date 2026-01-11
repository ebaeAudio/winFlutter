import type { AssistantCommand, AssistantResponse, TaskType } from "./assistant_schema.ts";

const YMD_RE = /^\d{4}-\d{2}-\d{2}$/;

export function clampString(raw: unknown, maxLen: number): string {
  const s = typeof raw === "string" ? raw : "";
  const trimmed = s.trim();
  if (trimmed.length <= maxLen) return trimmed;
  return trimmed.slice(0, maxLen);
}

/**
 * Basic sanitization: strip ASCII control chars except tab/newline/carriage return.
 * This helps avoid log injection / hidden characters while preserving natural language.
 */
export function stripUnsafeControlChars(raw: string): string {
  let out = "";
  for (let i = 0; i < raw.length; i++) {
    const c = raw.charCodeAt(i);
    const isAllowed =
      c === 0x09 || // \t
      c === 0x0a || // \n
      c === 0x0d || // \r
      (c >= 0x20 && c !== 0x7f);
    if (isAllowed) out += raw[i];
  }
  return out;
}

export function isYmd(raw: unknown): raw is string {
  return typeof raw === "string" && YMD_RE.test(raw.trim());
}

export type AssistantRequest = {
  transcript: string;
  baseDateYmd: string;
};

/**
 * Strict, schema-based parsing for assistant request bodies.
 *
 * OWASP alignment:
 * - Validate inputs at the boundary (type checks, length limits).
 * - Reject unexpected fields (avoid "mass assignment" / surprising behavior).
 */
export function parseAssistantRequestBodyStrict(raw: unknown, opts: {
  maxTranscriptChars: number;
}): { ok: true; value: AssistantRequest } | { ok: false; error: string } {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    return { ok: false, error: "Body must be a JSON object" };
  }

  const obj = raw as Record<string, unknown>;
  const allowedKeys = new Set(["transcript", "baseDateYmd"]);
  for (const k of Object.keys(obj)) {
    if (!allowedKeys.has(k)) return { ok: false, error: `Unexpected field: ${k}` };
  }

  const transcriptRaw = typeof obj["transcript"] === "string" ? obj["transcript"] : "";
  const baseDateRaw = typeof obj["baseDateYmd"] === "string" ? obj["baseDateYmd"] : "";

  const transcript = clampString(stripUnsafeControlChars(transcriptRaw), opts.maxTranscriptChars);
  const baseDateYmd = clampString(stripUnsafeControlChars(baseDateRaw), 10);

  if (!transcript) return { ok: false, error: "transcript required" };
  if (!isYmd(baseDateYmd)) return { ok: false, error: "baseDateYmd required (YYYY-MM-DD)" };

  return { ok: true, value: { transcript, baseDateYmd } };
}

function asBool(raw: unknown): boolean | null {
  if (typeof raw === "boolean") return raw;
  return null;
}

function asInt(raw: unknown): number | null {
  if (typeof raw === "number" && Number.isFinite(raw) && Number.isInteger(raw)) return raw;
  return null;
}

function asTaskType(raw: unknown): TaskType | null {
  if (raw === "must-win" || raw === "nice-to-do") return raw;
  return null;
}

export function validateCommand(raw: unknown): AssistantCommand | null {
  if (!raw || typeof raw !== "object") return null;
  const obj = raw as Record<string, unknown>;
  const kind = obj["kind"];
  if (typeof kind !== "string") return null;

  switch (kind) {
    case "date.shift": {
      const days = asInt(obj["days"]);
      if (days == null) return null;
      if (days < -365 || days > 365) return null;
      return { kind: "date.shift", days };
    }
    case "date.set": {
      const ymd = clampString(obj["ymd"], 10);
      if (!isYmd(ymd)) return null;
      return { kind: "date.set", ymd };
    }
    case "habit.create": {
      const name = clampString(obj["name"], 140);
      if (name.length < 1) return null;
      return { kind: "habit.create", name };
    }
    case "task.create": {
      const title = clampString(obj["title"], 140);
      if (title.length < 1) return null;
      const taskType = asTaskType(obj["taskType"]);
      return taskType ? { kind: "task.create", title, taskType } : { kind: "task.create", title };
    }
    case "task.setCompleted": {
      const title = clampString(obj["title"], 140);
      const completed = asBool(obj["completed"]);
      if (title.length < 1 || completed == null) return null;
      return { kind: "task.setCompleted", title, completed };
    }
    case "task.delete": {
      const title = clampString(obj["title"], 140);
      if (title.length < 1) return null;
      return { kind: "task.delete", title };
    }
    case "habit.setCompleted": {
      const name = clampString(obj["name"], 140);
      const completed = asBool(obj["completed"]);
      if (name.length < 1 || completed == null) return null;
      return { kind: "habit.setCompleted", name, completed };
    }
    case "reflection.append": {
      const text = clampString(obj["text"], 1500);
      if (text.length < 1) return null;
      return { kind: "reflection.append", text };
    }
    case "reflection.set": {
      const text = clampString(obj["text"], 4000);
      // Empty is allowed for set.
      return { kind: "reflection.set", text };
    }
    default:
      return null;
  }
}

export function validateAssistantResponse(raw: unknown, opts?: { debug?: boolean }): AssistantResponse {
  const obj = (raw && typeof raw === "object") ? (raw as Record<string, unknown>) : {};
  const say = clampString(obj["say"], 240);
  const commandsRaw = Array.isArray(obj["commands"]) ? obj["commands"] : [];

  const commands: AssistantCommand[] = [];
  for (const c of commandsRaw) {
    const validated = validateCommand(c);
    if (validated) commands.push(validated);
    if (commands.length >= 5) break;
  }

  const res: AssistantResponse = {
    say: say.length > 0 ? say : (commands.length > 0 ? "Got it." : "I couldn't find a safe command to run."),
    commands,
  };

  if (opts?.debug && obj["debug"] && typeof obj["debug"] === "object") {
    res.debug = obj["debug"] as Record<string, unknown>;
  }

  return res;
}


