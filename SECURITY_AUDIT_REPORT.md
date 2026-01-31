# Security Audit Report - winFlutter Codebase
**Date:** January 2025  
**Auditor:** Backend Cybersecurity Review  
**Scope:** Full codebase security review focusing on exposed APIs, secrets management, and vulnerability assessment

---

## Executive Summary

This security audit reviewed the winFlutter Flutter application codebase for security vulnerabilities. The codebase demonstrates **good security practices** in several areas, but there are **critical findings** that require immediate attention, particularly around Row Level Security (RLS) coverage for core database tables.

**Overall Security Posture:** ⚠️ **MODERATE RISK** - Several critical issues identified that could lead to data exposure.

---

## Critical Findings (Must Fix Before Production)

### 🔴 CRITICAL: Missing RLS Policies for Core Tables

**Issue:** The core application tables (`tasks`, `habits`, `habit_completions`, `daily_reflections`, `scoring_settings`) do not have visible RLS policies in the migrations directory.

**Evidence:**
- Migrations exist for newer tables (trackers, user_feedback, notes, admin_users) with proper RLS
- Core tables mentioned in `agentPrompt.md` are not found in migration files
- Only column additions found: `20260111_000001_task_details.sql`, `20260112_000002_task_goal_date.sql`

**Risk:**
- **CRITICAL** - If these tables exist in production without RLS, any authenticated user could potentially read/write other users' data using the public anon key
- Cross-user data access vulnerability
- Violation of data isolation principles

**Recommendation:**
1. **IMMEDIATE:** Verify production database has RLS enabled on all user tables
2. Create migration files for core tables with proper RLS policies:
   ```sql
   ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
   CREATE POLICY "tasks_select_own" ON public.tasks FOR SELECT USING (auth.uid() = user_id);
   CREATE POLICY "tasks_insert_own" ON public.tasks FOR INSERT WITH CHECK (auth.uid() = user_id);
   CREATE POLICY "tasks_update_own" ON public.tasks FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
   CREATE POLICY "tasks_delete_own" ON public.tasks FOR DELETE USING (auth.uid() = user_id);
   ```
3. Apply same pattern for: `habits`, `habit_completions`, `daily_reflections`, `scoring_settings`
4. Add to monthly audit checklist: verify RLS on all user tables

---

## High Priority Findings

### 🟠 HIGH: Exposed API Keys in Example File

**Issue:** `assets/env.example` contains what appears to be real Supabase credentials:
- `SUPABASE_URL=https://mytllkdpadrwapwxytca.supabase.co`
- `SUPABASE_ANON_KEY=sb_publishable_B5rjOES4z4fmare9OLSTRg_XFJTDmTz`

**Risk:**
- **HIGH** - While anon keys are "public" by design, they still enable access to whatever RLS permits
- If RLS is misconfigured, these keys could be used maliciously
- Keys should not be casually exposed in version control

**Recommendation:**
1. Replace with placeholder values: `SUPABASE_URL=https://your-project.supabase.co`
2. Add comment: `# Replace with your actual Supabase project URL and anon key`
3. Verify `.gitignore` properly excludes `assets/env` (✅ Already done)

### 🟠 HIGH: Optional Origin Allowlist for Assistant Endpoint

**Issue:** The assistant Edge Function (`supabase/functions/assistant/index.ts`) only checks `ASSISTANT_ALLOWED_ORIGINS` if it's set. If not configured, any origin can call the endpoint.

**Risk:**
- **HIGH** - In browser/web contexts, CSRF-like attacks could cause logged-in users to make unwanted assistant calls
- Cost abuse: malicious sites could burn OpenAI credits
- Unauthorized actions via cross-origin requests

**Recommendation:**
1. **For production with web support:** Require `ASSISTANT_ALLOWED_ORIGINS` to be set
2. Consider rejecting requests with `Origin` header not in allowlist (even if allowlist is empty, log warning)
3. Add deployment checklist item: "Do not deploy assistant without origin allowlist if web client exists"
4. Document mobile apps don't send Origin header (acceptable for mobile-only deployments)

### 🟠 HIGH: Local Storage of Sensitive Data

