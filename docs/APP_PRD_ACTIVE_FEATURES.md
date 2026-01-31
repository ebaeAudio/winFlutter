# Win the Year — Product Requirements Document (Active Features)

**Document version:** 2026-01-31  
**Purpose:** Single PRD describing the app and all active features as implemented in the codebase.

---

## 1. Product Summary

**Win the Year** is a daily execution app that helps users "win today" through:

- **Must-Win** and **Nice-to-Do** tasks for a selected date
- **Habits** (global list) with per-date checkmarks
- **Daily reflection** (freeform note per date)
- **Daily score** (0–100%) from tasks and habits, with rollups (week/month/year)
- **Focus mode** ("one thing now") with timeboxing and optional **Dumb Phone** sessions (app blocking)
- **AI Assistant** (text and voice) that turns natural language into task/habit/reflection/date actions
- **Projects & notes**: Secret Notes (local, markdown + wiki links) and a notes workspace (Supabase-backed)
- **Integrations**: Linear (issue preview in task details), optional remote focus push (APNs)

The app targets **ADHD-friendly** workflows: reduced friction, externalized working memory, visible time (timeboxing), single obvious next action, and gentle recovery from stuck states.

**Platforms:** iOS, Android, macOS, Windows, Linux, Web.  
**Backend:** Supabase (Auth + Postgres with RLS). **Demo mode** uses local storage only.

---

## 2. Authentication & Account

### 2.1 Auth

- **Email/password** signup and login (min 8 characters)
- **Magic link** (passwordless) login
- **Password recovery** flow
- **Session persistence** across app restarts
- **Protected routes** (main features require sign-in unless demo mode)

### 2.2 Setup

- **Setup screen** for first-time or post-recovery configuration (e.g. password reset)

### 2.3 Demo Mode

- Local-only storage (no Supabase)
- Acts as authenticated demo user
- **Reset demo data** in Settings when enabled

---

## 3. Today Screen (Daily Command Center)

**Route:** `/today` (query `ymd` for deep link, e.g. `/today?ymd=2026-01-15`).

### 3.1 Date Navigation

- Previous / Next day
- Date picker (calendar)
- "Go to Today" shortcut
- Deep link support for opening a specific date

### 3.2 Task Management

- **Must-Win tasks:** Critical; recommended 1–3 per day. Full CRUD, completion toggle, strikethrough, progress (X/Y). "Big win" celebration when all Must-Wins are done.
- **Nice-to-Do tasks:** Optional; same CRUD and toggle; lower scoring weight; can be moved to Must-Win.
- **Task properties:** Title, type, completed, in-progress flag, goal date (overdue highlight), notes, next step / starter step, estimate/actual minutes, subtasks.
- **Task details:** Full-screen task view (`/today/task/:id`) with notes, subtasks, time fields, Linear issue preview, status chips, reachability FAB cluster.

### 3.3 Habits

- Global habit list; per-date completion toggle
- Inline create; daily progress (X/Y)

### 3.4 Daily Reflection

- Freeform text area; auto-save on blur; manual save; character limits

### 3.5 Custom Trackers

- User-defined tracker categories (e.g. Energy, Mood)
- 3-item structure per tracker (emoji + description)
- Tap to increment, long-press to decrement
- Daily/weekly/yearly targets with progress

### 3.6 Daily Score

- **Weights (default):** Must-Wins 50%, Nice-to-Do 20%, Habits 30%
- Groups with **zero items** are excluded (no penalty)
- **Formula:** `score = Σ(weight × completion) / Σ(weight)`; percentage = (score / maxScore) × 100
- **Labels:** Excellent ≥90%, Good ≥70%, Fair ≥50%, Needs Improvement &lt;50%
- **Coach message** by time of day and score (e.g. "Today is still winnable")

### 3.7 Dashboard Customization

- **Reorderable sections** (drag): Date, Assistant, Focus, Quick Add, Habits, Trackers, Must-Wins, Nice-to-Do, Reflection
- Reset to default order; layout persisted

### 3.8 Today Extras

- **Quick Add** (task/habit by type)
- **Morning wizard** (optional launch flow; last-shown date in settings)
- **Zombie task alert:** Surfaces stale/incomplete tasks; link to **Zombie Task Review** screen
- **Reflection card** and **Wrap-up checklist** (e.g. end-of-day)
- **Dumb Phone countdown card** when a Dumb Phone session is active (from Focus tab)

---

## 4. Focus Mode ("One Thing Now")

**Route:** `/focus` (policies: `/focus/policies`, edit: `/focus/policies/edit/:id`, history: `/focus/history`).

### 4.1 Today Focus Mode

- Toggle from Today; **single focus task**
- **Focus Action Lane:** focus task title, starter step, "Start (2 min)", timebox buttons (10/15/25/45 min), "I'm stuck" / "Switch task" / "Exit focus"

