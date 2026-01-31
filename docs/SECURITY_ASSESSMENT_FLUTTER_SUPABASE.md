# Flutter + Supabase Security Assessment

**Scope:** Win the Year Flutter app (mobile + Supabase backend)  
**Model:** Red-team style — realistic attacker, exploitability + business impact  
**Standards:** OWASP Mobile Top 10, OWASP API Security Top 10, CWE, cloud best practices

---

## Executive Summary

The app uses **Supabase Auth**, **RLS on Postgres**, **Edge Functions with JWT + rate limiting**, and **client-side auth-derived `user_id`** consistently. No raw SQL or NoSQL in the client; **Linear API key** and **Supabase anon key** handling are aligned with good practice. Main areas to harden: **error disclosure**, **URL scheme validation for launched links**, **rate-limit durability**, **optional certificate pinning**, and **admin UX vs direct URL access**.

---

## 1. Authentication & Authorization

### 1.1 Auth flows (Supabase Auth)

- **Email/password, magic link, signup:** Implemented in `lib/features/auth/auth_screen.dart`; passwords passed to Supabase SDK only, not logged.
- **Session:** Supabase Flutter SDK manages session persistence (tokens). Ensure you are on a version that uses **secure storage** for tokens on mobile (SDK default).
- **Password recovery redirect:** `winflutter://auth-callback` is used for mobile; web uses hash-based `/auth/recovery`. **Action:** In Supabase Dashboard → Auth → URL Configuration, restrict **Redirect URLs** to your app’s scheme and production origins only (e.g. `winflutter://auth-callback`, `https://yourdomain.com/#/auth/recovery`). Do not use wildcards that allow open redirect.

**Severity:** Low (configuration)  
**Remediation:** Document and enforce allowed Redirect URLs in Supabase; audit periodically.

### 1.2 Admin access

- **Backend:** `is_admin()` (SECURITY DEFINER) and `admin_list_users()` enforce admin checks; RLS on `admin_users` and `user_feedback` restricts access.
- **Client:** `isAdminProvider` calls `is_admin` RPC; Admin nav is shown only when `isAdminProvider` is true (`lib/ui/desktop_nav_shell.dart`). Direct navigation to `/admin` or `/settings/admin` shows “Access denied” and does not expose data because RPC/RLS block.

**Severity:** Informational  
**Recommendation:** Optionally add a **router-level redirect** for `/admin` when `isAdminProvider` is false (e.g. redirect to `/today`) so non-admins never see the access-denied screen.

### 1.3 Protected routes

- Router in `lib/app/router.dart` redirects unauthenticated users to `/auth` (or `/setup` if not configured); `next` is validated via `_safeRelativeLocationFromNextParam` (no scheme/authority), preventing **open redirect**.

**Severity:** None (well implemented).

---

## 2. Input Validation & Injection

### 2.1 SQL / NoSQL / command injection

- **Flutter app:** All DB access goes through Supabase client (`.from()`, `.eq()`, `.insert()`, etc.). No raw SQL or string-concatenated queries; **user_id** is always taken from `_requireUserId()` (session), not from request/route parameters.
- **Edge Functions:** Assistant and generate-prd use **strict, schema-based parsing** (`_shared/validation.ts`): allowlisted keys, type checks, length limits, `stripUnsafeControlChars`. No dynamic SQL.

**Severity:** None identified.

### 2.2 XSS (mobile / web)

- **Mobile:** Rendered content is Flutter widgets; markdown is rendered via `flutter_markdown_plus`. No `WebView` with arbitrary HTML from user content in the reviewed paths.
- **Web (if used):** If you ever render user-generated HTML or pass unsanitized strings into a web view, introduce a sanitization layer and CSP.

**Severity:** Low (mobile-only today).  
**Remediation:** If you add WebView or web-rendered UGC, use a safe HTML subset or sanitizer; avoid `innerHTML` with raw user input.

### 2.3 Edge Function input

- **assistant:** `parseAssistantRequestBodyStrict` + `validateAssistantResponse` cap transcript length, validate `baseDateYmd` (YYYY-MM-DD), and drop invalid commands. **generate-prd:** `parseGeneratePrdRequestBodyStrict` with title/description limits.
- **remote_focus_push:** Expects `user_id` and `command_id` (UUIDs); no raw interpolation into queries. Service-role client is used server-side only.

**Severity:** None identified.

---

## 3. API Security (Edge Functions)

### 3.1 Authentication

