# PRD: Task Details (Notes, Tracking Fields, Subtasks)
**Project**: Win the Year (Flutter)  
**Author**: AI (Cursor)  
**Date**: 2026-01-06  
**Status**: Draft

---

### Summary
Add a **Task Details** experience so users can attach **notes** and other **tracking details** to a task, and optionally create **subtasks**. From the Today task list, a user can open a dedicated detail screen (via **double-tap** or an environment-appropriate alternative) to view/edit task metadata without cluttering the main list.

This must work in both:
- **Supabase mode** (signed-in): tasks are stored in Supabase (`tasks` table).
- **Demo/local mode**: tasks are stored in `SharedPreferences` as JSON (see `TodayDayData` local serialization).

---

### Problem / Opportunity
Today’s tasks are intentionally lightweight (title/type/completed). This makes the list fast, but it limits:
- Capturing context (“why this matters”, “next step”, “blocked by”)
- Breaking a task into actionable subtasks
- Tracking practical execution details (time estimate, actual time, status notes)

Users currently resort to daily Reflection or external notes, which makes it harder to keep task context tied to the work item.

---

### Goals
- **Fast access to task context**: open details directly from the task list.
- **Notes on tasks**: freeform text with autosave or explicit save.
- **Subtasks**: quick checklist inside a task (add/complete/reorder/delete).
- **Minimal clutter in Today list**: show small indicators (e.g., note/subtask count) without turning the list into a project manager.
- **Environment-aware interaction**: use double-tap where it makes sense, but provide a discoverable fallback that works across mobile/web/desktop and accessibility settings.

---

### Non-Goals (for MVP)
- Rich text editor (Markdown toolbar, attachments, images, links)
- Reminders/notifications, recurring subtasks, dependencies between tasks
- Full cross-day tasks/projects (beyond viewing/editing the task’s own date/type)
- Collaboration/sharing
- Complex analytics dashboards

---

### Users / Use Cases
- **Capture context**: “Email John — ask for invoice #; mention contract clause 3.”
- **Break down**: “Renew passport” → “Find docs”, “Take photo”, “Book appointment”.
- **Track execution**: estimate 15m, actual 32m, “Blocked until Sarah replies”.
- **Quick review**: open a task and see what to do next without leaving the app.

---

### UX Overview

#### Entry points (Today list)
Primary: open Task Details from a task row.

Because interaction expectations differ by environment, implement **at least two** entry paths:
- **Gesture-based**:
  - **Touch devices (iOS/Android)**: double-tap to open details; long-press as fallback.
  - **Pointer devices (web/desktop)**: double-click to open details; right-click/context menu optional.
- **Discoverable**:
  - Add a `PopupMenuItem` such as **“Details”** to the existing overflow menu.
  - Optional: add a trailing chevron/info icon that always opens details.

Accessibility requirement: users must be able to open details without relying on double-tap timing.

#### Task Details Screen (new)
Screen contents (MVP):
- **Header**:
  - Task title (editable)
  - Type (Must‑Win / Nice‑to‑Do)
  - Completed toggle
  - Date (read-only in MVP; editable in V2)
- **Notes**:
  - Multi-line text field
  - Autosave on blur + explicit “Saved” feedback (SnackBar) OR a Save button (choose one consistent pattern)
- **Subtasks**:
  - Add subtask (single-line input)
  - Checklist with toggle complete
  - Reorder (optional in MVP; otherwise append-only)
  - Delete subtask
- **Tracking fields (initial set)**:
  - Estimate (minutes)
  - Actual (minutes)
  - “Next step” (short text) OR “Blocked by” (short text) — pick one for MVP to avoid bloat

#### Small indicators in Today list (optional but recommended)
Without opening details, users should see that a task has extra info:
- Note icon if notes exist
- “3” badge if subtasks exist

---

### Functional Requirements

#### FR1 — Open details from Today list
- User can open Task Details for a task from Today list via:
  - Double-tap/double-click **and**
  - Overflow menu item **Details**

#### FR2 — View and edit task title and completion
- Title edits persist.
- Completed toggle persists and reflects back in Today list.

#### FR3 — Task notes
- Add/edit notes for a task.
- Notes persist across app restart and across devices (Supabase mode).

#### FR4 — Subtasks
- Create, edit (title), complete/uncomplete, and delete subtasks.
- Subtasks persist across app restart and across devices (Supabase mode).

#### FR5 — Tracking fields (MVP subset)
- Persist at least one lightweight tracking group, e.g.:
  - `estimateMinutes` (int)
  - `actualMinutes` (int)
  - `nextStep` (string) **or** `blockedBy` (string)

---

