import type { AssistantCommand, AssistantResponse, TaskType } from "./assistant_schema.ts";
import { clampString, isYmd, validateAssistantResponse } from "./validation.ts";

function inferTaskType(text: string): TaskType | null {
  const t = text.toLowerCase();
  if (t.includes("must win") || t.includes("must-win") || t.includes("mustwin")) return "must-win";
  if (t.includes("nice to do") || t.includes("nice-to-do") || t.includes("nicetodo") || t.includes("nice todo")) {
    return "nice-to-do";
  }
  return null;
}

function stripLead(raw: string, prefixes: string[]): string {
  const s = raw.trim();
  const lower = s.toLowerCase();
  for (const p of prefixes) {
    if (lower.startsWith(p)) return s.slice(p.length).trim();
  }
  return s;
}

function extractYmd(text: string): string | null {
  const m = text.match(/\b(\d{4}-\d{2}-\d{2})\b/);
  if (!m) return null;
  const ymd = m[1];
  return isYmd(ymd) ? ymd : null;
}

export function heuristicTranslate(transcriptRaw: string, baseDateYmd: string): AssistantResponse {
  const transcript = clampString(transcriptRaw, 2000);
  const lower = transcript.toLowerCase();

  const commands: AssistantCommand[] = [];

  // Date intent.
  if (lower.includes("tomorrow")) commands.push({ kind: "date.shift", days: 1 });
  else if (lower.includes("yesterday")) commands.push({ kind: "date.shift", days: -1 });
  else if (lower.includes("today")) commands.push({ kind: "date.shift", days: 0 });

  const explicitYmd = extractYmd(lower);
  if (explicitYmd) {
    // Prefer explicit date set over relative shift.
    for (let i = commands.length - 1; i >= 0; i--) {
      if (commands[i].kind === "date.shift") commands.splice(i, 1);
    }
    commands.push({ kind: "date.set", ymd: explicitYmd });
  }

  // Reflection.
  if (lower.startsWith("note:") || lower.startsWith("note ") || lower.startsWith("reflection:") || lower.startsWith("reflection ")) {
    const text = stripLead(transcript, ["note:", "note ", "reflection:", "reflection "]);
    if (text.trim().length > 0) {
      commands.push({ kind: "reflection.append", text: clampString(text, 1500) });
      return validateAssistantResponse({ say: "Noted.", commands });
    }
  }
  if (lower.startsWith("set reflection:") || lower.startsWith("set reflection ")) {
    const text = stripLead(transcript, ["set reflection:", "set reflection "]);
    commands.push({ kind: "reflection.set", text: clampString(text, 4000) });
    return validateAssistantResponse({ say: "Saved.", commands });
  }

  // Habit create.
  if (lower.startsWith("add habit ") || lower.startsWith("create habit ") || lower.startsWith("habit ")) {
    const name = stripLead(transcript, ["add habit ", "create habit ", "habit "]);
    if (name.trim().length > 0) commands.push({ kind: "habit.create", name: clampString(name, 140) });
  } else if (lower.startsWith("track ")) {
    const name = stripLead(transcript, ["track "]);
    if (name.trim().length > 0) commands.push({ kind: "habit.create", name: clampString(name, 140) });
  } else if (lower.includes(" every day") || lower.includes(" daily")) {
    // Best-effort "X every day" -> habit.create (take leading chunk).
    const name = transcript
      .replace(/ every day/gi, "")
      .replace(/ daily/gi, "")
      .trim();
    if (name.length > 0 && name.length <= 140) commands.push({ kind: "habit.create", name });
  }

  // Habit completion.
  if (lower.startsWith("complete habit ") || lower.startsWith("mark habit ")) {
    const name = stripLead(transcript, ["complete habit ", "mark habit "]);
    if (name.trim().length > 0) commands.push({ kind: "habit.setCompleted", name: clampString(name, 140), completed: true });
  } else if (lower.startsWith("uncomplete habit ") || lower.startsWith("unmark habit ") || lower.startsWith("undo habit ")) {
    const name = stripLead(transcript, ["uncomplete habit ", "unmark habit ", "undo habit "]);
    if (name.trim().length > 0) commands.push({ kind: "habit.setCompleted", name: clampString(name, 140), completed: false });
  }

  // Task create.
  if (lower.startsWith("add task ") || lower.startsWith("create task ") || lower.startsWith("task ")) {
    const title = stripLead(transcript, ["add task ", "create task ", "task "]);
    const taskType = inferTaskType(transcript);
    if (title.trim().length > 0) {
      const cmd: AssistantCommand = taskType
        ? { kind: "task.create", title: clampString(title, 140), taskType }
        : { kind: "task.create", title: clampString(title, 140) };
      commands.push(cmd);
    }
  } else if (lower.startsWith("add must win task") || lower.startsWith("add must-win task") || lower.startsWith("add must win ")) {
    const title = stripLead(transcript, ["add must win task", "add must-win task", "add must win "]).replace(/^:\s*/, "");
    if (title.trim().length > 0) commands.push({ kind: "task.create", title: clampString(title, 140), taskType: "must-win" });
  } else if (lower.startsWith("add nice to do task") || lower.startsWith("add nice-to-do task") || lower.startsWith("add nice to do ")) {
    const title = stripLead(transcript, ["add nice to do task", "add nice-to-do task", "add nice to do "]).replace(/^:\s*/, "");
    if (title.trim().length > 0) commands.push({ kind: "task.create", title: clampString(title, 140), taskType: "nice-to-do" });
  }

  // Task completion.
  if (lower.startsWith("complete task ") || lower.startsWith("mark task ")) {
    const title = stripLead(transcript, ["complete task ", "mark task "]);
    if (title.trim().length > 0) commands.push({ kind: "task.setCompleted", title: clampString(title, 140), completed: true });
  } else if (lower.startsWith("uncomplete task ") || lower.startsWith("unmark task ") || lower.startsWith("undo task ")) {
    const title = stripLead(transcript, ["uncomplete task ", "unmark task ", "undo task "]);
    if (title.trim().length > 0) commands.push({ kind: "task.setCompleted", title: clampString(title, 140), completed: false });
  }

  // Task delete.
  if (lower.startsWith("delete task ") || lower.startsWith("remove task ")) {
    const title = stripLead(transcript, ["delete task ", "remove task "]);
    if (title.trim().length > 0) commands.push({ kind: "task.delete", title: clampString(title, 140) });
  }

  // If heuristic didn't find an action, include a helpful say.
  const hasAction = commands.some((c) => c.kind !== "date.shift" && c.kind !== "date.set");
  const say = hasAction
    ? "Got it."
    : `Try: "tomorrow add task ...", "complete task ...", "note: ...", or "add habit ...".`;

  // Return validated/capped result; never trust heuristic output blindly.
  return validateAssistantResponse({
    say,
    commands: commands.slice(0, 5),
    debug: { mode: "heuristic", baseDateYmd },
  });
}


