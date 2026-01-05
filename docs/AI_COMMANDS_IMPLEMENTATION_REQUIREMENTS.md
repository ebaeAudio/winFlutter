# AI Commands Feature — Implementation Requirements Guide (Portable)

This document describes the **implementation requirements** for the “AI Commands / Voice Assistant” feature so it can be re-implemented in another system while preserving the same safety model, API contract, and UX expectations.

The defining pattern is:

- **Server**: translate user input (speech transcript / typed command) into a **small allowlisted set** of structured commands.
- **Client**: execute those commands via **existing, trusted app code paths** (your normal CRUD handlers), so UI stays consistent and the AI never “directly” performs privileged actions.

---

## Goals and non-goals

- **Goal**: Let users say/type natural phrases like “add task call mom”, “tomorrow mark workout complete”, “note: shipped v1” and have the app do the right thing.
- **Goal**: Keep actions safe and predictable by only supporting an explicit allowlist of command kinds.
- **Goal**: Keep execution deterministic and auditable by executing commands via existing handlers/routes.

- **Non-goal (v1)**: Full agentic behavior (arbitrary tool execution, browsing, free-form workflows).
- **Non-goal (v1)**: Server-side “do the action” with elevated privileges. The server only translates.
- **Non-goal (v1)**: Perfect NLP. Mis-parses are acceptable if they are safe and recoverable.

---

## High-level architecture

### Components

- **Client capture** (optional voice):
  - Speech → transcript (Web Speech API when available) and always a typed fallback.
  - Sends a request to the assistant endpoint: `POST /api/assistant`.

- **Assistant translation service** (server):
  - Authenticates the user (must be logged in).
  - Applies request guardrails (origin/CSRF mitigation, rate limiting, size limits).
  - Translates transcript → `{ say, commands[] }` using:
    - **LLM mode** if an API key is configured.
    - **Heuristic fallback** if not configured or if the LLM fails.
  - Strictly validates output and drops unknown/invalid commands.

- **Client executor**:
  - Executes returned commands sequentially.
  - Uses existing app handlers (create/update/delete/toggle/save) to keep UI and state consistent.
  - Resolves entities by **name/title** to IDs on the client (v1 voice does not speak IDs).

### Data flow

1) User speaks/types text.
2) Client calls `POST /api/assistant` with `{ transcript, baseDateYmd }`.
3) Server returns:
   - `say`: short user-facing feedback
   - `commands`: allowlisted structured actions (max N)
4) Client executes commands in order; date commands affect later actions.
5) Client shows toasts and error messages; unmatched entities are non-fatal.

---

## Core API contract

### Endpoint

- **Method**: `POST`
- **Path**: `/api/assistant`
- **Auth**: required (cookie/session token or equivalent)
- **Content-Type**: `application/json`

### Request JSON

- **transcript**: `string` (required)
  - Raw user input (speech transcript or typed command).
  - Must be trimmed and size-limited by server (see Guardrails).
- **baseDateYmd**: `string` (required)
  - The client’s current selected date context.
  - Format: `YYYY-MM-DD`
  - Used for:
    - date-relative interpretation (“tomorrow”, “yesterday”)
    - logging/trace context
    - optional per-user hints (but must not be treated as auth)

Example:

```json
{
  "transcript": "tomorrow add must win task: renew passport",
  "baseDateYmd": "2026-01-05"
}
```

### Response JSON

- **say**: `string`
  - Short user-facing acknowledgement/explanation.
  - Should be safe to display verbatim.
- **commands**: `AssistantCommand[]`
  - Ordered list of commands to execute.
  - The client executes sequentially; order matters for date commands.
- **debug**: optional (only when explicitly enabled)
  - Used for diagnosing parsing issues; must not include secrets/tokens.

Example:

```json
{
  "say": "Got it — adding that task for tomorrow.",
  "commands": [
    { "kind": "date.shift", "days": 1 },
    { "kind": "task.create", "title": "renew passport", "taskType": "must-win" }
  ]
}
```

---

## Command schema (v1 allowlist)

### Requirements

- Commands MUST match one of the following kinds.
- Commands MUST be validated server-side (drop invalid commands).
- Commands MUST be capped (recommendation: max **5** commands per request).
- Commands MUST use user-friendly identity fields (name/title), not internal IDs.

### Union type

