# Security Risks — Win the Year (Flutter) (`winFlutter`)

## Why this doc exists

This repository is an **end-user app** that handles:
- authentication (Supabase Auth)
- user-generated content (tasks, habits, reflections, feedback)
- focus restriction controls (Android Accessibility / iOS Screen Time scaffolding)
- an “assistant” feature that translates natural text into allowlisted commands via a Supabase Edge Function

The goal of this document is to provide **extensive, shared context** about our system and its likely security vulnerabilities so:
- another AI (or auditor) can review our threat model and propose mitigations
- we can run a **monthly security audit** to prevent risky code from being published

This doc intentionally mixes:
- **system map** (what exists, where it lives)
- **current controls** (what we already do right)
- **risk register** (what can go wrong, severity/likelihood, recommended fixes)
- **audit process** (what to re-check monthly + before release)

---

## Quick “system map” (high level)

### Runtime modes
- **Demo mode** (`DEMO_MODE=true`): app treats user as signed-in and persists data locally.
- **Supabase mode** (`SUPABASE_URL` + `SUPABASE_ANON_KEY` configured): app uses Supabase Auth and can call Supabase Edge Functions.

### Major components (and where to read them)
- **Routing + auth gating**
  - `lib/app/router.dart`
  - `lib/app/auth.dart`
- **Environment configuration**
  - `lib/app/env.dart`
  - `assets/env.example` (copy to `assets/env`, which is git-ignored)
- **Supabase initialization**
  - `lib/app/supabase.dart`
- **Assistant (client)**
  - `lib/assistant/assistant_client.dart`
  - (execution happens in Today UI paths; see `docs/AI_COMMANDS_IMPLEMENTATION_REQUIREMENTS.md`)
- **Assistant (server / Edge Function)**
  - `supabase/functions/assistant/index.ts`
  - `supabase/functions/_shared/rate_limit.ts`
  - migrations for rate limiting: `supabase/migrations/20260109_000001_rate_limits.sql`
- **Local persistence (demo / local repositories)**
  - Tasks: `lib/data/tasks/local_all_tasks_repository.dart`
  - Habits: `lib/data/habits/local_habits_repository.dart`
  - Focus policies: `lib/data/focus/local_focus_policy_repository.dart`
  - (many other local repositories follow the same pattern; search `SharedPreferences`)
- **Feedback ingestion (Supabase table + RLS)**
  - Client: `lib/features/feedback/feedback_submitter.dart`
  - DB: `supabase/migrations/20260112_000001_user_feedback.sql`
- **Restriction engine (platform bridge)**
  - Dart channel: `lib/platform/restriction_engine/restriction_engine_channel.dart`
  - Android handler: `android/app/src/main/kotlin/com/wintheyear/win_flutter/MainActivity.kt`
  - iOS plugin: `ios/Runner/RestrictionEnginePlugin.swift`
- **NFC pairing (Dumb Phone Mode)**
  - `lib/platform/nfc/nfc_card_service.dart`
  - secure storage use: `lib/features/focus/dumb_phone_session_gate_controller.dart`

---

## Threat model (what we defend against)

### Primary assets (what we must protect)
- **Auth/session tokens** (Supabase session/JWT; stored by `supabase_flutter`)
- **User content**: tasks, habits, reflections, focus policies, tracker data, feedback drafts
- **Restriction configuration**: allowed apps list, friction settings, “card required” behavior
- **Service credentials** (server-side only):
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `OPENAI_API_KEY` (if LLM translation enabled)
- **Availability/cost**: assistant endpoint can be abused to burn OpenAI credits / exhaust resources

### Adversaries (realistic)
- **Malicious or curious user** with device access (root/jailbreak, adb backup, desktop access)
- **Third-party app** on the same device reading insecurely stored data (platform dependent)
- **Network attacker** (mitm on hostile Wi-Fi) — mitigated by TLS, but we still care about logging/leaks
- **Web-origin abuse** (if we run on Flutter Web) — CSRF-like “credit burn” and unwanted assistant calls
- **Misconfiguration** (the most common): shipping secrets into clients, permissive RLS, missing origin allowlist

### Trust boundaries (important)
- **Client app** (Flutter) is untrusted for secrets. Anything shipped to the client should be assumed public.
- **Supabase Edge Function** runs server-side and can hold secrets (service role, OpenAI key).
- **Supabase Postgres** enforces authorization via **RLS policies**; misconfigured RLS is catastrophic.

---

## Security controls we already have (positive inventory)

### Auth-gated navigation and safe “next” redirect
- Routing uses strict redirects based on auth/setup state.
- The `next` param is sanitized to a **safe, app-internal relative path**:
  - see `_safeRelativeLocationFromNextParam` in `lib/app/router.dart`.