- **assistant / generate-prd:** Require `Authorization: Bearer <JWT>`. User is resolved via `supabase.auth.getUser()`; no user_id from body.
- **remote_focus_push:** Intended for **server-to-server** only (e.g. pg_net from DB trigger). Auth: `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>`. **Critical:** Service role key must **never** be in the client or in client-reachable config. Trigger uses Vault (`vault.decrypted_secrets`) to pass the key; only backend/trigger should have access.

**Severity:** Low (if key is only in Supabase secrets/Vault and trigger).  
**Remediation:** Confirm no Edge Function, script, or CI logs the service role key; rotate key if it has ever been in version control or shared channels.

### 3.2 Rate limiting

- **assistant:** Per-IP and per-user RPM via `_shared/rate_limit.ts`. Prefer **DB-backed** `rate_limit_check` (service_role) for durability across instances; **in-memory** fallback is best-effort only.
- **rate_limits** table: RLS enabled, **no** policies → anon/authenticated cannot read/write; only service_role can. `rate_limit_check` is granted to `service_role` only.

**Risk:** Under high load or RPC failure, rate limiting can fall back to in-memory and be bypassed or inconsistent across Edge instances.

**Severity:** Medium  
**Remediation:**
- Ensure Edge Functions always receive a Supabase client created with **service_role** for `rate_limit_check` so DB-backed limiting is used when possible.
- Monitor rate_limit RPC errors; consider a small retry or circuit-breaker so transient DB issues don’t permanently fall back to memory.
- Optionally add a **global** (e.g. per-deployment) cap to limit blast radius if both DB and memory limits fail.

### 3.3 Data exposure

- Assistant returns only `say` + allowlisted `commands`; no PII or internal IDs beyond what the client needs. generate-prd returns path/url/sha for the created PRD file.

**Severity:** None identified.

---

## 4. Data Storage & Encryption

### 4.1 At rest

- **Supabase:** Postgres and Supabase managed encryption at rest (provider default). No custom encryption logic in app.
- **Flutter:** **Linear API key** stored in **Flutter Secure Storage** (`lib/app/linear_integration_controller.dart`). Supabase session is managed by SDK (confirm SDK uses secure storage on iOS/Android).
- **SharedPreferences:** Used for theme, dashboard layout, demo/local data, timebox state, etc. **No** auth tokens or API keys in SharedPreferences.

**Severity:** None.  
**Recommendation:** In docs, state that Supabase anon key in env/dart-define is **public by design** and that RLS + Auth are the security boundary; never put service role key in the app.

### 4.2 In transit

- All Supabase and Linear API calls use HTTPS. No custom TLS logic in the app.

**Severity:** None.  
**Optional (hardening):** For high-sensitivity deployments, consider **certificate pinning** for Supabase (and Linear if you want). Not required for typical use; document if you add it.

---

## 5. Session Management & Token Handling

- Session comes from Supabase Auth; refresh is handled by the SDK. Router listens to `authStateProvider` and redirects when not signed in.
- **Demo mode:** No Supabase session; app treats user as “signed in” with local data only. No tokens stored for demo.

**Severity:** None identified.  
**Recommendation:** Enforce **short refresh rotation** and **logout on password change** in Supabase Auth settings if not already.

---

## 6. Secrets Management

### 6.1 Flutter app

- **Supabase URL + anon key:** From `Env` (`lib/app/env.dart`): `String.fromEnvironment('SUPABASE_URL'|'SUPABASE_ANON_KEY')` or `dotenv` from `assets/env`. `assets/env` and `.env*` are in `.gitignore`. Anon key is **intended** for client; RLS and Auth protect data.
- **Linear API key:** User-provided; stored in Flutter Secure Storage only; not in repo.

**Severity:** None.  
**Remediation:** Keep `assets/env` and `.env*` out of version control; use CI secrets for `--dart-define` in builds; never commit real keys.

### 6.2 Edge Functions

- **assistant:** Uses `OPENAI_API_KEY`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, optional `SUPABASE_SERVICE_ROLE_KEY` from env (Supabase secrets).
- **remote_focus_push:** Uses `SUPABASE_SERVICE_ROLE_KEY`, APNs secrets from env.
- **generate-prd:** Uses Supabase + optional Gemini/GitHub tokens from env.

**Severity:** Low (assuming secrets are in Supabase project secrets only).  
**Remediation:** Audit that no Edge Function logs env vars or error messages containing keys; use redacted error messages in production.

---

## 7. Logging, Monitoring & Error Handling

### 7.1 Sensitive data in logs / errors

- **`showErrorDialog`** (`lib/app/errors.dart`): When `includeRawDetails == true` (default), the dialog shows **raw** `error.toString()` (e.g. stack traces, PostgrestException messages, column names). A user or screen-share could leak internal details.