### 4.2 Starter Step

- "Next 2 minutes" action per task; editable via sheet; shown in Focus lane

### 4.3 "I'm Stuck" Flow

- Make it smaller (add/edit starter step), switch focus task, or exit focus; goal: next action in ≤3 taps

### 4.4 Timebox (Pomodoro) Timer

- Start/stop; durations 2/10/15/25/45 min; "+5 min"; end early; "wrap up soon" warning; timer persists in-app

### 4.5 Dumb Phone Mode (Distraction Blocking)

- **Policies:** Named (e.g. Work, Sleep); allowed-apps list per policy; policy editor
- **Sessions:** Duration (e.g. 5–180 min) or end-at time; presets (Light/Normal/Extreme) with friction: hold-to-unlock, unlock delay, emergency unlock limits
- **End early:** Hold-to-confirm; optional **clown camera check** (selfie + overlay, photo saved on device); optional **task unlock** (complete N selected tasks to unlock)
- **Integration with Today:** On session start can auto-navigate to Today, enable Focus, select first incomplete Must-Win, optionally auto-start 25-min timebox; snackbar confirmation
- **Session history** and **W celebration** (random chance on session completion)
- **NFC to end early:** Removed in current codebase; optional friction is documented elsewhere

### 4.6 Remote Focus

- **Remote focus commands** (e.g. start/stop from another device) via Supabase table + Edge Function
- **Remote focus push:** APNs push to iOS device when a remote command is inserted; requires Supabase + APNs secrets (see `docs/REMOTE_FOCUS_PUSH_SETUP.md`)

### 4.7 iOS Custom Shield (Task Callout)

- **iOS Screen Time / Family Controls:** When user tries to open a blocked app, a custom **Shield** (extension) can show one remaining task with encouraging copy and "Open Win the Year" CTA. Implementation in `ios/WinTheYearShieldConfig`; see `docs/IOS_CUSTOM_SHIELD_TASK_CALLOUT_PRD.md`.

---

## 5. AI Assistant

- **Text input** on Today: run button; response message; command tips/history
- **Voice input:** Push-to-talk; live transcript; mic level; auto-run on speech end (platform speech recognition); permission handling
- **Execution:** Allowlisted commands only; sequential execution; **preview sheet** for destructive/multi-action commands
- **Commands:**  
  **Date:** `date.shift`, `date.set`  
  **Task:** `task.create`, `task.setCompleted`, `task.delete`, `task.setStarterStep`, `task.setEstimate`  
  **Habit:** `habit.create`, `habit.setCompleted`  
  **Reflection:** `reflection.append`, `reflection.set`  
  **Focus:** (planned) `focus.start`, `focus.stop`
- **Backend:** Heuristic (regex) by default; optional LLM (e.g. OpenAI) for translation; execution always via app code paths; rate limiting and cost caps

---

## 6. Rollups (Analytics)

**Route:** `/settings/rollups` (linked from Settings).

- **Range:** Week / Month / Year
- **Summary:** Average % for period; delta vs previous period; date range label; color-coded delta
- **Chart:** Week/Month = one bar per day; Year = monthly averages
- **Daily breakdown list:** Per-day Must-Wins, Nice-to-Dos, Habits, overall %

---

## 7. Projects & Notes

**Route:** `/projects` (nav tab labeled "Notes"). Nested: `/projects/secret-notes?note=...`.

### 7.1 Projects Screen

- **Secret Notes** entry card (long-press to open); vision copy for "Notes & Projects" and second-brain roadmap
- **Notes & Projects** placeholder / future: inbox, project notes, daily scratchpad, linking to tasks/dates

### 7.2 Secret Notes

- **Markdown** editor with edit/preview; **wiki links** `[[Note]]`
- Multiple notes; auto-save (debounced); formatting toolbar (bold, italic, code, headings, checkboxes, links)
- **Local storage** (e.g. SharedPreferences); **privacy:** hidden entry (long-press on Projects)

### 7.3 Notes Workspace (Supabase-Backed)

- **NotesScreen**, **NoteEditorScreen**, **DailyScratchpadScreen** and notes data layer exist in `lib/features/notes/` and `lib/data/notes/`. Full routing (e.g. `/notes`, `/notes/:id`) may be in progress; see `docs/NOTES_ARCHITECTURE.md` and migrations for schema.

---

## 8. All Tasks View

**Route:** `/tasks`.

- Tasks across all dates; filter by type (Must-Win / Nice-to-Do) and completion; sort by date
- Open task details; toggle completion; navigate to task’s date

---

## 9. Settings

**Route:** `/settings`. Nested: rollups, trackers (new/edit), feedback, pitch, admin.

### 9.1 Account

