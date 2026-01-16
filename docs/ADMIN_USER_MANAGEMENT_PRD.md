### PRD: User Management in Admin Dashboard

### Status
- **Owner**: Product
- **Repo**: `winFlutter` (Flutter)
- **Audience**: Product + Design + Engineering
- **Last updated**: 2026-01-15

---

### 1) Executive summary
The admin dashboard currently provides feedback triage capabilities, but lacks the ability to manage users and their admin privileges. This PRD proposes a User Management section that allows admins to view users, grant/revoke admin access, and monitor basic user activity metrics.

This feature enables self-service admin management without requiring direct database access, improving operational efficiency and security through an auditable UI.

---

### 2) Problem statement
**Current state:**
- Admin privileges are managed by manually inserting rows into the `admin_users` table via SQL
- No visibility into who has admin access without querying the database
- No way to see basic user metrics (signup date, activity status, etc.)
- No audit trail for admin privilege changes
- Admins cannot grant/revoke access to other users through the app

**Pain points:**
- **P1**: Granting admin access requires database access and SQL knowledge
- **P2**: No visibility into user base without database queries
- **P3**: No way to track when admin privileges were granted or by whom
- **P4**: Difficult to identify inactive users or understand user growth

---

### 3) Goals and non-goals

### Goals
- **G1 — Self-service admin management**: Admins can grant/revoke admin privileges through the UI
- **G2 — User visibility**: View list of all users with basic metadata (email, signup date, admin status)
- **G3 — Audit trail**: Track who granted admin access and when
- **G4 — Basic user metrics**: See user activity indicators (last active, account age)
- **G5 — Security**: All operations respect RLS policies and require admin authentication

### Non-goals (v1)
- User profile editing (email changes, password resets)
- Bulk operations (grant admin to multiple users at once)
- Advanced user analytics (retention curves, engagement metrics)
- User deletion or account suspension
- Role-based permissions beyond admin/non-admin
- User search by name or other fields (email search only in MVP)

---

### 4) Target users and JTBD

### Primary persona
- **P1: "Platform admin"**: Needs to manage who has admin access and understand the user base

### Jobs To Be Done
- **JTBD1**: "When I need to grant admin access to a new team member, I want to do it through the app without SQL."
- **JTBD2**: "When I want to see who has admin access, I want a clear list in the dashboard."
- **JTBD3**: "When I need to understand our user base, I want to see basic metrics like signup dates and activity."

---

### 5) Research synthesis
**Existing patterns:**
- Most admin dashboards include a "Users" or "User Management" section
- Admin privilege management typically requires confirmation dialogs to prevent accidental changes
- User lists commonly show: email, signup date, last active, and role badges
- Audit logs for privilege changes are standard in enterprise admin tools

**Security considerations:**
- Admin operations should require explicit confirmation
- Changes should be logged with who made them and when
- RLS policies must prevent non-admins from accessing user data
- Email addresses should be displayed but not fully exposed (consider partial masking for privacy)

---

### 6) Product principles
- **Security first**: All operations must respect RLS and require admin authentication
- **Audit everything**: All admin privilege changes must be logged
- **Minimal data exposure**: Show only necessary user information
- **Clear feedback**: Confirm destructive actions (revoking admin access)
- **Progressive disclosure**: Start with essential features, expand based on needs

---

### 7) Proposed features (prioritized)

### MVP (ship first)

#### F1 — User list view
**Problem addressed**: lack of user visibility  
**What changes**:
- New "User Management" section in Admin Dashboard
- Table/list view showing:
  - Email address
  - Signup date (from `auth.users.created_at`)
  - Admin status badge (visual indicator)
  - Last active timestamp (if available from session data)
- Sortable by signup date (newest/oldest)
- Search/filter by email address

**Acceptance criteria**
- Admin can see all users in a paginated or scrollable list
- Admin status is clearly indicated with a badge or icon
- Email search works with partial matches
- List loads efficiently (pagination or virtual scrolling for large user bases)

#### F2 — Grant admin access
**Problem addressed**: manual SQL requirement  
**What changes**:
- "Grant Admin" action button/icon next to non-admin users
- Confirmation dialog: "Grant admin access to [email]?"
- On confirm, inserts row into `admin_users` table with:
  - `user_id`: target user's ID
  - `created_by`: current admin's user ID
  - `created_at`: current timestamp