**Severity:** Medium  
**Remediation:**
- Default `includeRawDetails` to **false** in production, or pass `includeRawDetails: false` for user-facing dialogs.
- Reserve raw details for internal/dev-only error reporting (e.g. feedback form with “attach debug info” that you control).
- Keep mapping in `friendlyError()` for Postgrest/Auth exceptions so users see safe messages; avoid returning `error.message` for unhandled cases in production.

### 7.2 debugPrint / track

- **`debugPrint`** in `today_screen.dart` (speech, AI button) and `remote_focus_session_provider.dart` (poll errors): Only in debug builds; can expose stack traces if someone ships a debug build.
- **`track()`** (`lib/app/analytics/track.dart`): Logs event + props when **not** `kReleaseMode`. If you later send the same props to an analytics backend, ensure they never contain PII (email, tokens, full names) without consent and masking.

**Severity:** Low  
**Remediation:** Do not ship release builds with debug mode; when wiring analytics, apply a PII policy to `track()` props.

---

## 8. Mobile-Specific & Deep Links

### 8.1 URL scheme (winflutter://)

- **Password reset:** Redirect is `winflutter://auth-callback`. iOS `Info.plist` and Android intent filter declare `winflutter` scheme. Supabase must list this in Redirect URLs.
- **Risk:** If an attacker could control the redirect URL (e.g. via another app or a misconfigured allowlist), they might try to capture tokens. Restricting Redirect URLs in Supabase to exact values mitigates this.

**Severity:** Low (with correct Supabase config).  
**Remediation:** Restrict Redirect URLs; avoid wildcards.

### 8.2 Launching external URLs

- **`linear_markdown_renderer.dart`:** `_launchUrl(context, url)` uses `Uri.tryParse(url)` then `launchUrl(uri, mode: LaunchMode.externalApplication)`. No check that the scheme is `https` (or `http`). Markdown from **Linear** is relatively trusted; if the same renderer is ever used for **user-generated** markdown, `javascript:` or `file:` links could be dangerous.

**Severity:** Medium (if this renderer is used for UGC). Low if only for Linear-sourced content.  
**Remediation:** Before launching, allow only `https` (and optionally `http` for known hosts). Reject `javascript:`, `file:`, `data:`, and other non-http(s) schemes. Example:

```dart
static Future<void> _launchUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') return;  // block javascript:, file:, etc.
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}
```

Apply the same rule anywhere else you `launchUrl` with a URL that could ever come from user or external content (e.g. feature_request_screen, linear_issue_header, linear_issue_card if they take URLs from untrusted input).

---

## 9. Row Level Security (RLS) & Database

### 9.1 Core tables

- **tasks, habits, habit_completions, daily_reflections, scoring_settings:** RLS with `auth.uid() = user_id` (or equivalent for habit_completions via habits join). **user_feedback:** Insert own only; select for admins via separate policy.
- **notes, note_links, note_templates, note_tags:** RLS by `user_id`; **note_templates** SELECT allows `auth.uid() = user_id OR is_system = true` so shared system templates are readable. UPDATE/DELETE restrict to own and non-system.

**Severity:** None identified.

### 9.2 note_templates is_system

- INSERT policy is `WITH CHECK (auth.uid() = user_id)` only. A user could insert a row with `is_system = true` (if client sends it), polluting “system” template lists. They cannot read or update other users’ rows.

**Severity:** Low  
**Remediation:** Either add `WITH CHECK (is_system = false)` to the insert policy, or set `is_system` via trigger/default only (e.g. only allow `is_system = true` for a fixed system user or migration).

### 9.3 user_devices & remote_focus_commands

- RLS: select/insert/update/delete only where `auth.uid() = user_id`. **remote_focus_push** Edge Function uses **service_role** to read `user_devices` for a given `user_id` (from trigger payload). Trigger is fired by insert into `remote_focus_commands` (which is RLS-protected), so only the owning user can create commands; the trigger then calls the Edge Function with that user_id. No privilege escalation identified.

**Severity:** None identified.

### 9.4 rate_limits

- RLS enabled, **no** policies → only service_role can access. Correct.

---

## 10. Dependency & Supply Chain

- **pubspec.yaml:** No obviously vulnerable or unmaintained packages in the excerpt. **supabase_flutter**, **flutter_secure_storage**, **go_router**, etc. are common choices.
- **Edge Functions:** Pinned imports (e.g. `npm:@supabase/supabase-js@2.45.4`, `jose@6.1.3`). Pinning is good; keep dependencies updated for security patches.