### Assistant safety model (“translate only, execute deterministically”)
Design intent (see `docs/AI_COMMANDS_IMPLEMENTATION_REQUIREMENTS.md`):
- Server: translate transcript → allowlisted commands
- Client: execute commands via existing code paths (deterministic, auditable)

### Assistant Edge Function guardrails (server-side)
In `supabase/functions/assistant/index.ts`:
- **Auth required** (expects `Authorization: Bearer <JWT>`, validates via `supabase.auth.getUser()`)
- **Optional origin allowlist**
- **Rate limiting**
  - per-IP limiter + per-user limiter
  - durable limiter via Postgres RPC if `SUPABASE_SERVICE_ROLE_KEY` is configured
  - best-effort in-memory fallback otherwise
- **Input size limits** (content-length, body bytes, transcript chars)
- **Output validation** (drops invalid/unknown commands)
- **Timeouts** for OpenAI call

### RLS present for some tables (Supabase)
Good examples in migrations:
- `public.user_feedback` is **insert-only** with `auth.uid() = user_id`
  - `supabase/migrations/20260112_000001_user_feedback.sql`
- `public.trackers` and `public.tracker_tallies` have select/insert/update/delete policies scoped to `auth.uid()`
  - `supabase/migrations/20260106_000001_trackers.sql`
- `public.rate_limits` table has RLS enabled with **no policies** (clients cannot access)
  - `supabase/migrations/20260109_000001_rate_limits.sql`

### Secure storage used for the NFC paired-card hash
In `lib/features/focus/dumb_phone_session_gate_controller.dart`:
- stores only a **hash** (SHA-256 hex) in `flutter_secure_storage`
- explicitly avoids storing raw NFC tag contents

---

## Risk register (prioritized findings + recommended mitigations)

Severity scale used here:
- **Critical**: could expose other users’ data or ship server secrets; must fix before release
- **High**: realistic compromise of user privacy/security or major abuse/cost risk
- **Medium**: defense-in-depth gap; fix soon
- **Low**: best practice / hygiene

### 1) Client-side local persistence stores user content in plaintext (SharedPreferences)
- **Where**
  - Tasks: `lib/data/tasks/local_all_tasks_repository.dart`
  - Habits: `lib/data/habits/local_habits_repository.dart`
  - Focus policies: `lib/data/focus/local_focus_policy_repository.dart`
  - plus other files found via search for `SharedPreferences`
- **Why it matters**
  - SharedPreferences is not designed for secrets.
  - On rooted devices, via backups, or via device compromise, user content can be exfiltrated.
  - Even if “demo mode” is the primary user, code often drifts and becomes used beyond demo.
- **Severity**
  - **High** for privacy (depending on what we store: reflections can be sensitive).
- **Recommendations**
  - **Short-term**: document clearly that demo mode/local persistence is non-secure and should not store secrets.
  - **Medium-term**: migrate sensitive local content to an encrypted store:
    - Use platform keystores (Android Keystore / iOS Keychain) to wrap an encryption key.
    - Store encrypted blobs (tasks/habits/reflections) instead of raw JSON strings.
  - **Process**: treat any new `SharedPreferences.setString(...)` as a security review trigger.

### 2) Android restriction-engine session config is stored in SharedPreferences and is potentially tamperable
- **Where**
  - Android bridge persists restriction state to SharedPreferences:
    - `android/app/src/main/kotlin/com/wintheyear/win_flutter/MainActivity.kt`
    - keys like `allowedAppsJson`, `frictionJson`, `emergencyUntilMillis`, `cardRequired`
  - Enforcement reads the same prefs on every app switch:
    - `android/app/src/main/kotlin/com/wintheyear/win_flutter/focus/FocusAccessibilityService.kt`
  - Blocking UI provides bypass/escape actions based on `cardRequired` + friction settings:
    - `android/app/src/main/kotlin/com/wintheyear/win_flutter/focus/BlockingActivity.kt`
- **Why it matters**
  - If our enforcement layer (e.g., AccessibilityService) trusts these values blindly, a user with adb/root could tamper them to bypass restrictions.
  - If “focus mode” is a core safety feature, tamper resistance matters.
- **Severity**
  - **Medium → High** depending on how enforcement is implemented (we should audit the AccessibilityService code under `android/app/src/main/kotlin/.../focus/`).
- **Recommendations**
  - Move sensitive enforcement state to a tamper-resistant store (encrypted prefs) and/or validate state with signatures.
  - Treat the client as untrusted: enforcement should rely on OS-level signals where possible.
  - Add a “security notes” section for Focus mode clarifying what is and isn’t tamper-resistant.
  - If “ending early” is meant to be hard to bypass, reconsider the current scaffold behavior:
    - `BlockingActivity` long-press ends the session by setting `active=false` when `cardRequired` is off.
    - `Emergency unlock` sets an `emergencyUntilMillis` bypass window when `cardRequired` is off.

