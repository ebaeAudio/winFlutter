## PRD: Gemini “Capture → Today Plan” (Flutter GenAI showcase)

### Summary
Add a small, high-impact “**AI Capture**” feature on the Today screen that turns **messy input** (typed brain-dump *or* a photo/screenshot of notes) into a **reviewable plan**: Must‑Wins, Nice‑to‑Dos, optional Habits, and (optionally) a time‑boxed schedule. The user always reviews/edits before anything is created.

This is designed to showcase Google’s Gemini capabilities that matter in a real app:
- **Multimodal understanding** (image + text prompts) via Gemini models.
- **Structured outputs (JSON Schema)** for deterministic, typed extraction.
- **Tool / function-calling style workflows** (we model this as an allowlisted “commands” schema the app executes deterministically).

### Why this is a “thinking hard” showcase
This feature forces the model to do more than paraphrase:
- **Extract** actionable tasks from ambiguous, messy notes.
- **De-duplicate + normalize** (merge duplicates, keep user wording).
- **Prioritize** (limit Must‑Wins to 1–3, make tradeoffs explicit).
- **Schedule** (optional) with constraints (available time, meetings, energy).
- **Be honest about uncertainty** (confidence + evidence text snippets).

### Goals
- **G1**: Convert unstructured input into a structured, reviewable “Today plan” in < 15 seconds.
- **G2**: Keep execution deterministic and safe: the model **cannot** directly mutate data; it only proposes allowlisted actions.
- **G3**: Demonstrate Gemini’s strengths (multimodal + structured output) in a way that feels native to Win the Year (Today/Must‑Win/Nice‑to‑Do/Habits/Reflection).

### Non-goals
- Replace the existing Assistant (the text command translator).
- Automatically complete/delete tasks without explicit user confirmation.
- Perfect handwriting OCR; we’ll provide a best-effort flow with clear error handling.

---

## User stories
- **US1 (Brain dump)**: As a user, I can paste a messy list of thoughts and get a clean set of Today tasks categorized as Must‑Win vs Nice‑to‑Do.
- **US2 (Photo capture)**: As a user, I can attach a photo/screenshot of notes and the app extracts tasks (with “evidence” quotes) so I trust what it captured.
- **US3 (Planning)**: As a user, I can optionally enter “time available today” and get a simple time‑boxed plan for my Must‑Wins.
- **US4 (Safety)**: As a user, I can review/edit before applying changes, and I can discard everything with one tap.

---

## UX / Flow (Today screen)
### Entry points
- Add a small action on Today (e.g. under the score card, or in the Assistant section):
  - **Button**: “AI Capture”
  - **Icon**: `Icons.auto_awesome`

### AI Capture sheet
Use Material 3 + `AppScaffold` patterns and repo spacing (`Gap`, `AppSpace`).

- **Step 1: Input**
  - Tabs or segmented control:
    - **Text**: multiline field (“Paste a brain dump…”)
    - **Photo**: “Choose photo / Take photo”
  - Optional fields:
    - “Time available today (minutes)”
    - “Hard constraints (optional)” (e.g., “meeting 3–4pm”)

- **Step 2: Generate (loading state)**
  - Inline progress + cancel:
    - “Extracting tasks…”
    - “Organizing Must‑Wins…”
  - If generation fails: show a calm error and a retry button.

- **Step 3: Review & apply**
  - Sections:
    - **Must‑Wins** (max 3) — editable titles
    - **Nice‑to‑Do** (max 5) — editable titles
    - **Habits** (optional, max 3) — editable names
    - **Plan** (optional) — time blocks + short rationale
    - **Questions** (0–2) — if model needs clarification
  - Each extracted item shows a small “Evidence” chip:
    - Tap to reveal the snippet the model extracted from (text span or “best guess”).
  - Actions:
    - **Apply to Today** (creates tasks/habits)
    - **Discard**

### Accessibility + quality bars
- Touch targets >= 44px, clear labels, full keyboard support on text fields.
- Error states are explicit and actionable (retry, switch to text, remove photo).
- No spooky action: nothing changes until “Apply”.

---

## Data contract (model → app)
The model must return **strict JSON** (structured output), validated client-side/server-side:

- **Top-level**:
  - `say`: short user-facing summary (1–2 sentences, calm tone)
  - `proposals`: list of allowlisted proposed actions
  - `questions`: optional clarifying questions (0–2)
  - `notes`: optional warnings/uncertainty

- **Proposals (allowlist)**:
  - `task.create { title, taskType: "must-win" | "nice-to-do" }`
  - `habit.create { name }`
  - (Optional phase 2) `reflection.append { text }`

Constraints:
- Max 3 Must‑Win tasks, max 5 Nice‑to‑Do tasks, max 3 habits.
- Titles/names should be based on user input; no invented specifics.
- The app validates, de-dupes, and can drop invalid items.

---

## Technical approach (recommended for this repo)
This repo already uses a **Supabase Edge Function** to translate Assistant input into allowlisted commands. We mirror that pattern:

- Flutter collects input (text and/or image bytes).
- Flutter calls `Supabase.instance.client.functions.invoke('gemini_capture', …)`.
- Edge function calls Gemini (server-side key), requests **structured JSON** output, validates response, and returns the JSON to Flutter.
- Flutter renders review UI and applies proposals using existing task/habit repositories.

Why this approach:
- Matches existing guardrail model (allowlisted commands + deterministic executor).
- Keeps API keys off-device (consistent with current assistant setup).

---

## Security / privacy
- **No secrets in Flutter**: Gemini key lives in Edge Function secrets.
- **Rate limiting**: per-user + per-IP (mirror assistant).
- **Input limits**: cap text length and image size (compress/resize client-side).
- **User consent**: explicitly state that photos/text are sent to the AI service to generate suggestions.
- **Logging**: avoid logging raw user content; only log request ids and failure modes.

---

## Success metrics
- **Activation**: % of users who open AI Capture after seeing it.
- **Completion**: % who reach “Apply to Today”.
- **Edits**: median number of edits (high edits may indicate low extraction quality).
- **Time-to-plan**: time from “Generate” → “Apply”.
- **Error rate**: API failures, validation failures, timeouts.

---

## Milestones
- **M1 (Text-only)**: Paste brain dump → review → create tasks.
- **M2 (Multimodal)**: Add photo import; show evidence; handle common failures.
- **M3 (Optional)**: Add simple time‑boxed plan output and/or reflection suggestion.

---

## References (official docs)
- Firebase AI Logic (client SDKs incl. Dart/Flutter, proxy + App Check): `https://firebase.google.com/docs/ai-logic`
- Gemini API: Structured outputs (JSON Schema + streaming partial JSON): `https://ai.google.dev/gemini-api/docs/structured-output`
- Gemini API: Function calling (tools/actions patterns): `https://ai.google.dev/gemini-api/docs/function-calling`
- Dart package note (deprecated Google AI Dart SDK): `https://pub.dev/packages/google_generative_ai`

