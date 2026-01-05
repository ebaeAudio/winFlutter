export type TaskType = "must-win" | "nice-to-do";

export type AssistantCommand =
  | { kind: "date.shift"; days: number }
  | { kind: "date.set"; ymd: string }
  | { kind: "habit.create"; name: string }
  | { kind: "task.create"; title: string; taskType?: TaskType }
  | { kind: "task.setCompleted"; title: string; completed: boolean }
  | { kind: "task.delete"; title: string }
  | { kind: "habit.setCompleted"; name: string; completed: boolean }
  | { kind: "reflection.append"; text: string }
  | { kind: "reflection.set"; text: string };

export type AssistantResponse = {
  say: string;
  commands: AssistantCommand[];
  debug?: Record<string, unknown>;
};


