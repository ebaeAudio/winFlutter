## Implementation guide: Gemini “Capture → Today Plan” (WinFlutter)

### What we’re building
Add an **AI Capture** sheet on Today that accepts:
- **Text** (brain dump)
- **Photo/screenshot** (notes, whiteboard, typed list)

It calls a server-side Gemini integration that returns **strict JSON proposals**, which the Flutter client renders for review and then applies deterministically (create tasks/habits).

This guide is intentionally scoped to a **small test feature** with strong guardrails.

---

## Key constraints from this repo
- Use **Material 3** + existing theme (`lib/app/theme.dart`).
- Use `AppScaffold` for screens (`lib/ui/app_scaffold.dart`).
- Use spacing helpers (`lib/ui/spacing.dart`: `AppSpace`, `Gap`).
- Keep business logic outside widgets; keep widgets small/composable (`lib/ui/components/`).
- Prefer deterministic behavior; the AI proposes, the app executes.

---

## Capability choices (what we’ll showcase)
We’ll explicitly use:
- **Structured output (JSON Schema)** so we can validate and render proposals safely. (`response_mime_type=application/json` + schema)
- **Multimodal prompt** for photo imports (image + text parts).

Optional enhancements:
- **Streaming structured output** (partial JSON chunks) for progressive UI updates.
- **Function calling** (tool-style) — in this repo, we already treat “commands” as an allowlisted tool contract; you can also implement Gemini tools directly later.

Official docs:
- `https://ai.google.dev/gemini-api/docs/structured-output`
- `https://ai.google.dev/gemini-api/docs/function-calling`
- `https://firebase.google.com/docs/ai-logic` (recommended mobile SDK + proxy/App Check)

---

## Architecture (recommended for this repo)
### Why not call Gemini directly from Flutter (for this POC)
This repo’s existing Assistant keeps model keys in **Supabase Edge Function env** (Flutter doesn’t ship OpenAI keys). We’ll keep that same security posture.

### Proposed flow
1) Flutter gathers input (text and/or image bytes).
2) Flutter calls a Supabase Edge Function: `gemini_capture`.
3) Edge Function calls Gemini API (server-side key), requests structured JSON output.
4) Edge Function validates output and returns a safe response to Flutter.
5) Flutter shows a review UI, then applies proposals via existing repositories.

---

## Step 0: Decide your provider
You have two solid options:

- **Option A (fastest in this repo)**: Supabase Edge Function → Gemini Developer API  
  - Minimal new infra (Supabase is already core here).
  - Keys stay server-side.

- **Option B (Google-recommended mobile path)**: Firebase AI Logic (Flutter client SDK + proxy + App Check)  
  - Best long-term if you want deep Google ecosystem alignment.
  - More setup overhead (Firebase project + App Check).

This guide details **Option A** end-to-end, and outlines Option B at the end.

---

## Step 1: Add Edge Function skeleton (Supabase)
Create:
- `supabase/functions/gemini_capture/index.ts`
- `supabase/functions/_shared/gemini_capture_schema.ts`
- `supabase/functions/_shared/gemini_capture_validation.ts`

Mirror the patterns in `supabase/functions/assistant/index.ts`:
- auth required (JWT)
- CORS allowlist optional
- per-IP + per-user rate limiting
- strict input parsing + output validation

### Environment variables (Supabase Function secrets)
Add:
- `GEMINI_API_KEY` (server-side only)
- `GEMINI_MODEL` (e.g. `gemini-2.0-flash`, configurable)
- Optional: `GEMINI_TIMEOUT_MS`, `GEMINI_MAX_BODY_BYTES`

Keep these **out of Flutter**.

---

## Step 2: Define the structured output schema (JSON)
You want a schema that is:
- small (avoid huge nested structures at first)
- allowlisted (only supported actions)
- easy to validate (drop invalid items)

Recommended response shape:
- `say: string`
- `proposals: Proposal[]`
- `questions?: string[]`
- `notes?: string[]`

Where `Proposal` is one of:
- `{"kind":"task.create","title":string,"taskType":"must-win"|"nice-to-do","evidence"?:string}`
- `{"kind":"habit.create","name":string,"evidence"?:string}`

