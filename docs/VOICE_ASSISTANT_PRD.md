### Voice Assistant PRD (Win Flutter)

### Executive summary
Win Flutter already supports a safe, deterministic “assistant” workflow: **user text → translate to allowlisted commands → execute via trusted app code**. This PRD adds a first-class **voice layer** so users can **speak to control the app end-to-end** (hands-busy, eyes-busy, low friction), while preserving safety, predictability, and privacy.

### Problem statement
Typing is slow and high-friction in the moments this app is most valuable: during planning, transitions, and when the user feels scattered. Users want to:
- quickly capture tasks/habits/notes by speaking
- mark items complete while moving
- navigate dates and run multi-step updates without “menuing”
- hear confirmation back (optional) without reading

### Goals
- **G1 — Full voice loop**: speak → app understands → app performs actions → app confirms (visually and optionally via voice).
- **G2 — Safe by design**: assistant remains a **translator**, never an unconstrained agent. Execution stays in existing client handlers.
- **G3 — Fast + delightful**: low-latency capture, clear “listening” affordances, easy correction, confidence-building previews.
- **G4 — Works everywhere**: iOS + Android, with a typed fallback; graceful degradation when speech is unavailable.
- **G5 — Privacy-forward**: transparent permissioning; minimal retention; opt-in for storing audio/transcripts.

### Non-goals (v1)
- Always-on hotword (“Hey Win”) in the background.
- Unlimited command set across every screen without explicit allowlisting.
- Arbitrary “agentic” behavior (tool use, browsing, ad-hoc workflows).

### Current system (baseline)
- **Translation**: `AssistantClient.translate()` calls Supabase Edge Function `assistant` (LLM when configured, heuristic fallback).
- **Command allowlist**: strict kinds like `task.create`, `habit.create`, `reflection.append`, `date.shift`, etc.
- **Execution**: `AssistantExecutor.execute()` runs commands sequentially, includes confirmations for deletes / multi-action sequences.
- **UI entry point**: `TodayScreen` has an “Assistant” text field and “Run” button.

### Target users & jobs-to-be-done
- **Busy planner**: “Add three tasks while walking into work.”
- **Distracted / ADHD-friendly user**: “Dump thoughts into reflection, then turn them into tasks.”
- **Hands-busy**: cooking, commuting, parenting; wants one-tap push-to-talk.
- **Accessibility**: motor limitations or preference for voice.

### Experience principles
- **One gesture to speak** (push-to-talk by default).
- **Show what we heard** (editable transcript) before irreversible changes.
- **Confirm outcomes** (visual toasts + optional spoken confirmations).
- **Never surprise-delete** (explicit confirmations, always).
- **Recoverable errors** (helpful prompts + disambiguation UI).

---

### Product scope

### v1 Voice MVP (Push-to-talk + transcript + run)
Adds a microphone affordance to the existing Assistant card on `TodayScreen`.

#### Core features
- **Push-to-talk mic button**
  - Tap-and-hold or tap-to-start / tap-to-stop (final decision in UX section).
  - Clear “Listening…” state with elapsed time, animated waveform, and cancel.
- **Speech-to-text (STT) → transcript field**
  - Transcript is inserted into the existing assistant input field.
  - User can edit the transcript before running (always).
- **Run voice command**
  - Same as “Run” today: transcript → translate → preview/confirm (when needed) → execute.
- **Optional read-back (TTS)**
  - If enabled, speak the assistant’s `say` string (“Got it.” / “Added task…”).
  - Speak the *result summary* (e.g., “Done, 2 changes.”) when actions executed.

#### Supported intents (initial)
Start with the existing allowlist (already implemented):
- **Dates**: today/tomorrow/yesterday, explicit `YYYY-MM-DD`
- **Tasks**: create, complete/uncomplete, delete
- **Habits**: create, complete/uncomplete
- **Reflection**: append and set

#### Voice-friendly utterance examples
- “Tomorrow add must win: renew passport”
- “Complete task: send the invoice”
- “Note: shipped v1, felt good, do it again tomorrow”
- “Add habit: walk 20 minutes daily”
- “Delete task: cancel gym membership” (must confirm)

---

### v1.5 “Feels magical” upgrade (Streaming + smart confirmations)
Improve responsiveness and reduce errors without expanding scope.
- **Streaming partial transcript** while listening (shows live words).
- **Auto-stop on silence** (VAD) with a short grace period.
- **Action preview sheet** (“I’m about to: set date to tomorrow; add task ‘renew passport’…”) when:
  - multi-action sequences
  - any delete
  - ambiguous match (multiple tasks/habits match)
