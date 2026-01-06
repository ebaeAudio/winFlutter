### Dumb Phone Session → Auto-Navigate to Today + Auto-Start Today Focus (PRD)

### Executive summary
When a user starts a **Dumb Phone Mode** session, the app should immediately take them to the **Today** screen and automatically start **Today “Focus mode”** (“One thing now”). This bridges the gap between “blocking distractions” and “doing the next right thing” with a single action.

### Problem statement
Today, starting Dumb Phone Mode begins platform restrictions, but the user can be left on the Dumb Phone dashboard without a clear “what do I do now?” next step.

This creates friction:
- Users successfully block distractions, but don’t get guided into a task.
- Users need multiple taps/navigation to reach Today and enable Focus mode.
- The moment of motivation (“start Dumb Phone Mode”) is the best time to direct attention.

### Goals
- **G1 — Single action → right place**: Starting Dumb Phone Mode routes the user to `Today`.
- **G2 — Immediately actionable**: Today Focus mode becomes enabled automatically.
- **G3 — Predictable + reversible**: Behavior is consistent, transparent, and easy to exit/override.
- **G4 — No regressions**: Dumb Phone Mode still starts/ends exactly as before; only the post-start UX changes.

### Non-goals (v1)
- Automatically creating tasks or changing task content.
- Changing platform restriction policy behavior, allowed app lists, friction settings, or permission/onboarding flows.
- Adding new “focus session” data models for Today (we’ll use existing Today focus mode state for v1).

---

### Current system (baseline)
- **Dumb Phone Mode** lives at route `'/home/focus'`.
  - User starts a session in `FocusDashboardScreen` via `ActiveFocusSessionController.startSession(policyId, duration)`.
- **Today** lives at route `'/home/today'`.
  - Today has an ADHD-friendly **Focus mode** stored per-day:
    - `focusModeEnabled` (bool)
    - `focusTaskId` (optional)
  - UI behavior:
    - If Focus mode is enabled, Today shows a “One thing now” section and selects a focus task (either `focusTaskId` or first incomplete Must‑Win).

---

### Proposed experience

### Primary user flow
1) User goes to **Dumb Phone Mode** (`/home/focus`).
2) User taps **Start session** and confirms.
3) App starts platform restrictions successfully.
4) App immediately routes to **Today** (`/home/today`).
5) App enables **Today Focus mode** for today’s date.
6) App auto-selects a “one thing now” focus task (when possible).
6) User sees “One thing now” and can begin.

### Secondary flows
- **If the user is already on Today** when starting Dumb Phone Mode (future entry point or deeplink):
  - Still enable Focus mode and keep them on Today.
- **If Today Focus mode is already enabled**:
  - Do not toggle it off/on; leave it enabled.
- **If there are no Must‑Wins**:
  - Focus mode still enables, and Today should show the existing empty-state guidance (“Add a Must‑Win…”).

### UX notes
- The routing should happen **only after** a successful Dumb Phone session start.
- Recommended: show a lightweight confirmation on Today like:
  - Snackbar: “Dumb Phone Mode started — Focus is on”
  - If a task was auto-selected: “Focusing: <task title>”
  - This helps users understand why they were navigated and what to do next.

---

### Functional requirements

### FR1 — Post-start navigation
After `startSession(...)` completes successfully:
- Navigate to `'/home/today'`.

### FR2 — Auto-enable Today Focus mode
After navigation to Today (or immediately before, if safe):
- Enable Today Focus mode for today’s `ymd`.
- Do not disable or overwrite user state beyond what is required to “start focus”.

### FR3 — Auto-select a focus task (ADHD-friendly default)
Goal: reduce cognitive load by ensuring “One thing now” always has a concrete target when possible.

Rule:
- If `focusTaskId` is already set for today, **preserve it**.
- Else, set `focusTaskId` to the **first incomplete Must‑Win** (sorted by existing list order) if one exists.
- Else (no incomplete Must‑Wins):
  - Leave `focusTaskId` as null.
  - Keep Focus mode enabled and place the user in the “Add a Must‑Win” path (UI already guides this).

Rationale:
- **ADHD users benefit from a single default** more than from being asked to choose.
- Persisting `focusTaskId` makes the focus target **stable** across re-renders/navigation/restarts, and avoids “it changed” confusion.
- The Today UI already provides “Pick different” and “Exit” to quickly override.

### FR4 — Failure behavior
- If `startSession(...)` fails (permissions, platform error, policy missing, etc.):
  - Do not navigate.
  - Keep the user on Dumb Phone Mode and surface the error (current behavior already shows “Session error” state).

### FR5 — No onboarding bypass
- If restriction permissions onboarding is required, the onboarding flow remains unchanged.
- Navigation to Today only occurs from the confirmed start action after session start succeeds.

---

### Edge cases & considerations
- **User cancels the “Start Dumb Phone Mode?” confirmation dialog**: no navigation; no focus changes.
- **Rapid repeated taps**: guard against double-start; only perform navigation once on success.
- **App lifecycle**: if the app is backgrounded during start, best-effort apply focus enablement when returning (v1 can ignore; v1.5 can harden).
- **Date**: Today Focus mode should apply to “today” date at the time of start.
- **Already active Dumb Phone session**:
  - Starting a new one may be blocked/allowed depending on current behavior; PRD does not change that logic.
  - If start action is disabled or no-op, do not navigate.

---

### ADHD UX rationale (why this is the best default)
- **Minimize branching**: don’t ask “what should I focus on?” at the exact moment the user is trying to escape distraction.
- **Immediate next action**: land on Today with one highlighted thing, not a dashboard.
- **Stable target**: once chosen, keep the same task as the focus target until the user changes it.
- **Easy escape hatches**: visible “Pick different” + “Exit” keeps users in control without adding decision friction up front.

---

### Technical design (proposed)
- Implement in the Dumb Phone start action handler (current location: `FocusDashboardScreen` Start button):
  - `await startSession(...)`
  - enable Today focus for today’s ymd via `TodayController.setFocusModeEnabled(true)`
  - optionally set `focusTaskId` for today via `TodayController.setFocusTaskId(...)` using rule FR3
  - `context.go('/home/today')`

Notes:
- This is intentionally a UI-level orchestration, not a deep coupling between FocusSession and Today domain models (v1).
- If we later add an explicit “Dumb Phone start triggers Today focus” setting, this orchestration becomes conditional.

---

### Analytics & success metrics (optional but recommended)
- **Event: dumb_phone_session_started**
  - properties: duration_minutes, policy_id, platform, success/failure
- **Event: dumb_phone_poststart_navigate_today**
- **Event: today_focus_auto_enabled**
- **Outcome**:
  - % of Dumb Phone starts that reach Today within 3s
  - task completion rate during Dumb Phone sessions (proxy: tasks completed while a focus session is active)

---

### Rollout plan
- **Phase 1**: Ship as the default behavior (ADHD-first UX).
- **Phase 2**: Add a Settings toggle (“After starting Dumb Phone Mode, open Today and start focus”) if users want control.

---

### Acceptance criteria
- Starting Dumb Phone Mode successfully results in navigation to `Today`.
- Today Focus mode is enabled after start.
- If start fails or user cancels confirmation, app does not navigate and does not change Today focus state.
- Existing Dumb Phone session start/end functionality remains unchanged aside from navigation + Today focus enablement.

---

### Open questions (product decisions)
- None for v1. If users request customization later, add a Settings toggle in Phase 2.