**Severity:** Low (process).  
**Remediation:** Run `dart pub audit` and `flutter pub upgrade` (or equivalent) regularly; track Supabase and Deno deploy bulletins; update Edge Function dependencies when patches are released.

---

## 11. OWASP Alignment (Summary)

| Area | Finding |
|------|--------|
| **M1 (Improper Platform Usage)** | Deep link / redirect URL allowlist in Supabase is critical; document and restrict. |
| **M2 (Insecure Data Storage)** | Linear key in secure storage; Supabase session via SDK. No secrets in SharedPreferences. |
| **M3 (Insecure Communication)** | HTTPS used; optional pinning for high-sensitivity deployments. |
| **M4 (Insecure Authentication)** | Supabase Auth; session and refresh handled by SDK. Redirect URL config is the main control. |
| **M5 (Insufficient Cryptography)** | N/A (no custom crypto). |
| **M6 (Insecure Authorization)** | RLS and is_admin() enforce authorization; admin UI gated by isAdminProvider. |
| **M7 (Client Code Quality)** | No raw SQL; user_id from session. Error disclosure and URL launch scheme validation recommended. |
| **M8 (Code Tampering)** | Standard Flutter; obfuscation not reviewed. Consider build integrity / attestation for high-risk builds. |
| **M9 (Reverse Engineering)** | Anon key and app logic are visible; design assumes RLS + Auth as boundary. |
| **M10 (Extraneous Functionality)** | No backdoors or debug endpoints in reviewed code. |
| **API: Broken Object Level Authorization** | Mitigated by RLS and auth-derived user_id. |
| **API: Broken Authentication** | JWT required for assistant/generate-prd; service role only for remote_focus_push. |
| **API: Excessive Data Exposure** | Responses limited to necessary fields; validation on output in assistant. |
| **API: Lack of Resources & Rate Limiting** | Rate limiting present; durability depends on DB-backed limiter. |

---

## 12. Attack Scenarios & PoC Ideas (No Malware)

1. **Error message mining:** Attacker triggers DB or auth errors and captures dialogs/screenshots. With `includeRawDetails: true`, messages can reveal schema or internal paths. **Mitigation:** Default off for raw details; friendly messages only in production.
2. **Open redirect (auth):** Attacker tricks user into using a magic link or recovery link that points to a malicious redirect URL. **Mitigation:** Strict Redirect URL allowlist in Supabase.
3. **Rate limit bypass:** Under failure of `rate_limit_check` RPC or when only in-memory limiter is used, attacker sends many requests to assistant/generate-prd to burn quota. **Mitigation:** Prefer DB-backed rate limit; monitor RPC health; optional global cap.
4. **Malicious link in markdown:** If markdown is user-generated or from an untrusted source, `javascript:` or `file:` in links could be launched. **Mitigation:** Restrict launched URLs to `https` (and optionally `http`) only.
5. **Service role key leak:** If the key is ever in client, CI logs, or support bundles, full DB and bypass of RLS are possible. **Mitigation:** Key only in Supabase secrets/Vault and server-side trigger; rotate if ever exposed.

---

## 13. Prioritized Remediation Checklist

| Priority | Item | Severity | Action |
|----------|------|----------|--------|
| 1 | Error dialog raw details | Medium | Default `includeRawDetails: false` or restrict to dev/feedback only. |
| 2 | URL scheme validation for launchUrl | Medium | Allow only https (and optional http); reject javascript:, file:, data:. |
| 3 | Rate limit durability | Medium | Prefer DB-backed limiter; monitor RPC; optional global cap. |
| 4 | Supabase Redirect URLs | Low | Restrict to exact app scheme + production origins; document. |
| 5 | note_templates is_system on INSERT | Low | Add WITH CHECK (is_system = false) or enforce via trigger. |
| 6 | Analytics / track() PII | Low | When adding backend, ensure no PII in props without policy. |
| 7 | Certificate pinning | Optional | Consider for high-sensitivity deployments only. |
| 8 | Admin route redirect | Optional | Redirect non-admins from /admin to /today. |

---

## 14. Clarifications (if needed)

- **Supabase session storage:** Confirm with current `supabase_flutter` docs that mobile uses secure storage for tokens; no code change suggested if already documented.
- **Web deployment:** If Flutter Web is used in production, re-check CORS, redirect URLs, and any web-specific auth flows.
- **Storage buckets:** No Supabase Storage usage was found in the app; if you add buckets later, apply RLS or object-level policies and validate upload types/sizes.

This assessment is based on the codebase and migrations reviewed; runtime config (Supabase Dashboard, env in deploy) should be audited separately.