**Issue:** User content (tasks, habits, reflections) stored in `SharedPreferences` in plaintext for demo/local mode.

**Evidence:**
- `lib/data/tasks/local_all_tasks_repository.dart`
- `lib/data/habits/local_habits_repository.dart`
- Multiple other local repositories

**Risk:**
- **HIGH** - On rooted/jailbroken devices or via backups, user content can be exfiltrated
- Reflections may contain sensitive personal information
- Code drift: demo mode code may be used in production scenarios

**Recommendation:**
1. Document clearly: demo mode is non-secure, should not store secrets
2. **Medium-term:** Migrate sensitive content to encrypted storage:
   - Use platform keystores (Android Keystore / iOS Keychain) to wrap encryption keys
   - Store encrypted blobs instead of raw JSON
3. Add process: treat new `SharedPreferences.setString()` as security review trigger

---

## Medium Priority Findings

### 🟡 MEDIUM: Service Role Key Exposure Risk

**Issue:** No automated checks to prevent service role keys from being committed to client code.

**Risk:**
- **MEDIUM** - If service role key ever lands in client code, it would be catastrophic
- Currently relies on manual review

**Recommendation:**
1. Add CI/CD check that fails if these patterns appear in `lib/`, `assets/`, or native code:
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `OPENAI_API_KEY`
   - `sb_secret_` patterns
2. Add pre-commit hook or GitHub Actions workflow
3. Document: anon key OK in client, service role is NOT

### 🟡 MEDIUM: Android Restriction Engine Tamperability

**Issue:** Android focus/restriction configuration stored in `SharedPreferences`, potentially tamperable on rooted devices.

**Risk:**
- **MEDIUM** - Users with root/ADB access could modify restriction settings
- If focus mode is a core safety feature, tamper resistance matters

**Recommendation:**
1. Move enforcement state to encrypted storage or validate with signatures
2. Treat client as untrusted: enforcement should rely on OS-level signals where possible
3. Document security model: what is/isn't tamper-resistant

### 🟡 MEDIUM: Edge Function Dev Mode JWT Bypass

**Issue:** Local dev uses `--no-verify-jwt` flag, which is correct for dev but could be accidentally deployed.

**Risk:**
- **MEDIUM** - Process risk: someone might ship dev config to production

**Recommendation:**
1. Add release checklist: confirm deployed function requires auth (JWT verification enabled)
2. Add explicit warnings in dev serve output
3. Consider environment-based config (dev vs prod)

---

## Positive Security Practices Found ✅

### 1. Secure Storage for Sensitive Data
- ✅ Linear API keys stored in `FlutterSecureStorage` (OS keychain/keystore)
- ✅ NFC card hash stored securely (not raw tag contents)
- ✅ Proper use of `flutter_secure_storage` package

### 2. Edge Function Security
- ✅ Authentication required (JWT validation)
- ✅ Rate limiting (per-IP and per-user)
- ✅ Input size limits (body bytes, transcript chars)
- ✅ Output validation (drops invalid commands)
- ✅ Timeouts for OpenAI calls
- ✅ Proper CORS handling

### 3. Input Validation
- ✅ Supabase client uses parameterized queries (`.from()`, `.select()`, `.insert()`) - safe from SQL injection
- ✅ Edge Function has strict input validation (`parseAssistantRequestBodyStrict`)
- ✅ Command validation with allowlist approach

### 4. Secrets Management
- ✅ `.gitignore` properly excludes `assets/env` and `.env` files
- ✅ Environment variables loaded from secure sources (not hardcoded)
- ✅ Service role key only used server-side in Edge Functions

### 5. RLS Implementation (Where Present)
- ✅ Excellent RLS policies for: `trackers`, `tracker_tallies`, `user_feedback`, `notes`, `admin_users`
- ✅ Proper use of `auth.uid()` for user isolation
- ✅ Rate limits table has RLS with no policies (correctly locked down)

### 6. Admin Functions Security
- ✅ `is_admin()` function uses `SECURITY DEFINER` correctly
- ✅ Admin functions check admin status before execution
- ✅ Proper RLS on admin_users table

---

## Low Priority / Best Practices

### 🔵 LOW: iOS Local Network Permissions
- Info.plist includes local network usage (likely for dev/debugging)
- Ensure not exposed in release builds
- Consider gating for production