- Show email; log out (with confirmation)

### 9.2 Trackers

- Link to **Custom Trackers** list and editor (create/edit categories and items)

### 9.3 Integrations

- **Linear:** Personal API key (secure); task notes parsed for `ABC-123`; issue preview in Task Details (title, description, state, assignee, link to Linear); refresh on demand

### 9.4 Dumb Phone Settings

- Auto-start 25-min timebox toggle
- Require clown camera check to end early
- (NFC to end early removed in current build)

### 9.5 Appearance

- **Mode:** System / Light / Dark
- **Theme palette:** Slate, Forest, Sunset, Grape
- **Layout:** Full-width toggle; one-hand mode with hand (Left/Right) selection

### 9.6 Support

- About / **Pitch** page
- **Send feedback** (bugs, suggestions)

### 9.7 Demo Mode

- Reset demo data (when demo mode is on)

---

## 10. Admin Dashboard

**Route:** `/settings/admin` or `/admin`. **Admin-only** (RLS / `is_admin()`).

- **User list:** Email, signup date, admin flag; search; grant/revoke admin (with confirmation and audit; self-revoke prevented)
- **Feedback triage:** List feedback by kind (Bug/Improvement); expandable cards with details and context

---

## 11. Command Palette & Quick Capture

- **Command palette:** ⌘K / Ctrl+K; fuzzy search; navigation (Today, Focus, Rollups, Projects, Tasks, Settings) and actions (New Task, New Must-Win); keyboard nav; shortcut hints
- **Quick capture:** ⌥N / Alt+N; parse `!task`, `#habit`, `note:`, `tomorrow`, `/focus 25`; type/date inference; submit/cancel shortcuts

---

## 12. UI/UX Conventions

- **Design:** Material 3; theme in `lib/app/theme.dart`; `AppScaffold`; spacing scale (`AppSpace`, `Gap`) in `lib/ui/spacing.dart`
- **Components:** Section headers, empty states, info banners, task lists, clown cam gate sheet, Linear issue block, command palette, quick capture, etc. in `lib/ui/components/`
- **Accessibility:** Touch targets ≥44px; contrast; semantic labels; focus order; error states
- **Navigation:** Bottom nav (mobile): Notes → Tasks → Now → Dumb → Settings. Desktop: sidebar + command palette and quick capture. **GoRouter**; deep links; notification/deep-link handlers in `AppRoot`

---

## 13. Data & Sync

- **Supabase:** PostgreSQL + Auth; RLS; user-scoped data
- **Tables (conceptual):** tasks (with details, subtasks, goal_ymd, next_step, etc.), habits, habit_completions, daily_reflections, task_subtasks, focus_policies, focus_sessions, focus_active_sessions, trackers, tracker_tallies, scoring_settings, notes (when used), user_feedback, admin_users; remote_focus_commands, user_devices for remote focus push
- **Local:** Demo mode and Secret Notes; theme/settings and dashboard layout persistence

---

## 14. Security & Privacy

- Auth and session handling via Supabase; logout clears local state
- RLS for isolation; API keys stored securely; assistant allowlist and server-side limits; clown photos local only
- Admin: RLS, audit trail, no self-revoke

---

## 15. Platform Notes

- **iOS:** Screen Time / Family Controls, custom Shield extension, APNs for remote focus push, speech recognition
- **Android:** Restriction/accessibility patterns for app blocking; speech recognition
- **macOS:** Desktop nav, dock badge (incomplete Must-Win count), shortcuts
- **Web:** PWA-capable; responsive

---

## Summary of Active Feature Areas

| Area              | Key features |
|-------------------|--------------|
| Auth & account    | Email/password, magic link, recovery, setup, demo mode |
| Today             | Date nav, Must-Win/Nice-to-Do, habits, reflection, trackers, score, dashboard order, quick add, morning wizard, zombie alerts, wrap-up, focus lane |
| Focus             | Single focus task, starter step, timebox, I'm stuck, Dumb Phone policies/sessions, clown cam, task unlock, history, W celebration, remote focus push |
| Assistant         | Text + voice, allowlisted commands, preview sheet |
| Rollups           | Week/month/year, average %, chart, daily list |
| Projects & notes  | Projects screen, Secret Notes (local, wiki links), notes workspace (Supabase, in code) |
| Tasks             | All tasks view, filters, task details, Linear preview |
| Settings          | Account, trackers, Linear, Dumb Phone options, theme, feedback, pitch, admin (when admin) |
| Global UX         | Command palette, quick capture, deep links, notifications |

This PRD reflects the app and active features as implemented in the repository as of the document date. For implementation details, see `agentPrompt.md`, `docs/FRONTEND_SPEC.md`, and `docs/COMPREHENSIVE_FEATURE_LIST.md`.