### Non-Functional Requirements
- **Performance**: Today list remains fast; details data loads lazily (on detail screen).
- **Reliability**: In Supabase mode, failed saves must surface a user-visible error and allow retry.
- **Offline**:
  - MVP: best-effort (if offline, show “Couldn’t save” and keep local draft until user retries).
  - V2: queued sync.
- **Accessibility**:
  - Details entry not dependent on double-tap.
  - Large text support, focus order, semantic labels for toggles.

---

### Data / Storage Design

#### Current baseline
- **Supabase mode**: `tasks` table stores core fields (id/user_id/title/type/date/completed/created_at/updated_at).
- **Demo/local mode**: tasks stored inside `TodayDayData` JSON in `SharedPreferences`.

#### Proposed Supabase schema (recommended)
Option A (simplest for MVP): add columns to `tasks` and a new `task_subtasks` table.

- **`tasks` additions**:
  - `notes` (text, nullable)
  - `estimate_minutes` (int, nullable)
  - `actual_minutes` (int, nullable)
  - `next_step` (text, nullable) OR `blocked_by` (text, nullable)
  - (Optional) `details_updated_at` (timestamptz)

- **`task_subtasks` table**:
  - `id` (uuid, pk)
  - `task_id` (uuid, fk → `tasks.id`, indexed)
  - `title` (text)
  - `completed` (bool)
  - `sort_order` (int) or `created_at` ordering
  - `created_at`, `updated_at`

Row Level Security:
- Only owner can read/write via join on `tasks.user_id = auth.uid()`.

#### Demo/local mode storage
Extend the locally-serialized task JSON (backward compatible):
- Add optional fields to the local task model:
  - `notes?: string`
  - `estimateMinutes?: int`
  - `actualMinutes?: int`
  - `nextStep?: string` / `blockedBy?: string`
  - `subtasks?: [{ id, title, completed, createdAtMs }]`

Compatibility:
- Existing stored days missing new fields must still parse (defaults).

---

### API / Code Architecture (high-level)
To keep Today list lightweight, split “task summary” vs “task details”:
- **Task summary**: what the Today list already uses (id/title/type/completed).
- **Task details**: notes + tracking + subtasks.

Repository approach options:
- Extend `TasksRepository` with:
  - `Future<Task> getById(String id)` (returns full detail fields)
  - `Future<Task> updateDetails(...)`
  - plus subtask CRUD
- OR add a dedicated `TaskDetailsRepository` (cleaner separation).

Navigation:
- Add a new GoRouter route under `/home/today`, e.g.:
  - `/home/today/task/:id` (recommended)
  - Optional query param `ymd` if needed later for local-mode lookup.

---

### Interaction Spec (Environment-aware)

#### Default behavior
- **Overflow menu**: always includes **Details**.
- **Gesture**:
  - Touch: double-tap row → open details; long-press row → open details (or show context menu with Details).
  - Pointer: double-click row → open details.

#### Notes on discoverability
Double-tap is not obvious. The “Details” menu item ensures users can find the feature without learning a hidden gesture.

---

### Error States / Edge Cases
- **Task deleted while viewing details**: show “Task not found” and pop back.
- **Supabase unauthenticated mid-session**: redirect to auth; prevent writes.
- **Sync conflicts** (V2): last-write-wins initially; later show “edited on another device” warning.
- **Focus mode**: if current focus task is opened, details screen must not disable focus flow; closing details returns to Today without changing focus selection.

---

### Analytics / Telemetry (optional)
Track high-level usage:
- `task_details_opened` (source: doubleTap / menu / icon; environment: ios/android/web)
- `task_notes_saved` (chars_count)
- `subtask_created`, `subtask_completed`
- `task_tracking_updated` (fields_changed)

---

### Rollout Plan

#### MVP (v1)
- Task Details screen
- Notes (text)
- Subtasks (add/complete/delete)
- 1–3 tracking fields (estimate/actual + nextStep OR blockedBy)
- Entry: Details menu item + environment gesture

#### V2
- Reorder subtasks
- Edit task date (move to a different day)
- Assistant support: “add note to task …” / “add subtask to …”
- Offline queue + sync conflict handling

---

### Acceptance Criteria (MVP)
- From Today list, a user can open a Task Details screen for any task using **Details** in the overflow menu.
- On the primary target environment(s), double-tap/double-click also opens Task Details.
- Notes persist correctly in both demo/local mode and Supabase mode.
- Subtasks persist correctly in both demo/local mode and Supabase mode.
- Today list remains readable and performant; no full notes rendered inline.
- No accessibility regressions: a user can access Task Details without relying on timing-based gestures.


