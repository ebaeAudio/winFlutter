# AI Commands / Voice Assistant (Planning + Implementation Notes)

This repo already has the primitives we need:

- **Tasks**: CRUD via `app/api/tasks/*` backed by `lib/db/tasks.ts`
- **Habits**: list/create + daily completion via `app/api/habits/*` backed by `lib/db/habits.ts`
- **Notes**: daily “notes” exist as **reflections** via `app/api/reflections` backed by `lib/db/reflections.ts`

So the first version of “talk to the app” can be implemented without DB schema changes.

## Architecture (recommended)

See also: `docs/AI_COMMANDS_IMPLEMENTATION_REQUIREMENTS.md` for a portable “implement this in another system” requirements guide.

### 1) Capture speech → transcript (client)

- Use the browser **Web Speech API** (`SpeechRecognition`) when available.
- Always provide a typed fallback input (mobile Safari often lacks SpeechRecognition).
- The client sends `{ transcript, baseDateYmd }` to the server assistant endpoint.

### 2) Translate transcript → structured intent (server)

Create `POST /api/assistant` that returns a **small, validated allowlist** of commands.

- If `OPENAI_API_KEY` is configured:
  - Call an LLM with a constrained prompt and force a **JSON response** containing commands.
- If not configured:
  - Use a **heuristics fallback** (regex-ish) that handles a few common cases.

**Important**: the assistant route should not accept arbitrary “actions”. It must return only a fixed set of command kinds that you explicitly implement.

### 3) Execute commands (client)

On the Today screen, you already have local handlers that call the APIs and update React state:

- `handleTaskCreate(title, type)`
- `handleTaskUpdate(id, updates)`
- `handleHabitToggle(habitId, completed)`
- `handleReflectionSave(note)`

The voice assistant UI should map commands to these handlers so the UI stays in sync.

## Command schema (v1)

The assistant returns:

```ts
type AssistantCommand =
  | { kind: 'date.shift'; days: number }
  | { kind: 'date.set'; ymd: string }
  | { kind: 'habit.create'; name: string }
  | { kind: 'task.create'; title: string; taskType?: 'must-win' | 'nice-to-do' }
  | { kind: 'task.setCompleted'; title: string; completed: boolean }
  | { kind: 'task.delete'; title: string }
  | { kind: 'habit.setCompleted'; name: string; completed: boolean }
  | { kind: 'reflection.append'; text: string }
  | { kind: 'reflection.set'; text: string };
```

Notes:

- **No IDs in voice**: tasks/habits are referenced by **title/name**. The client resolves to IDs.
- **Date handling**: “tomorrow” is expressed as `date.shift` + action, so everything is relative to the currently selected date.
- **Habit vs task**: habits are for recurring behaviors (“daily”, “every day”, “habit”, “track”), tasks are one-offs. If ambiguous, default to task (and add a clarifying step later).

## Safety / guardrails

- **Allowlist only**: reject any command with an unknown `kind`.
- **Hard limits**: cap to e.g. 5 commands per request; cap string lengths.
- **No tool execution on server** (v1): server only translates; client executes known code paths.
- **User scoping**: all API calls still go through `requireApiUser()` and RLS in Supabase.
- **CSRF protection**: enforce an Origin allowlist so third-party sites can’t “credit burn” by tricking a logged-in browser into POSTing `/api/assistant`.
- **Rate limiting**: enforce per-user requests-per-minute (RPM) and optionally add daily quotas.
- **Cost caps**: set `max_tokens`, short timeouts, and conservative model defaults.
- **No debug leakage**: only emit assistant debug fields if explicitly enabled.

## Env vars

Add at runtime (not required for build):

- `OPENAI_API_KEY` (server-side only)
- `OPENAI_MODEL` (optional, default set in code)
- `ASSISTANT_ALLOWED_ORIGINS` (optional, comma-separated; defaults to same-origin)
- `ASSISTANT_RPM` (optional; default 20 requests/minute per user, in-process limiter)
- `ASSISTANT_OPENAI_TIMEOUT_MS` (optional; default 12000ms)
- `ASSISTANT_MAX_TRANSCRIPT_CHARS` (optional; default 2000)
- `ASSISTANT_DEBUG` (optional; default false)

## Rollout plan

- Start with typed commands + toasts (fast iteration).
- Add speech recognition (desktop Chrome first).
- Add “confirm before executing” for destructive actions (delete) and multi-step sequences.
- Add “disambiguation” UX when multiple tasks match a title (e.g., show 2–3 choices).