### 3) “Origin allowlist” is optional; misconfiguration can enable unwanted assistant calls (cost/CSRF-like risk)
- **Where**
  - `supabase/functions/assistant/index.ts` checks `Origin` only if `ASSISTANT_ALLOWED_ORIGINS` is set.
- **Why it matters**
  - In browser contexts, a third-party site could cause a logged-in user to call the assistant endpoint (“credit burn” / unwanted actions).
  - Mobile apps don’t typically send an `Origin` header; web does.
- **Severity**
  - **High** for cost abuse if Flutter Web is supported or if any browser client exists.
- **Recommendations**
  - For production deployments that include web, require an allowlist:
    - set `ASSISTANT_ALLOWED_ORIGINS` explicitly
    - consider rejecting requests that have an `Origin` header not in allowlist, and deciding policy for “missing origin”
  - Add a deployment checklist item: **do not deploy assistant without origin allowlist** (unless mobile-only).

### 4) Edge Function local dev command disables JWT verification (`--no-verify-jwt`)
- **Where**
  - Documented in `docs/AI_COMMANDS_SETUP.md` and `README.md`
- **Why it matters**
  - This is correct for local development, but it’s a classic “someone ships the dev config” footgun.
- **Severity**
  - **Medium** (process risk).
- **Recommendations**
  - Add a release checklist item: confirm deployed function requires auth (JWT verification enabled).
  - Consider adding explicit logging/warnings in dev serve output and documentation.

### 5) Supabase schema/RLS coverage may be incomplete across all user-data tables
- **Where**
  - We have migrations for trackers, feedback, rate-limits, and task extra columns.
  - The core tables described in `agentPrompt.md` (tasks/habits/habit_completions/daily_reflections/scoring_settings) are not all represented as migrations here.
- **Why it matters**
  - If tables exist in Supabase with missing/incorrect RLS, an attacker can read/write other users’ data using the public anon key.
- **Severity**
  - **Critical** if any production Supabase project has permissive RLS for core tables.
- **Recommendations**
  - Ensure every user table has:
    - `alter table ... enable row level security;`
    - policies scoped to `auth.uid()`
    - no “public read” policies unless explicitly intended
  - Add a monthly audit step: export and review RLS policies from the live project.

### 6) iOS local network + Bonjour permissions present in Info.plist (may be dev-only)
- **Where**
  - `ios/Runner/Info.plist` includes:
    - `NSLocalNetworkUsageDescription`
    - `NSBonjourServices` containing `_dartobservatory._tcp`
- **Why it matters**
  - Local network permissions expand the app’s perceived privacy surface and can raise App Store review questions.
  - Bonjour advertisement/service discovery can be sensitive if accidentally enabled in production builds.
- **Severity**
  - **Medium** (privacy/perception + potential dev-feature leakage).
- **Recommendations**
  - Ensure Dart VM service / observatory is not exposed in release builds.
  - Consider gating/removing local-network related plist entries for production, if feasible.