### 🔵 LOW: NFC Pairing Security Model
- Uses hash of tag UID/NDEF content
- Document as convenience/friction mechanism, not cryptographic authentication
- Acceptable for intended use case

---

## SQL Injection Assessment

**Status:** ✅ **SAFE**

**Analysis:**
- All database queries use Supabase client methods (`.from()`, `.select()`, `.insert()`, `.update()`, `.delete()`)
- These methods use parameterized queries internally
- No raw SQL string concatenation found
- Edge Function uses Supabase JS client (also parameterized)

**Verdict:** No SQL injection vulnerabilities detected.

---

## API Exposure Assessment

**Status:** ⚠️ **CONDITIONAL RISK**

**Analysis:**
- Supabase anon key is exposed in client (by design, acceptable)
- Edge Function properly requires authentication
- No unauthenticated endpoints found
- **Risk:** If RLS is missing on core tables, anon key could access other users' data

**Verdict:** API exposure risk depends entirely on RLS configuration. Must verify all tables have proper RLS.

---

## Recommendations Summary

### Immediate Actions (Before Next Release)
1. ✅ **Verify RLS on all production tables** - especially `tasks`, `habits`, `habit_completions`, `daily_reflections`
2. ✅ **Create migration files** for core tables with proper RLS policies
3. ✅ **Replace real credentials** in `assets/env.example` with placeholders
4. ✅ **Set `ASSISTANT_ALLOWED_ORIGINS`** if web client exists

### Short-Term (Next Sprint)
1. Add CI/CD checks for service role key patterns
2. Document security model for demo mode (non-secure storage)
3. Add release checklist for Edge Function auth verification
4. Review Android restriction engine tamper resistance

### Medium-Term (Next Quarter)
1. Migrate sensitive local storage to encrypted format
2. Implement tamper-resistant storage for Android focus settings
3. Add automated RLS policy verification to monthly audit

---

## Monthly Security Audit Checklist

Based on findings, here's an enhanced checklist:

### 1. Secrets & Keys
- [ ] No service role keys in client code (automated check)
- [ ] `assets/env` remains git-ignored
- [ ] No secrets in screenshots/logs

### 2. RLS Verification (CRITICAL)
- [ ] All user tables have RLS enabled
- [ ] All policies scoped to `auth.uid()`
- [ ] No permissive `using (true)` policies
- [ ] Verify: tasks, habits, habit_completions, reflections, settings, trackers, feedback, notes

### 3. Edge Function Security
- [ ] Auth required (JWT verification enabled)
- [ ] `ASSISTANT_ALLOWED_ORIGINS` set (if web exists)
- [ ] Rate limiting enabled
- [ ] Size limits configured
- [ ] Debug mode disabled in production

### 4. Local Storage Review
- [ ] No new sensitive data in SharedPreferences
- [ ] Secure storage used for all secrets
- [ ] Demo mode limitations documented

### 5. Dependency Review
- [ ] Review new packages for security issues
- [ ] Update vulnerable dependencies

---

## Conclusion

The codebase shows **strong security awareness** with good practices in many areas. However, the **critical RLS gap** for core tables must be addressed immediately. Once RLS is verified/implemented, the security posture improves significantly.

**Priority Actions:**
1. 🔴 Verify and implement RLS for core tables
2. 🟠 Replace real credentials in example file
3. 🟠 Configure origin allowlist for assistant endpoint
4. 🟡 Add automated checks for service role keys

**Overall Grade:** **B+** (Good, but critical issues need resolution)

---

## Appendix: Files Reviewed

- `lib/app/env.dart` - Environment configuration
- `lib/app/supabase.dart` - Supabase initialization
- `supabase/functions/assistant/index.ts` - Edge Function
- `supabase/migrations/*.sql` - Database migrations
- `lib/data/**/supabase_*.dart` - Repository implementations
- `lib/app/linear_integration_controller.dart` - Secure storage usage
- `assets/env.example` - Example configuration
- `.gitignore` - Secrets exclusion
- `security risks.md` - Existing security documentation

---

**Report Generated:** January 2025  
**Next Review:** After RLS implementation verification