- **Disambiguation UI**
  - When a command references “call mom” and multiple tasks match, show a picker.
- **“Say again / retry”**
  - If translation returns no commands, propose 2–3 example phrases contextual to the current date.

---

### v2 “Interact fully with the app” (Expanded allowlist + cross-screen actions)
This is how voice becomes a full controller, while staying safe (explicit allowlist + deterministic execution).

#### New command categories (proposed additions)
- **Navigation**
  - “Go to Today”, “Go to Settings”, “Open Focus”, “Show tomorrow”
  - `nav.go { route }`, `date.set`, `date.shift`
- **Focus mode**
  - “Start focus mode”, “Exit focus mode”, “Set focus task to ‘X’”
  - `focus.setEnabled { enabled }`
  - `focus.setTask { title }`
- **Editing**
  - “Rename task ‘X’ to ‘Y’”
  - `task.rename { fromTitle, toTitle }` (or `task.updateTitle`)
- **Bulk operations**
  - “Complete all Must-Wins”
  - `task.completeMany { filter }` (must confirm)
- **Help / examples**
  - “What can I say?” → show a voice cheatsheet.

#### Conversational follow-ups (still safe)
Introduce a lightweight “slot filling” UX:
- User: “Add task” → App: “What’s the title?” (voice or typed)
- User: “Complete” → App: “Which task?” with suggestions

---

### User experience design

### Entry points
- **Primary (v1)**: `TodayScreen` → Assistant card:
  - mic button next to input or as a leading icon inside the field
  - “Run” stays as the explicit execution action
- **Secondary (v2)**:
  - global floating mic (optional)
  - quick action on home / nav shell

### Listening interaction (v1 decision)
Choose one and keep consistent across platforms:
- **Option A — Tap-to-toggle (recommended)**:
  - Tap mic: starts listening
  - Tap again: stops + finalizes transcript
  - Pros: one-handed, accessible; no long-press dexterity requirement
- **Option B — Press-and-hold**:
  - Hold to talk, release to stop
  - Pros: familiar walkie-talkie; reduces accidental background capture

### States
- **Idle**: mic icon visible; hint text shows example commands.
- **Listening**: timer + waveform; “Cancel” action; optional “Stop” action.
- **Processing**: spinner + “Working…” (already present); mic disabled.
- **Result**:
  - show `say` text in Assistant card (already present)
  - snackbars for executed count / first error (already present)
  - optional TTS read-back

### Safety UX rules
- **Always confirm**:
  - any delete
  - any bulk command (multi-item changes)
  - any sequence with >1 “action” command (date commands excluded)
- **Prefer preview over irreversible action** when confidence is low:
  - ambiguous entity match
  - low-confidence STT (if available) or noisy transcript

### Editing & repair
- Transcript is editable pre-run.
- After-run: offer “Undo” where feasible (v2) or “Run another command”.

---

### Functional requirements

### Voice capture (client)
- Must request microphone permission only when user taps mic (no surprise prompts).
- Must provide clear in-app explanation if permission denied (and link to settings).
- Must support cancellation that discards partial transcript.

### Speech-to-text (STT)
The app must produce a transcript string suitable for `AssistantClient.translate()`.

#### STT implementation options
- **Option 1 — On-device / platform STT (recommended for MVP)**
  - iOS: Apple Speech framework via a Flutter plugin
  - Android: Android SpeechRecognizer via plugin
  - Pros: low cost; better privacy; works without server audio handling
  - Cons: quality varies by device; language support varies; streaming may vary
- **Option 2 — Cloud STT (Whisper / equivalent) via Supabase**
  - Client records short audio clip → upload → server transcribes → feed transcript into existing assistant translation
  - Pros: consistent quality; unified behavior
  - Cons: higher cost; higher latency; more privacy considerations; more infra

**MVP decision**: start with Option 1; keep Option 2 as a future toggle for “High accuracy mode”.

### Text-to-speech (TTS)
- When enabled, speak:
  - `translation.say` (short)
  - optional execution summary (“Done: 2 changes.”)
- Must respect:
  - device mute / accessibility settings (where possible)
  - user setting: off by default (recommended)

### Assistant translation & execution (existing)
- Keep existing allowlist + validation model.
- Preserve sequential execution and date context behavior.
- Preserve confirmation requirements in executor.

---

### Platform requirements

### iOS
- Add `NSMicrophoneUsageDescription` to `ios/Runner/Info.plist`.
  - Suggested copy: “Win Flutter uses the microphone to let you speak tasks, habits, and reflections hands‑free.”