Notes:
- Keep proposal counts bounded (Must‑Wins ≤ 3, Nice‑to‑Do ≤ 5, Habits ≤ 3).
- Preserve user wording; do not invent specifics.
- Include `evidence` (short quote) to build user trust.

---

## Step 3: Call Gemini from the Edge Function
### Endpoint basics
Use the Gemini REST API to send:
- a **text-only** prompt (brain dump), or
- a **multimodal** prompt with an image.

Structured output docs describe:
- setting `response_mime_type` to `application/json`
- providing a JSON Schema for the response
- and that streamed chunks can be partial JSON (optional feature)

See: `https://ai.google.dev/gemini-api/docs/structured-output`

### Prompting guidelines (server-side)
Use a tight system prompt:
- “Return ONLY valid JSON matching the schema.”
- “Only propose allowlisted actions.”
- “Do not invent tasks; use user’s words.”
- “If uncertain, ask up to 2 questions.”

Then pass user content:
- `baseDateYmd` (the selected Today date)
- `timeAvailableMinutes` (optional)
- `constraintsText` (optional)
- input: `brainDumpText` and/or image

---

## Step 4: Validate response (server-side) and return safe output
Follow the existing assistant approach:
- Parse Gemini response as JSON.
- Validate strict schema.
- Enforce caps and drop invalid items.
- Return:
  - `say`
  - `proposals` (validated)
  - `questions`/`notes`
  - optionally `debug` in non-prod

Important: even if Gemini guarantees syntactically valid JSON, you still must validate semantics in your app (the Gemini docs explicitly recommend validating outputs).

---

## Step 5: Flutter UI (Today → AI Capture sheet)
### Files (suggested)
- `lib/features/today/widgets/ai_capture_sheet.dart`
- `lib/features/today/ai_capture_controller.dart` (Riverpod state + async call)
- `lib/assistant/gemini_capture_client.dart` (Supabase functions invoke wrapper)

### UI components
Use:
- `SegmentedButton` for Text/Photo
- `TextField` for brain dump + optional constraints
- “Choose photo / Take photo” button (requires an image picker package)
- Review list using `Card`, `ListTile`, and existing `SectionHeader` patterns

### Image picking
This repo doesn’t currently include an image picker dependency. For a mobile POC, add:
- `image_picker` (common choice)

Then:
- resize/compress before upload (keep request size bounded)
- show a small thumbnail + “remove” action

---

## Step 6: Flutter → Edge Function call
Match how `assistant` is called (see `docs/AI_COMMANDS_SETUP.md`):

- Use `Supabase.instance.client.functions.invoke('gemini_capture', body: …)`.
- Include:
  - `baseDateYmd`
  - `brainDumpText` (optional)
  - `imageBase64` + `mimeType` (optional)
  - `timeAvailableMinutes` (optional)
  - `constraintsText` (optional)

Handle:
- 401: user not logged in
- 429: rate limited
- 5xx: service failure
- schema validation errors (treat as retryable, show “Try text-only” fallback)

---

## Step 7: Apply proposals deterministically
On “Apply to Today”:
- For each proposal:
  - `task.create`: call your existing tasks repository create flow for the selected date + type.
  - `habit.create`: call habits/trackers creation flow (or treat as tracker creation if that’s the repo’s model).

De-dupe:
- if a task with same title already exists for the date/type, skip or prompt.
- if a habit/tracker exists by name, skip.

---

## Step 8: Testing
### Unit tests (server-side)
- Schema validation drops invalid proposals.
- Caps are enforced.
- Image too large is rejected cleanly.

### Flutter tests
- AI Capture sheet renders empty state, loading state, error state.
- Review → Apply creates the expected tasks/habits.

---

## Option B outline: Firebase AI Logic (Flutter)
If you want to integrate via Google’s recommended mobile SDK path:
- Start at: `https://firebase.google.com/docs/ai-logic`
- Firebase AI Logic provides client SDKs including **Dart for Flutter**, plus a **proxy service** and **App Check** integration to help prevent abuse and keep keys server-side when using the Gemini Developer API.

In practice:
- add Firebase to the Flutter app
- enable Firebase AI Logic in Firebase console
- use the Flutter client SDK to send prompts (text-only or multimodal)
- still keep the same “structured proposals → deterministic apply” pattern in the app

For this repo, you can still keep Supabase as the data backend and only use Firebase for AI calls if desired.