### 7) “Secrets in repo” guardrails: env example + build defines
- **Where**
  - `assets/env.example` contains a real-looking `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
  - `lib/app/env.dart` reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from `--dart-define` or dotenv.
- **Why it matters**
  - Supabase anon keys are “public”, but still enable access to whatever RLS permits; they should be treated as **shareable but not casually leaked** (screenshots/logs).
  - The bigger risk is accidentally introducing **service role** or other secrets into Flutter.
- **Severity**
  - **Medium** today; **Critical** if service role keys ever land in client code/assets.
- **Recommendations**
  - Add a lint/audit step that fails CI if any of these appear in `lib/`, `assets/`, or mobile native code:
    - `SUPABASE_SERVICE_ROLE_KEY`
    - `OPENAI_API_KEY`
    - `sb_secret_` patterns
  - Make it explicit in docs: anon key is OK in client, service role is not.

### 8) NFC pairing: fallback to tag UID hash can be spoofed or cloned in some cases
- **Where**
  - `lib/platform/nfc/nfc_card_service.dart` hashes either NDEF content or tag identifier bytes.
- **Why it matters**
  - Many NFC tags can be cloned; UID-based identification is not strong authentication.
  - This is acceptable for “lightweight friction”, but should not be framed as “secure”.
- **Severity**
  - **Medium** depending on product claims.
- **Recommendations**
  - Document that NFC pairing is a **convenience/friction mechanism**, not cryptographic authentication.
  - Prefer NDEF key material where possible; consider requiring higher entropy (already enforces >=16 bytes).
  - Consider challenge-response tags if we ever need stronger guarantees.

### 9) iOS restriction selection persistence in App Group UserDefaults
- **Where**
  - `ios/Runner/RestrictionEnginePlugin.swift` stores Screen Time selection in App Group defaults.
- **Why it matters**
  - App Group defaults are not a secret store; on a compromised device this can be read/modified.
- **Severity**
  - **Low → Medium** (privacy + integrity, depends on enforcement model).
- **Recommendations**
  - Treat selection as non-secret; avoid storing anything sensitive there.
  - If integrity matters, store a signed summary or migrate sensitive bits.

---

## Monthly security audit (repeatable checklist)

### 0) Scope and required artifacts
- Identify release target(s): iOS/Android/Web.
- Identify Supabase project(s): dev/staging/prod.
- Collect:
  - latest `supabase/` folder + migrations
  - current deployed Edge Function env vars (names only; never export secret values into tickets/docs)
  - current RLS policy export (SQL) from production

### 1) Secrets & key handling
- Confirm **no service role keys** are present anywhere client-side:
  - search repo for `SERVICE_ROLE`, `SUPABASE_SERVICE_ROLE_KEY`, `sb_secret_`, `OPENAI_API_KEY`
- Confirm `assets/env` remains git-ignored and not checked in.
- Confirm any screenshots/logs shared externally do not include:
  - `SUPABASE_ANON_KEY`
  - JWTs / `Authorization: Bearer`

### 2) Supabase RLS verification (highest priority)
- For every user table, confirm:
  - RLS enabled
  - policies are scoped to `auth.uid()`
  - no permissive `using (true)` reads unless explicitly intended
- Validate especially:
  - tasks / habits / habit_completions / reflections / settings / trackers / feedback

### 3) Edge Function hardening checks (`assistant`)
- Confirm deployed function:
  - requires auth (JWT verification enabled in production)
  - has `ASSISTANT_ALLOWED_ORIGINS` set (if any browser/web client exists)
  - has rate limiting enabled (db-backed preferred via service role key)
  - has conservative size limits (body bytes / transcript chars)
  - has safe debug behavior (`ASSISTANT_DEBUG=false` in prod unless actively debugging)
- Confirm OpenAI integration:
  - timeouts set
  - prompt is constrained (“return only JSON”, allowlist)
  - output validation remains strict

### 4) Mobile local-storage review
- Search for any new or expanded use of:
  - `SharedPreferences.setString` storing user content or identifiers
  - logging of sensitive values (tokens, keys, user data)
- Ensure anything “sensitive” is either:
  - server-side, or
  - encrypted at rest using platform keystores

### 5) Platform permissions & entitlements review
- iOS:
  - verify Screen Time capabilities/entitlements are correct and minimal
  - verify app group identifiers and storage usage
- Android:
  - review AccessibilityService implementation and configuration
  - validate that bypass paths are minimized and clearly communicated

### 6) Dependency / supply-chain check
- Review dependency changes since last audit:
  - Flutter/Dart packages in `pubspec.yaml` + `pubspec.lock`
  - Node deps for Supabase functions (npm imports) in `supabase/functions/**`
- Flag:
  - new network-facing dependencies
  - crypto/auth/storage libraries changes

### 7) Release gating rules (what blocks shipping)
- Any client-side presence of:
  - service role keys, OpenAI keys, admin credentials (**blocker**)
- Any production Supabase table containing user data without RLS (**blocker**)
- Any assistant endpoint deployed without auth requirements (**blocker**)
- Any discovered cross-user data access path (**blocker**)

---

## “Hand this to another AI” — suggested analysis prompt

Copy/paste this (and include this repo or the listed files):

> You are performing a security review for a Flutter app backed by Supabase and a Supabase Edge Function.
> 1) Build a threat model from `security risks.md`.
> 2) Verify whether the identified risks are real by reading the referenced files.
> 3) Propose prioritized mitigations with minimal product impact.
> 4) Produce a “release checklist” and “monthly audit checklist” improvements.
>
> Focus on: secrets handling, Supabase RLS correctness, assistant endpoint abuse/CSRF, local data at rest, and platform restriction-engine tamper resistance.

Key files to read first:
- `lib/app/router.dart`
- `lib/app/env.dart`
- `lib/assistant/assistant_client.dart`
- `supabase/functions/assistant/index.ts`
- `supabase/migrations/*.sql`
- `lib/data/**/local_*_repository.dart`
- `android/app/src/main/kotlin/com/wintheyear/win_flutter/MainActivity.kt`
- `ios/Runner/RestrictionEnginePlugin.swift`