- If using iOS Speech framework, also add `NSSpeechRecognitionUsageDescription` (copy aligned with above).

### Android
- Add `<uses-permission android:name="android.permission.RECORD_AUDIO" />` to `android/app/src/main/AndroidManifest.xml`.
- If using on-device speech recognition services, verify any additional permissions required by chosen plugin.

### Flutter dependencies (to be decided at implementation)
- Add an STT package (platform or cross-platform).
- Add a TTS package for read-back.
- (Optional) Add `permission_handler` if not already present, or use plugin-native permission flows.

---

### Technical design (proposed)

### High-level architecture
1) **Capture**: user presses mic → record/recognize speech → transcript (streaming partials if supported).
2) **Translate**: feed transcript into `AssistantClient.translate(transcript, baseDateYmd)`.
3) **Preview/confirm**: show action sheet when required by safety rules.
4) **Execute**: `AssistantExecutor.execute(...)` runs commands.
5) **Feedback**: show `say` + toasts; optionally speak via TTS.

### Data model changes
- **No schema changes required for v1**.
- v2 may add:
  - assistant history (transcript + commands + executed outcomes) as opt-in
  - “undo” support (requires operation log)

### Settings (proposed)
Add to Settings screen:
- **Voice input**: On/Off (default On if permissions granted; otherwise Off)
- **Spoken confirmations**: Off/On (default Off)
- **Speech language**: System default (optional)
- **High accuracy mode (cloud STT)**: Off/On (future)
- **Privacy**:
  - “Store transcripts in history” (default Off)
  - “Store audio clips” (default Never)

---

### Privacy, security, and compliance
- **Permission transparency**: explain why microphone is needed at the moment of request.
- **Retention**:
  - Default: do not store audio; do not store transcripts beyond local UI state.
  - Optional history (v2): opt-in with clear retention controls.
- **Backend safety**:
  - Maintain assistant Edge Function guardrails: auth required, origin allowlist, per-user rate limiting, input/output validation.
- **Abuse prevention**:
  - throttle repeated mic-to-translate calls
  - handle accidental “open mic” scenarios with clear UI indicators

---

### Non-functional requirements
- **Latency targets**
  - STT finalize (short utterance): < 1.5s typical after stop
  - Translate call: < 2.0s p50, < 5.0s p95 (network permitting)
  - Total “tap mic → action executed”: < 6s p50 for single-action commands
- **Reliability**
  - If STT fails, user can type and still run assistant.
  - If translation fails, heuristic fallback provides safe minimal behavior.
- **Battery**
  - No background listening in v1; no persistent audio sessions.
- **Accessibility**
  - Works with screen readers; clear labels: “Start listening”, “Stop listening”, “Cancel listening”.

---

### Analytics & success metrics
Measure without storing raw audio by default.
- **Adoption**
  - % of active users who use voice weekly
  - voice sessions per day
- **Effectiveness**
  - command execution success rate
  - “no commands returned” rate
  - disambiguation rate
  - cancellation rate
- **Speed**
  - end-to-end latency p50/p95
- **Retention impact**
  - task/habit/reflection creation rate change after voice enablement

---

### Rollout plan

### Phase 0 — Design + instrumentation
- Finalize STT/TTS dependency choices.
- Define event schema (voice_started, voice_stopped, transcript_finalized, translate_success, execute_success).

### Phase 1 — MVP in Today Assistant
- Add mic button + listening UI + permission flows.
- Insert transcript into existing assistant text field.
- Keep “Run” as explicit execution.
- Add optional TTS setting (off by default).

### Phase 2 — Quality
- Streaming partials + silence auto-stop (if supported).
- Action preview & disambiguation UI.
- Better empty/failed translation guidance.

### Phase 3 — Full app interaction (expanded allowlist)
- Add navigation/focus/edit/bulk commands with explicit allowlisting and confirmations.
- Add conversational follow-up prompts for missing information.

---

### Open questions (need product decisions)
- **Push-to-talk gesture**: tap-to-toggle vs press-and-hold?
- **Default spoken confirmations**: off by default (recommended) or on?
- **Cloud STT**: do we want an accuracy toggle, and what’s the cost envelope?
- **Assistant history**: do we want a transcript/action log for transparency and undo?
- **Wake word**: do we ever want hands-free background activation (likely v3+ only)?

---

### Acceptance criteria (v1)
- User can tap mic, speak, see transcript populated, tap Run, and have at least one command execute successfully.
- Mic permission prompts are shown only after user intent and are gracefully handled when denied.
- Destructive commands still require explicit confirmation before execution.
- Typed assistant continues to work exactly as before.


