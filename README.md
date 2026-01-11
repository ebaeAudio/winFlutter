## Win the Year (Flutter) — `win_flutter`

A mobile-first rebuild of the **Win the Year** daily execution app.

The app is designed to help you “win today” via:
- **Must‑Wins** (critical) + **Nice‑to‑Dos** (optional) per date
- **Habits** (global list) with per-day completion
- **Reflection** notes per date (auto-saves)
- **Focus mode (“Dumb Phone Mode”)** scaffolding for app restrictions (platform-dependent)
- **Assistant** (typed commands) that translates simple natural-ish input into deterministic actions

If you want the detailed product spec and scoring rules, start with `agentPrompt.md`.

### Table of contents
- **Start here**: [Project status](#project-status), [Quick start](#quick-start)
- **Tour**: [What’s implemented today](#whats-implemented-today), [Routing + auth gating](#routing--auth-gating)
- **Setup**: [Demo vs Supabase mode](#demo-vs-supabase-mode), [Environment configuration](#environment-configuration), [Supabase](#supabase-setup)
- **Assistant**: [AI Commands / Assistant](#ai-commands--assistant)
- **Focus**: [Restriction engine (Focus / Dumb Phone Mode)](#restriction-engine-focus--dumb-phone-mode)
- **Dev guide**: [Project structure](#project-structure), [Common commands](#common-commands), [Troubleshooting](#troubleshooting)
- **Ops**: [Security & secrets](#security--secrets)

---

## Project status

This repo is an **active scaffold/MVP** with working navigation, auth gating, theme persistence, and a usable Today screen (local data) plus an Assistant UI.

- **Product spec (authoritative)**: `agentPrompt.md`
- **Buildout roadmap/checklist**: `IMPROVEMENTS_CHECKLIST.md`
- **Assistant deep dive**: `docs/AI_COMMANDS.md` + `docs/AI_COMMANDS_SETUP.md` + `docs/AI_COMMANDS_IMPLEMENTATION_REQUIREMENTS.md`

---

## Quick start

### Prerequisites
- **Flutter SDK** installed and on PATH (`flutter doctor` should be mostly green)
- Platform toolchains as needed:
  - iOS/macOS: Xcode + CocoaPods
  - Android: Android Studio / SDK
  - Web: Chrome
  - Windows: Visual Studio toolchain

### Install dependencies

```bash
flutter pub get
```

### Run

By default, demo mode is **off** (unless you explicitly enable it via `DEMO_MODE=true`).

```bash
flutter run
```

Optional (demo mode):

```bash
flutter run --dart-define=DEMO_MODE=true
```

---

## What’s implemented today

High-signal “what works right now” snapshot:

- **Navigation**: `go_router` routes for Home, Today, Rollups, Settings, Focus, Auth, and Setup.
- **Auth gating**:
  - Demo mode: always treated as signed in.
  - Supabase not configured: routes redirect to Setup with instructions.
  - Supabase configured: Auth screen supports sign in / sign up / magic link.
- **Today screen**:
  - Date navigation (prev/next + date picker + go-to-today).
  - Local tasks (Must‑Win / Nice‑to‑Do): add/edit/move/delete + complete.
  - Local habits: add + daily completion toggles.
  - Reflection field: auto-saves on blur.
  - Assistant input: translates and executes allowlisted commands.
  - Focus mode UI: selects a current “focus task” and offers “Done / Pick different / Exit”.
- **Settings**:
  - Theme mode (system/light/dark) and palette swatches (Slate/Forest/Sunset/Grape).

If you’re looking for “what’s next”, the checklist is intentionally explicit: `IMPROVEMENTS_CHECKLIST.md`.

---

## Routing + auth gating

The routing model is intentionally strict so the app always lands in a coherent state:

- `DEMO_MODE=true` ⇒ signed in as a demo user (no Supabase required).
- If Supabase is not configured ⇒ redirect to `/setup`.
- Otherwise ⇒ require a Supabase session; redirect to `/auth` if signed out.

Implementation references:
- `lib/app/router.dart` (redirect rules)
- `lib/app/auth.dart` (demo mode vs setup-required vs real session)
- `lib/features/setup/setup_screen.dart` (user-facing setup instructions)

---

## Demo vs Supabase mode

This app can run in two broad modes:

- **Demo mode** (`DEMO_MODE=true`)
  - Designed for local/dev use without any Supabase project.
  - The app behaves as a “demo user”.
  - Note: demo persistence is currently evolving (see `IMPROVEMENTS_CHECKLIST.md` section 3).

- **Supabase mode** (configure `SUPABASE_URL` + `SUPABASE_ANON_KEY`)
  - Enables Supabase Auth and Supabase Edge Function calls (for the Assistant translator when enabled).
  - The Flutter app initializes Supabase only when both values are present.

---

## Environment configuration

The Flutter app reads environment values from **either**:

1) **Compile-time defines** (recommended for Web and CI)

```bash
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=DEMO_MODE=false
```

2) **Local dotenv file**: `assets/env` (git-ignored)

- Copy: `assets/env.example` → `assets/env`
- Fill in values

Notes:
- On **Flutter Web**, the app intentionally does **not** load `assets/env` (to avoid noisy missing-asset console errors). Use `--dart-define` for web.
- See the source of truth for env precedence in `lib/app/env.dart` and `lib/main.dart`.

---

## Supabase setup

At minimum (for auth + configured client initialization), you need:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

The longform backend schema + behavior expectations (tasks/habits/reflections/scoring) are documented in:
- `agentPrompt.md` (tables, RLS expectations, scoring model)

### Run with Supabase configured

```bash
flutter run
```

If Supabase is not configured, the Auth screen will show a warning banner and sign-in actions are disabled (by design).

---

## AI Commands / Assistant

The Assistant is intentionally designed with guardrails:
- **Server translates** transcript → allowlisted structured commands
- **Client executes** those commands through trusted app code paths (deterministic)

In Flutter:
- UI + execution live on the Today screen (`lib/features/today/today_screen.dart`)
- The client chooses translation strategy:
  - **Remote translator** via Supabase Edge Function (when Supabase is configured and demo mode is off)
  - **Local heuristic fallback** otherwise

### Supabase Edge Function (`assistant`)

Edge function implementation:
- `supabase/functions/assistant/index.ts`

Local serve (requires Supabase CLI):

```bash
supabase functions serve assistant --no-verify-jwt
```

Deploy:

```bash
supabase functions deploy assistant
```

Where configuration lives:
- **Flutter app does NOT need OpenAI keys**
- OpenAI + guardrails are configured as **Supabase Function environment variables**

Common Function env vars (set in Supabase for the deployed function):
- Required:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
- Optional (recommended):
  - `OPENAI_API_KEY` (enables LLM translation; otherwise heuristic fallback)
  - `OPENAI_MODEL` (default: `gpt-4o-mini`)
  - `ASSISTANT_ALLOWED_ORIGINS` (Origin allowlist)
  - `ASSISTANT_RPM` (per-user rate limit; default `20`)
  - `ASSISTANT_MAX_TRANSCRIPT_CHARS` (default `2000`)
  - `ASSISTANT_OPENAI_TIMEOUT_MS` (default `12000`)
  - `ASSISTANT_DEBUG` (`true` to include debug output; never includes secrets)

Details:
- `docs/AI_COMMANDS_SETUP.md` (how to run/deploy + env vars)
- `docs/AI_COMMANDS_IMPLEMENTATION_REQUIREMENTS.md` (portable contract + safety model)

---

## Restriction engine (Focus / Dumb Phone Mode)

This repo includes a platform abstraction for enforcing focus restrictions:
- Dart interface: `lib/platform/restriction_engine/restriction_engine.dart`
- Method channel implementation: `lib/platform/restriction_engine/restriction_engine_channel.dart`
- Channel name: `win_flutter/restriction_engine`

### iOS (Screen Time)
- Native plugin scaffold: `ios/Runner/RestrictionEnginePlugin.swift`
- Uses Screen Time frameworks when available (`FamilyControls`, `ManagedSettings`, `DeviceActivity`)
- **Important**:
  - Screen Time authorization is not supported in the iOS Simulator; use a physical device.
  - Missing entitlements/capabilities can cause authorization failures.

### Android (AccessibilityService)
- Method channel handler: `android/app/src/main/kotlin/com/wintheyear/win_flutter/MainActivity.kt`
- Stores session configuration in SharedPreferences for a native AccessibilityService to enforce.
- There is additional Android focus engine code under:
  - `android/app/src/main/kotlin/com/wintheyear/win_flutter/focus/`

This feature is still evolving; expect behavior and UX to change as focus policies and allowlists are refined.

---

## Project structure

High-level layout:
- `lib/app/`: app composition + env/auth/router/theme/bootstrap
- `lib/features/`: screens and feature logic (Today, Rollups, Settings, Focus, Auth, Setup)
- `lib/ui/`: shared UI primitives (scaffold, spacing, components)
- `lib/assistant/`: assistant models/client/executor/matching
- `lib/platform/`: platform abstractions and channels (restriction engine)
- `supabase/functions/`: Supabase Edge Functions (assistant)
- `assets/`: local env + any bundled assets
- `docs/`: assistant docs and implementation requirements
- `test/`: unit/widget tests

---

## Common commands

### Get packages

```bash
flutter pub get
```

### Run

```bash
flutter run
```

### Run in demo mode

```bash
flutter run --dart-define=DEMO_MODE=true
```

### Run on web (use `--dart-define` for env)

```bash
flutter run -d chrome --dart-define=DEMO_MODE=true
```

### Run tests

```bash
flutter test
```

---

## Security & secrets

- `assets/env` is **git-ignored** and should contain any local development secrets.
- `assets/env.example` is safe to commit and should contain only placeholders.
- **OpenAI keys never belong in the Flutter app**. If you enable LLM translation, set `OPENAI_API_KEY` on the **Supabase Edge Function** environment instead.
- If you’re publishing screenshots/logs, avoid including `SUPABASE_ANON_KEY` or any JWTs.

---

## Troubleshooting

### “Supabase isn’t configured” banner
- Add `SUPABASE_URL` and `SUPABASE_ANON_KEY` via `assets/env` or `--dart-define`.
- Confirm you’re not relying on `assets/env` on Flutter Web (it’s skipped on purpose).

### iOS Screen Time authorization fails
- Run on a **physical device** (simulator cannot authorize Family Controls).
- Confirm your Xcode project has the required capabilities/entitlements for Screen Time.

### Android focus restrictions don’t apply
- Ensure the AccessibilityService is enabled (the app will route you to Accessibility settings).
- Verify the app is running a build variant that includes the focus engine service.

---

## Where to go next

- **Buildout roadmap**: `IMPROVEMENTS_CHECKLIST.md`
- **Authoritative product spec**: `agentPrompt.md`
- **Assistant docs**: `docs/AI_COMMANDS_SETUP.md`