- Success feedback (snackbar/toast)
- Error handling for edge cases (user already admin, user doesn't exist)

**Acceptance criteria**
- Admin can grant access with 2 taps (action + confirm)
- Operation is logged in `admin_users.created_by`
- UI updates immediately to show new admin status
- Clear error messages if operation fails

#### F3 — Revoke admin access
**Problem addressed**: no way to remove admin privileges  
**What changes**:
- "Revoke Admin" action button/icon next to admin users
- **Warning confirmation dialog**: "Revoke admin access from [email]? They will lose access to the admin dashboard."
- Prevents revoking your own admin access (disable button or show error)
- On confirm, deletes row from `admin_users` table
- Success feedback

**Acceptance criteria**
- Admin cannot revoke their own access (button disabled or error shown)
- Confirmation dialog clearly warns about consequences
- Operation succeeds and UI updates immediately
- Clear error messages if operation fails

#### F4 — Admin audit trail
**Problem addressed**: no visibility into who granted admin access  
**What changes**:
- Show "Granted by" information in user list (if available from `admin_users.created_by`)
- Expandable detail view or tooltip showing:
  - When admin access was granted (`created_at`)
  - Who granted it (email of `created_by` user, or "System" if null)
- For users who are not admins, show "Not an admin" or omit the field

**Acceptance criteria**
- Admin can see who granted access to each admin user
- Historical data is preserved (even if grantor is no longer admin)

---

### Phase 2 (next)

#### F5 — User activity metrics
**Problem addressed**: lack of user engagement visibility  
**What changes**:
- Add "Last Active" column showing most recent session timestamp
- Add "Account Age" indicator (days since signup)
- Optional: "Active" badge for users active in last 7 days
- Optional: Basic stats card showing total users, active users, new users this month

#### F6 — Enhanced search and filtering
**Problem addressed**: finding specific users in large lists  
**What changes**:
- Filter by admin status (All / Admins only / Non-admins only)
- Filter by activity status (Active / Inactive)
- Sort by multiple columns (email, signup date, last active)

---

### Phase 3 (bigger bets)

#### F7 — User detail view
**Problem addressed**: need for deeper user insights  
**What changes**:
- Clicking a user opens a detail sheet/modal showing:
  - Full user profile information
  - Recent activity summary
  - Associated data counts (tasks created, focus sessions, etc.)
  - Admin privilege history (if multiple grants/revokes are tracked)

#### F8 — Bulk operations
**Problem addressed**: efficiency for large user bases  
**What changes**:
- Multi-select users
- Bulk grant/revoke admin access
- Export user list to CSV

---

### 8) Functional requirements (detailed)

### Data model
**Existing tables (no changes needed):**
- `auth.users` (Supabase Auth): contains email, `created_at`, `id`
- `admin_users` (existing): `user_id`, `created_at`, `created_by`

**New database functions (optional, for efficiency):**
```sql
-- Function to get user list with admin status (for admins only)
create or replace function public.admin_list_users()
returns table (
  user_id uuid,
  email text,
  created_at timestamptz,
  is_admin boolean,
  admin_granted_at timestamptz,
  admin_granted_by uuid
)
language sql
security definer
set search_path = public
stable
as $$
  select 
    u.id as user_id,
    u.email,
    u.created_at,
    exists(select 1 from admin_users au where au.user_id = u.id) as is_admin,
    au.created_at as admin_granted_at,
    au.created_by as admin_granted_by
  from auth.users u
  left join admin_users au on au.user_id = u.id
  order by u.created_at desc;
$$;

-- Grant execute to authenticated users (RLS in function ensures only admins can use it)
grant execute on function public.admin_list_users() to authenticated;
```

**RLS considerations:**
- New RLS policy on `auth.users` read access for admins (if direct access needed)
- Or use `security definer` function to bypass RLS safely
- `admin_users` table already has RLS; need INSERT/DELETE policies for admins:

```sql
-- Allow admins to insert into admin_users
drop policy if exists "admin_users_insert_admin" on public.admin_users;
create policy "admin_users_insert_admin"
on public.admin_users
for insert
with check (public.is_admin());

-- Allow admins to delete from admin_users (revoke access)
drop policy if exists "admin_users_delete_admin" on public.admin_users;
for delete
using (public.is_admin());
```

### API/Repository layer
**New repository**: `lib/data/admin/admin_user_repository.dart`
- `listUsers()`: Returns list of users with admin status
- `grantAdminAccess(String userId)`: Inserts into `admin_users`
- `revokeAdminAccess(String userId)`: Deletes from `admin_users`
- `getCurrentAdminUserId()`: Helper to get current user ID for `created_by`

### UI components
**New screen/section**: `lib/features/admin/user_management_screen.dart`
- Or integrate into existing `AdminDashboardScreen` as a new section
- User list widget with search, sort, actions
- Confirmation dialogs for grant/revoke operations

---

### 9) UX requirements (fits this repo)
- Use **Material 3** + existing theme (`lib/app/theme.dart`)
- Use `AppScaffold` for consistent layout
- Use spacing via `AppSpace` + `Gap` (see `docs/FRONTEND_SPEC.md`)
- Accessibility:
  - Touch targets ≥ 44px
  - Clear empty states ("No users found")
  - Clear error states with actionable messages
  - Keyboard navigation support (for desktop)
- Copy tone: professional, clear, non-technical
- Confirmation dialogs: use `HoldToConfirmButton` pattern for destructive actions (revoke admin)

---

### 10) Security requirements

### Authentication & Authorization
- All operations require admin authentication (checked via `isAdminProvider`)
- RLS policies enforce database-level security
- UI should hide user management section if user is not admin

### Data privacy
- Email addresses are PII; display them but consider:
  - Partial masking option (e.g., "u***@example.com") for privacy-sensitive contexts
  - Or require explicit "Show emails" toggle
- Do not expose user IDs in UI (use email as identifier)
- Do not expose other PII beyond email and timestamps

### Audit logging
- All admin privilege changes must be logged:
  - Who made the change (`created_by` in `admin_users`)
  - When (`created_at`)
  - What (grant/revoke)
  - Target user (via `user_id`)

### Edge cases
- **Self-revocation prevention**: Disable "Revoke Admin" button for current user
- **Last admin protection**: Prevent revoking if it would leave zero admins (optional, Phase 2)
- **Concurrent modifications**: Handle race conditions gracefully (show error if user already admin/non-admin)

---

### 11) Metrics and success criteria

### North Star
- **Time to grant admin access**: < 30 seconds from admin dashboard to completion

### Supporting metrics
- **Admin operations per week**: Track grant/revoke frequency
- **User list load time**: < 2 seconds for 1000 users
- **Error rate**: < 1% of admin operations fail
- **Adoption**: % of admins who use UI vs SQL for admin management

### Success criteria
- Admins can grant/revoke access without SQL knowledge
- User list loads and displays correctly for user bases up to 10,000 users
- All operations are auditable via `created_by` and `created_at` fields
- Zero security incidents related to privilege escalation

---

### 12) Risks and mitigations
- **R1 — Security vulnerability**: Exposing user list or allowing privilege escalation.  
  - **Mitigation**: Strict RLS policies, admin-only access, security definer functions, thorough testing
- **R2 — Performance**: User list query slow for large user bases.  
  - **Mitigation**: Pagination, indexing, virtual scrolling, consider caching
- **R3 — Accidental revocations**: Admin accidentally revokes their own or another critical admin's access.  
  - **Mitigation**: Confirmation dialogs, prevent self-revocation, warning messages
- **R4 — Privacy concerns**: Exposing email addresses in admin UI.  
  - **Mitigation**: Consider partial masking, require admin authentication, document in privacy policy

---

### 13) Rollout plan
- **Phase 0**: Internal testing with 2-3 admins
- **Phase 1**: Ship MVP (F1-F4) to all admins
- **Phase 2**: Add activity metrics and enhanced filtering (F5-F6) based on feedback
- **Phase 3**: Consider advanced features (F7-F8) if there's demand

---

### 14) Open questions
- Should we show partial email masking by default, or only on request?
- Do we need to track revocations separately, or is deletion from `admin_users` sufficient?
- Should we prevent the last admin from being revoked, or allow it (with warning)?
- Do we need pagination for user list, or is virtual scrolling sufficient?
- Should user list be real-time (subscription) or refresh-on-demand?

---

### 15) Implementation checklist (agent-ready, parallelizable)

### Workstream A — Database schema and RLS
- [ ] **Add RLS policies for admin_users INSERT/DELETE**
  - [ ] Policy: `admin_users_insert_admin` (admins can insert)
  - [ ] Policy: `admin_users_delete_admin` (admins can delete)
  - [ ] Test policies with non-admin user (should fail)
  - [ ] Test policies with admin user (should succeed)
- [ ] **Create admin_list_users() function (optional, for efficiency)**
  - [ ] Function returns user list with admin status
  - [ ] Marked as `security definer` with proper RLS checks
  - [ ] Grant execute permission to authenticated users
  - [ ] Test function returns correct data
- [ ] **Acceptance**: Admins can insert/delete from `admin_users` via Supabase client; non-admins cannot

### Workstream B — Data layer (Repository)
- [ ] **Create AdminUserRepository** (`lib/data/admin/admin_user_repository.dart`)
  - [ ] `listUsers()`: Query users with admin status
  - [ ] `grantAdminAccess(String userId)`: Insert into `admin_users`
  - [ ] `revokeAdminAccess(String userId)`: Delete from `admin_users`
  - [ ] Error handling for edge cases (already admin, doesn't exist, etc.)
  - [ ] **Acceptance**: Repository methods work correctly, handle errors gracefully
- [ ] **Create Riverpod providers**
  - [ ] `adminUserRepositoryProvider`: Provides repository instance
  - [ ] `adminUserListProvider`: FutureProvider for user list
  - [ ] **Acceptance**: Providers integrate with existing Supabase setup

### Workstream C — UI: User list view
- [ ] **User list widget** (table or card list)
  - [ ] Display: email, signup date, admin badge, last active (if available)
  - [ ] Search by email (partial match)
  - [ ] Sort by signup date (newest/oldest)
  - [ ] Loading state (CircularProgressIndicator)
  - [ ] Empty state ("No users found")
  - [ ] Error state (with retry button)
  - [ ] **Acceptance**: List displays correctly, search works, sorting works
- [ ] **Integrate into AdminDashboardScreen**
  - [ ] Add "User Management" section header
  - [ ] Add user list below feedback section
  - [ ] Use `AppScaffold`, `SectionHeader`, `Gap`/`AppSpace`
  - [ ] **Acceptance**: Section appears in admin dashboard, matches existing UI patterns

### Workstream D — UI: Grant/Revoke actions
- [ ] **Grant admin action**
  - [ ] "Grant Admin" button/icon next to non-admin users
  - [ ] Confirmation dialog: "Grant admin access to [email]?"
  - [ ] On confirm, call `grantAdminAccess()`
  - [ ] Success snackbar: "Admin access granted to [email]"
  - [ ] Error handling with user-friendly messages
  - [ ] **Acceptance**: Admin can grant access, UI updates immediately, errors handled
- [ ] **Revoke admin action**
  - [ ] "Revoke Admin" button/icon next to admin users
  - [ ] **Warning confirmation dialog**: "Revoke admin access from [email]? They will lose access to the admin dashboard."
  - [ ] Disable button for current user (self-revocation prevention)
  - [ ] On confirm, call `revokeAdminAccess()`
  - [ ] Success snackbar: "Admin access revoked from [email]"
  - [ ] Error handling
  - [ ] **Acceptance**: Admin can revoke access (except self), UI updates, errors handled
- [ ] **Admin audit trail display**
  - [ ] Show "Granted by" and "Granted at" in user list (for admin users)
  - [ ] Use expandable row or tooltip for details
  - [ ] Format dates using `DateFormat`
  - [ ] **Acceptance**: Admin can see who granted access and when

### Workstream E — Security and edge cases
- [ ] **Self-revocation prevention**
  - [ ] Disable "Revoke Admin" button when viewing own user row
  - [ ] Or show error message: "You cannot revoke your own admin access"
  - [ ] **Acceptance**: Admin cannot revoke their own access
- [ ] **Concurrent modification handling**
  - [ ] Handle "user already admin" error gracefully
  - [ ] Handle "user not admin" error when revoking
  - [ ] Show appropriate error messages
  - [ ] **Acceptance**: Edge cases handled with clear error messages
- [ ] **Access control**
  - [ ] Hide user management section if `isAdminProvider` is false
  - [ ] Show access denied message if non-admin tries to access
  - [ ] **Acceptance**: Non-admins cannot see or use user management

### Cross-cutting (do once)
- [ ] **Accessibility review**: All interactive elements meet 44px touch target, contrast requirements
- [ ] **Copy pass**: Professional, clear language; no technical jargon
- [ ] **Error message review**: All errors are user-friendly and actionable
- [ ] **QA scenarios** (smoke list)
  - [ ] Admin views user list (empty, populated, large list)
  - [ ] Admin grants access to non-admin user
  - [ ] Admin revokes access from another admin
  - [ ] Admin tries to revoke own access (should fail/disable)
  - [ ] Non-admin tries to access user management (should be denied)
  - [ ] Search by email (exact match, partial match, no results)
  - [ ] Sort by signup date (ascending, descending)
  - [ ] Network error handling (offline, timeout)
  - [ ] Concurrent grant/revoke (race condition handling)
