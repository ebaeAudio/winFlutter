### Project: “Win the Year” mobile rebuild (Flutter or React Native)

#### Goal
Rebuild the **current, implemented behavior** of the Win the Year app as a mobile app (Flutter or React Native), targeting iOS + Android.

This PRD is based on the existing Next.js/Supabase app implementation (tasks, habits, reflections, scoring + rollups, assistant) — not the older “future PRD” docs about customizable categories/partials.

---

## Product summary (what the app does)
A daily execution app that helps users “win today” via:
- Must‑Win tasks (critical) and Nice‑to‑Do tasks (optional) for a selected date
- Habits (global list) with per-date checkmarks
- Daily reflection note (per date)
- Daily score (0–100%) derived from tasks/habits
- Rollups view (week/month/year) with chart + comparison to previous period
- Optional Assistant: text input (and voice where supported) that translates simple commands into actions

Backed by Supabase Auth + Postgres with RLS. Also supports a demo mode that uses local storage only.

---

## Scope (MVP for mobile parity)
### In scope
- Auth: email/password login + signup; magic link login; logout
- Protected routes (must be signed in unless demo mode)
- Home screen: links to Today / Rollups / Settings / Logout
- Today screen:
  - date navigation (prev/next buttons, date picker, “Go to Today”)
  - daily score card + coach message
  - daily reflection editor with auto-save on blur + manual save
  - task lists (must-win + nice-to-do): CRUD + toggle completed
  - habits list: create habit + toggle completion for selected date
  - assistant UI (text) that can create/complete/delete tasks, create/complete habits, append/set reflection, shift/set date
- Rollups screen:
  - week/month/year segmented control
  - average % for range + comparison vs previous period
  - chart (bar sparkline)
  - daily breakdown list
- Settings: show email + theme picker (4 themes)
- Demo mode: local persistence instead of Supabase; reset demo data

### Out of scope (do not implement unless asked)
- Custom categories beyond must-win / nice-to-do / habits
- Partial completion percentages per task/habit
- Notifications, streaks, social, export/import, analytics, etc.

---

## Technical decisions (agent: propose + execute)
Pick one:
- **Flutter** (recommended if you want strongest cross-platform UI consistency)
- **React Native** (recommended if you want JS/TS parity with existing web stack)

Backend should remain **Supabase** for parity.

---

## Data model (Supabase Postgres)
Implement (or reuse) these tables + RLS policies:

### tasks
- id (uuid pk)
- user_id (uuid fk auth.users)
- title (text)
- type (text: 'must-win' | 'nice-to-do')
- date (date, YYYY-MM-DD)
- completed (bool)
- created_at/updated_at timestamps

### habits
- id (uuid pk)
- user_id (uuid fk auth.users)
- name (text)
- created_at/updated_at

### habit_completions
- id (uuid pk)
- habit_id (uuid fk habits)
- date (date)
- completed (bool)
- created_at
- unique(habit_id, date)

### daily_reflections
- id (uuid pk)
- user_id (uuid fk auth.users)
- date (date)
- note (text)
- created_at/updated_at
- unique(user_id, date)

### scoring_settings
- user_id (uuid pk)
- categories (jsonb) — array of {id,label,weight} (weights sum to 100)
Default:
- must-win: 50
- nice-to-do: 20
- habits: 30

---

## API contracts (mobile can call Supabase directly OR mirror these endpoints)
For parity, mobile must be able to do the equivalent operations:

### Tasks
- List tasks for date: GET (filter by date)
- Create task: title, type, date, completed? (default false)
- Update task: title? completed?
- Delete task

### Habits
- List habits (global per user)
- Create habit: name
- Get completions for date (for all user habits)
- Toggle completion for habit+date: upsert/set completed boolean

### Reflections
- Get reflection note for date (default empty)
- Upsert reflection note for date

### Rollups
- Query daily scores for date range start..end
- Also return “startDate” (earliest date user has activity, from earliest task date or earliest habit created date)

### Assistant
- POST: { transcript, baseDateYmd } -> { say, commands[] }
- commands supported:
  - date.shift {days}
  - date.set {ymd}
  - habit.create {name}
  - habit.setCompleted {name, completed}
  - task.create {title, taskType?}
  - task.setCompleted {title, completed}
  - task.delete {title}
  - reflection.append {text}
  - reflection.set {text}

Assistant can be:
- heuristic-only initially (local parsing), OR
- optional OpenAI-backed translator if env configured (but **execution must always be the app’s own code paths**)

---

## Scoring model (current behavior)
Daily score is computed over 3 weighted groups:
- Must‑Win tasks
- Nice‑to‑Do tasks
- Habits

Group completion:
- tasks group completion = completedCount / totalCount
- habits group completion = completedHabitsForDate / totalHabits

Important rule:
- If a group has **zero items**, exclude it from that day’s max score (no penalty).

Compute:
- score = Σ(weight * completion) over non-empty groups
- maxScore = Σ(weight) over non-empty groups
- percentage = maxScore > 0 ? (score / maxScore)*100 : 0

Label thresholds:
- Excellent ≥ 90
- Good ≥ 70
- Fair ≥ 50
- Needs Improvement < 50

Coach message:
- If viewing today and percentage < 100:
  - morning/evening: “Today is still winnable.”
  - afternoon: “You’re making progress. Keep going.”
- Else: rotate message based on label.

---

## UX/screens (acceptance criteria)
### Auth
- User can sign up with email + password (min 8 chars), confirm password
- User can login with email+password
- User can request magic link login
- Successful auth returns to the “next” path (safe relative path)

### Home (protected)
- Buttons: Today, Rollups, Settings, Logout

### Today (protected)
- Date controls: prev, next, date picker, go-to-today
- Loads:
  - tasks for date
  - habits list + completions for date
  - reflection note for date
- Must‑Win task list:
  - create, edit title, toggle complete, delete w/ confirmation
- Nice‑to‑Do task list: same
- Habits:
  - create habit
  - toggle completion for date
- Reflection:
  - edit note
  - auto-save on blur if changed
  - show “unsaved changes” state
- Assistant:
  - text input runs command -> app executes resulting actions
  - show confirmation/toast feedback

### Rollups (protected)
- Week/month/year segmented control
- Average % for period + “vs previous” delta
- Bar chart:
  - week/month: one bar per day
  - year: monthly averages
- Daily breakdown list

### Settings (protected)
- show email
- theme picker with 4 themes; persist on device

### Demo mode (optional but parity)
- When enabled, app acts as authenticated demo user
- Uses local storage only
- Today shows “Reset demo data” control

---

## Environment variables (expected)
- SUPABASE_URL / SUPABASE_ANON_KEY (platform-appropriate naming)
- DEMO_MODE flag (optional)
- Assistant (optional): OPENAI_API_KEY, OPENAI_MODEL, rate limiting knobs

---

## Delivery plan (agent should execute in new repo)
1. Scaffold Flutter or React Native app with navigation + state management.
2. Implement Supabase auth flows + session persistence.
3. Implement Today screen end-to-end (tasks/habits/reflection + score).
4. Implement Rollups (range selection + aggregation + chart).
5. Implement Settings + theme persistence.
6. Implement Assistant (heuristic first; optional LLM later).
7. Add minimal smoke tests for critical flows.

---

## Open questions (ask user before making irreversible choices)
- Flutter or React Native?
- Do you want to call Supabase **directly** from mobile, or via a thin API layer (for rate limiting / assistant / security)?
- Should Demo Mode exist in the mobile rebuild?
- Should scoring settings be user-editable in v1 mobile (API exists, no UI exists currently)?