```ts
type TaskType = 'must-win' | 'nice-to-do';

type AssistantCommand =
  | { kind: 'date.shift'; days: number }                         // integer, -365..365
  | { kind: 'date.set'; ymd: string }                            // YYYY-MM-DD
  | { kind: 'habit.create'; name: string }                       // 1..140 chars
  | { kind: 'task.create'; title: string; taskType?: TaskType }  // 1..140 chars
  | { kind: 'task.setCompleted'; title: string; completed: boolean }
  | { kind: 'task.delete'; title: string }
  | { kind: 'habit.setCompleted'; name: string; completed: boolean }
  | { kind: 'reflection.append'; text: string }                  // 1..1500 chars
  | { kind: 'reflection.set'; text: string };                    // 0..4000 chars (empty allowed)
```

### Semantics and ordering

- **Date commands**
  - `date.shift` modifies the execution date relative to current selection.
  - `date.set` sets execution date to a specific day.
  - If a user says “tomorrow …”, the translator should emit a date command **first**, then the action(s).

- **Habits vs tasks**
  - `habit.create` is for recurring behaviors (“daily”, “every day”, “habit”, “track”, “start doing”).
  - `task.create` is for one-off items (“call mom”, “email Bob”, errands).
  - If ambiguous, default to `task.create` in v1 (safe; can be edited later).

- **Reflection**
  - `reflection.append` adds new text to the existing note with a newline.
  - `reflection.set` replaces the note content.

---

## Server-side translation requirements

### Authentication & authorization

- **Must require authenticated user** (same auth scheme as the rest of your API).
- **Must not** use the assistant endpoint as a bypass around normal per-table/per-route authorization.
- Recommended: keep assistant endpoint limited to translation only; all data mutations still flow through the existing secured APIs (or client handlers that call those APIs).

### Guardrails (required)

- **Origin allowlist check (CSRF/credit burn mitigation)**
  - Reject requests with an `Origin` header that is not on the allowlist.
  - If `Origin` is absent, you may allow (some clients omit it), but consider your threat model.
  - Purpose: prevent third-party sites from forcing a logged-in browser to spend AI credits.

- **Rate limiting**
  - Required per-user RPM limiting (e.g., 20 requests/min/user).
  - In-memory limiter is acceptable for dev/single-node; for multi-instance/serverless, use Redis/Upstash or a database-backed limiter.
  - On limit:
    - respond `429`
    - include `Retry-After` seconds header

- **Input limits**
  - Cap transcript length (recommendation: 2000 chars).
  - Cap `baseDateYmd` length (defensive).
  - Reject missing/empty fields with `400`.

- **Output validation**
  - Parse as JSON and validate:
    - `say` string length (recommendation: 240 chars)
    - `commands` array max length (recommendation: 5)
    - each command matches allowlist kind + type constraints
  - Drop unknown/invalid commands silently; do not execute them.

- **Timeouts and cost caps**
  - Use short timeouts (recommendation: 12 seconds).
  - Use low temperature (0) and conservative max tokens (recommendation: ~350).

### Translation strategies

#### Strategy A — LLM-backed translator (preferred when configured)

Requirements:

- Use a constrained system prompt:
  - “Return ONLY JSON, no markdown”
  - Provide the exact allowlisted command kinds and their shapes
  - Provide ordering rules (date commands first)
  - Provide classification guidance (habit vs task, taskType inference)
  - “Do not invent data”
- Expect and handle failure cases:
  - Non-200 response
  - Timeout
  - Non-JSON content
  - JSON that does not validate

Fallback behavior:

- If the LLM call fails (or API key missing), run the heuristic translator and return those commands.

#### Strategy B — heuristic translator (required fallback)

Purpose:

- Support a small set of typed commands for local/dev and as a resilience path.

Minimum recommended heuristics:

- date words: “tomorrow”, “yesterday”, “today” → `date.shift`
- task create:
  - “add task …”
  - “add must win task …”
  - “add nice to do task …”
- task complete:
  - “complete task …”
- reflection:
  - “note: …” or “reflection: …”
- habit create:
  - “add habit …”
  - “track …”
  - “X every day” → habit.create

---

## Client-side execution requirements

### Execution model

- Execute commands **sequentially** in the returned order.
- Maintain an `execDate` variable that starts as the currently selected date.
  - `date.shift` / `date.set` update `execDate` and update UI selection.
  - All subsequent action commands apply to `execDate`.

### How the client resolves title/name → ID

Because voice commands do not include IDs in v1, the executor must resolve:

- **Task commands referencing title**:
  - fetch tasks for the execution date (or use cached state if it is known complete)
  - attempt match in order:
    - exact case-insensitive match
    - substring containment match (prefer shortest matching title)
  - if no match:
    - show user-visible error (“Task not found …”)
    - continue executing remaining commands

- **Habit commands referencing name**:
  - fetch habits list
  - same matching strategy (exact then substring)
  - if no match: show error and continue

### Handlers / routes the executor must call

These are conceptual; map them to your system’s real APIs:

- **Task**
  - create task (for a date): `(title, type, ymd)`
  - update task (completed): `(id, { completed })`
  - delete task: `(id)`
- **Habit**
  - create habit: `(name)`
  - toggle completion (for a date): `(habitId, completed, ymd)`
- **Reflection**
  - save note (for a date): `(note, ymd)`; implement `append` on client by concatenation

### UX requirements

- **Typed fallback**: voice support is not universal; always provide a text input to run commands.
- **User feedback**
  - show the raw command text the user issued (toast/log)
  - show `say` returned by the assistant
  - show a final success toast if any commands were applied
- **Non-fatal errors**
  - if one command fails (e.g., entity not found), continue to the next command
  - surface the error clearly with the referenced title/name and date context

### Destructive actions

Minimum v1 safety:

- For `task.delete`, either:
  - require an explicit “delete …” transcript (already true), and/or
  - add a confirm UX step before executing delete commands.

Recommendation:

- Add “confirm before executing” when:
  - command list has > 1 action
  - any delete occurs
  - matches are ambiguous (multiple candidates)

---

## Configuration (environment variables)

This feature expects runtime configuration (names can be adapted in another system, but behavior should match).

- **OPENAI_API_KEY**: enable LLM translation
- **OPENAI_MODEL**: optional; default model set in code
- **ASSISTANT_ALLOWED_ORIGINS**: optional; comma-separated allowlist for Origin checks
- **ASSISTANT_RPM**: optional; per-user requests per minute
- **ASSISTANT_OPENAI_TIMEOUT_MS**: optional; request timeout
- **ASSISTANT_MAX_TRANSCRIPT_CHARS**: optional; input clamp size
- **ASSISTANT_DEBUG**: optional; enable debug fields in responses (never include tokens)

---

## Observability & telemetry requirements (recommended)

- **Structured logs** for assistant requests:
  - user id (or anonymized stable id)
  - time, request id
  - transcript length (not necessarily full transcript; consider privacy)
  - whether LLM vs heuristic was used
  - number of commands returned and number executed
  - latency and LLM error codes (if any)

- **Metrics**:
  - request count, rate limited count
  - average latency
  - parse failure rate
  - “not found” rate for title/name matching (helps improve prompts and UX)

---

## Security & privacy requirements

- **Never** return tokens, cookie values, or raw auth headers in debug output.
- If storing transcripts:
  - define retention policy
  - avoid storing full transcripts by default; store hashes or truncated snippets unless user opted in
- Enforce **Origin allowlist** and **rate limiting** to prevent abuse and runaway costs.
- Ensure assistant endpoint requires auth even in “demo” environments (or explicitly gate demo mode).

---

## Test plan / acceptance checklist

### API contract tests

- **400** when transcript missing/empty
- **400** when baseDateYmd missing/empty
- **403** when Origin is not allowed
- **429** when rate limit exceeded and `Retry-After` is present
- **200** and valid response when:
  - LLM enabled and returns valid JSON
  - LLM enabled but returns invalid JSON → safe error message + no commands (or heuristic fallback, per your policy)
  - LLM request fails → heuristic fallback commands

### Validation tests

- Unknown `kind` is dropped
- `date.shift.days` non-integer or out of range is dropped
- too-long `title/name/text` is clamped and still validated
- command list > max is truncated

### End-to-end UX tests

- Speech unavailable:
  - typed command still works
- “tomorrow add task X”:
  - date shifts first, then task created on that date
- “complete task X” where X doesn’t exist:
  - user sees “Task not found…”
  - the app does not crash
- “note: …”:
  - reflection is saved and visible

---

## Implementation notes for porting to another system

If your “other system” differs from this repo, keep the contracts stable:

- **Keep the assistant endpoint purely translational** (no privileged server-side execution in v1).
- **Preserve the allowlist**. Adding new commands is fine, but do it explicitly and version the schema.
- **Preserve deterministic client execution** through the same handlers/routes the UI uses.
- **Preserve date-context behavior** with ordered date commands.
- **Preserve title/name matching** with clear ambiguity and “not found” UX.

If you want, tell me what the “other system” is (stack + auth + where tasks/habits/reflections live), and I can tailor this document into a concrete spec (endpoints, schemas, and pseudo-code) for that environment.


