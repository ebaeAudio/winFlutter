## Win the Year (Flutter) — Improvements & Buildout Checklist

This checklist turns the current scaffold into a **professional, personal-feeling** MVP with parity to the PRD in `agentPrompt.md`.

### How to use this doc
- **Work sequentially**: do items `1.x` → `2.x` → `3.x`, etc.
- **Or batch by range**: e.g. “implement 1–2 (design + navigation)”, then “3–5 (Today)”.
- Each item includes:
  - **Goal**
  - **Acceptance criteria**
  - **Suggested implementation notes**
  - **Likely files**

---

## 0) Baseline hygiene (small, high-leverage)

### 0.1 Add a lightweight docs structure (optional)
- [ ] **Goal**: Keep docs discoverable as the app grows.
- [ ] **Acceptance criteria**:
  - [ ] `README.md` links to this checklist (and any future docs).
- [ ] **Likely files**: `README.md`

### 0.2 Add app-wide copy tone guidelines (personal + consistent)
- [ ] **Goal**: Make the app feel like one “voice” (coach-y but calm, consistent microcopy).
- [ ] **Acceptance criteria**:
  - [ ] A short “Voice & tone” section exists (1–2 paragraphs + examples).
  - [ ] Key screens use consistent phrasing (empty states, errors, confirmations).
- [ ] **Likely files**: `IMPROVEMENTS_CHECKLIST.md` (this doc), later `lib/app/strings.dart` (if you centralize copy)

---

## 1) Design system + UI polish (make it feel professional)

> Current state: Material 3 is enabled, but theme is mostly just a seed color (`lib/app/theme.dart`). Screens use direct `Padding + ListView + Card` with ad-hoc spacing.

### 1.1 Define a spacing scale + reusable gaps
- [ ] **Goal**: Consistent rhythm everywhere.
- [ ] **Acceptance criteria**:
  - [ ] A single spacing scale exists (e.g. 4/8/12/16/24/32).
  - [ ] Screens stop using “random” values and instead use the scale.
- [ ] **Implementation notes**:
  - [ ] Create `lib/ui/spacing.dart` with constants (e.g. `s4, s8, s12, s16, s24`).
  - [ ] Optional: small widgets like `Gap.h16`, etc.
- [ ] **Likely files**: `lib/ui/spacing.dart`, all screens in `lib/features/**`

### 1.2 Create a standard page scaffold wrapper
- [ ] **Goal**: Consistent padding, max width on larger screens, scroll behavior, safe areas.
- [ ] **Acceptance criteria**:
  - [ ] New `AppScaffold` used by all major screens (Today/Rollups/Settings/Auth).
  - [ ] On tablet/web widths, content is centered with a max width (e.g. 560–720).
- [ ] **Implementation notes**:
  - [ ] `AppScaffold(title, body, actions, bottomNav?)`.
  - [ ] Wrap body in `SafeArea` and `Align + ConstrainedBox`.
- [ ] **Likely files**: `lib/ui/app_scaffold.dart`, screens in `lib/features/**`

### 1.3 Upgrade theme from “seed only” to a cohesive system
- [ ] **Goal**: A distinct, modern look with consistent component styling.
- [ ] **Acceptance criteria**:
  - [ ] `ThemeData` defines at least:
    - [ ] `textTheme` (headline/body/label scale tuned)
    - [ ] `appBarTheme`
    - [ ] `cardTheme` (shape + surface tint behavior)
    - [ ] `inputDecorationTheme` (filled/outline style, consistent padding)
    - [ ] `filledButtonTheme` / `outlinedButtonTheme`
    - [ ] `segmentedButtonTheme`
    - [ ] `dividerTheme`
    - [ ] `snackBarTheme`
  - [ ] Light + dark both look intentional (not “default dark”).
- [ ] **Implementation notes**:
  - [ ] Keep 4 theme seeds, but define “surface language” (corner radius, elevation, container colors).
  - [ ] Consider `ColorScheme.fromSeed(...).copyWith(...)` for better surface contrast.
- [ ] **Likely files**: `lib/app/theme.dart`

### 1.4 Add a small component set (to avoid repeated UI patterns)
- [ ] **Goal**: Screens become compositional and consistent.
- [ ] **Acceptance criteria**:
  - [ ] Reusable widgets exist for:
    - [ ] `SectionHeader` (title + optional trailing action)
    - [ ] `EmptyStateCard` (icon + title + description + CTA)
    - [ ] `InfoBanner` (neutral/warn/error styles)
    - [ ] `PrimaryActionBar` (sticky bottom actions on forms, if desired)
- [ ] **Likely files**: `lib/ui/components/**` or `lib/ui/widgets/**`

### 1.5 Improve accessibility + touch ergonomics
- [ ] **Goal**: Better usability and “polish”.
- [ ] **Acceptance criteria**:
  - [ ] Tap targets are ≥ 44px.
  - [ ] Text contrast is sufficient in light/dark.
  - [ ] Inputs have helpful labels and error text (not just red `Text()`).
  - [ ] `Semantics` labels exist for non-textual controls where needed.
- [ ] **Likely files**: theme + all feature screens

---

## 2) Navigation & app structure (product-shaped, not a demo menu)

> Current state: `/home` is a list of buttons; subroutes are `/home/today`, `/home/rollups`, `/home/settings`.

### 2.1 Move to a bottom navigation shell (recommended)
- [ ] **Goal**: Make the app feel like a real mobile product: Today / Rollups / Settings.
- [ ] **Acceptance criteria**:
  - [ ] Bottom nav is persistent across primary tabs.
  - [ ] Back button behavior is sane (tab navigation doesn’t stack weirdly).
  - [ ] Deep links still work.
- [ ] **Implementation notes**:
  - [ ] Use `go_router` `ShellRoute` with `NavigationBar`.
  - [ ] Consider making Today the default initial route.
- [ ] **Likely files**: `lib/app/router.dart`, `lib/features/home/home_screen.dart` (may become shell), new `lib/ui/nav_shell.dart`

### 2.2 Decide what “Home” becomes (choose one)
- [ ] **Option A (simplest)**: Remove Home as a screen; “Today” is the landing tab.
- [ ] **Option B**: Keep Home as a light dashboard (today score preview + quick add task).
- [ ] **Acceptance criteria**:
  - [ ] There is a single obvious “start here” experience.
- [ ] **Likely files**: `lib/app/router.dart`, `lib/features/home/home_screen.dart`

### 2.3 Routing polish: safe redirects + “return to next”
- [ ] **Goal**: After signing in, return to the intended page.
- [ ] **Acceptance criteria**:
  - [ ] Auth flow supports a safe `next=` relative path.
  - [ ] Redirect logic doesn’t lose the user’s original intent.
- [ ] **Likely files**: `lib/app/router.dart`, `lib/features/auth/auth_screen.dart`

---

## 3) Data layer foundations (Supabase + Demo mode parity)

> Current state: demo mode affects auth state, but there’s no local data persistence layer for tasks/habits/reflections yet.

### 3.1 Define domain models
- [ ] **Goal**: Use consistent types across Supabase + demo/local implementations.
- [ ] **Acceptance criteria**:
  - [ ] Models exist for:
    - [ ] Task
    - [ ] Habit
    - [ ] HabitCompletion (or computed map)
    - [ ] DailyReflection
    - [ ] DailyScore (derived)
  - [ ] JSON serialization exists (manual or via small helpers).
- [ ] **Likely files**: `lib/domain/**` or `lib/models/**`

### 3.2 Create repositories with two implementations: Supabase + Local
- [ ] **Goal**: Same UI works in both real and demo mode.
- [ ] **Acceptance criteria**:
  - [ ] `TasksRepository`, `HabitsRepository`, `ReflectionsRepository`, `RollupsRepository` interfaces exist.
  - [ ] Supabase implementation uses authenticated user + RLS tables.
  - [ ] Local implementation uses `SharedPreferences` (or a better local DB if you choose later).
  - [ ] Switching is automatic based on `Env.demoMode` or Supabase configured state.
- [ ] **Implementation notes**:
  - [ ] For SharedPreferences, store per-user or per-demo data under stable keys.
  - [ ] Keep local schema versioned (`data_version`) to allow resets/migrations.
- [ ] **Likely files**: `lib/data/**`, `lib/app/env.dart`, `lib/app/supabase.dart`

### 3.3 Add a “Reset demo data” control
- [ ] **Goal**: Demo mode should be safe to experiment with.
- [ ] **Acceptance criteria**:
  - [ ] A settings control exists: “Reset demo data”.
  - [ ] Confirm dialog appears; reset clears demo keys and returns to an empty state.
- [ ] **Likely files**: `lib/features/settings/settings_screen.dart`, local repo implementation

---

## 4) Today screen (core MVP) — end-to-end

> Current state: date nav exists (prev/next/today) and a placeholder card. No tasks/habits/reflections/scoring.

### 4.1 Upgrade date controls (prev/next + date picker)
- [ ] **Goal**: Make date selection fast and clear.
- [ ] **Acceptance criteria**:
  - [ ] Prev / Next buttons remain.
  - [ ] Add a date picker (`showDatePicker`) that sets the selected date.
  - [ ] “Go to Today” appears only when not on today (optional polish).
  - [ ] Date is displayed in a friendly format (e.g. “Mon, Jan 5” + smaller YMD).
- [ ] **Likely files**: `lib/features/today/today_screen.dart`

### 4.2 Tasks: Must‑Win + Nice‑to‑Do lists (CRUD)
- [ ] **Goal**: This is the daily execution core.
- [ ] **Acceptance criteria**:
  - [ ] Two sections: Must‑Win and Nice‑to‑Do.
  - [ ] Create task (inline input or modal).
  - [ ] Toggle completed.
  - [ ] Edit title.
  - [ ] Delete with confirmation.
  - [ ] Empty states for each list with a helpful CTA.
- [ ] **Implementation notes**:
  - [ ] Keep interactions “1-hand friendly”: quick add, swipe actions optional.
  - [ ] Use optimistic updates with rollback (optional).
- [ ] **Likely files**: `lib/features/today/today_screen.dart`, repositories, providers/controllers

### 4.3 Habits: global list + per-date completion toggles
- [ ] **Goal**: Habits are stable; completions vary per day.
- [ ] **Acceptance criteria**:
  - [ ] Create habit (global).
  - [ ] List habits.
  - [ ] Toggle completion for selected date (upsert completion record).
  - [ ] Empty state encourages adding first habit.
- [ ] **Likely files**: Today screen + habits repo

### 4.4 Reflection editor (autosave + unsaved state)
- [ ] **Goal**: Reflection should feel safe (never lose text) and calm.
- [ ] **Acceptance criteria**:
  - [ ] Text area loads reflection note for date (default empty).
  - [ ] Auto-save on blur if changed.
  - [ ] Manual save button (optional) + status indicator:
    - [ ] “Saved”
    - [ ] “Saving…”
    - [ ] “Unsaved changes”
    - [ ] “Save failed” with retry
- [ ] **Likely files**: Today screen + reflections repo

### 4.5 Scoring + coach message card (per PRD rules)
- [ ] **Goal**: Show “how you’re doing today” in one glance.
- [ ] **Acceptance criteria**:
  - [ ] Daily score percent (0–100) derived from:
    - [ ] Must‑Win completion
    - [ ] Nice‑to‑Do completion
    - [ ] Habits completion
  - [ ] “Zero items => exclude group” rule implemented.
  - [ ] Label thresholds implemented (Excellent/Good/Fair/Needs Improvement).
  - [ ] Coach message changes based on label + time-of-day rule for today.
- [ ] **Likely files**: scoring utility (`lib/domain/scoring.dart`), Today UI

### 4.6 In-screen feedback (snackbars/toasts)
- [ ] **Goal**: Clear confirmations without clutter.
- [ ] **Acceptance criteria**:
  - [ ] Create/update/delete shows brief confirmation (SnackBar).
  - [ ] Failures show actionable message (not raw exception dump).
- [ ] **Likely files**: Today UI + common error mapping helper

---

## 5) Rollups screen — end-to-end

> Current state: segmented control exists; placeholder card.

### 5.1 Compute rollup ranges + previous period ranges
- [ ] **Goal**: Week/Month/Year with “vs previous” delta.
- [ ] **Acceptance criteria**:
  - [ ] Week: daily scores for last 7 days (or calendar week—choose and document).
  - [ ] Month: daily scores for last ~30 days (or calendar month—choose and document).
  - [ ] Year: monthly averages for last 12 months (or calendar year—choose and document).
  - [ ] Previous period computed consistently for delta.
- [ ] **Likely files**: `lib/features/rollups/rollups_screen.dart`, rollups repo/utilities

### 5.2 Build the rollups UI (avg + delta + chart + breakdown list)
- [ ] **Goal**: Quickly answer “Am I winning more this week than last?”
- [ ] **Acceptance criteria**:
  - [ ] Average % for selected range.
  - [ ] Delta vs previous period with clear up/down styling.
  - [ ] Chart:
    - [ ] Week/Month: one bar per day
    - [ ] Year: one bar per month average
  - [ ] Breakdown list shows each day (or month) with score + label.
- [ ] **Implementation notes**:
  - [ ] Start simple with a lightweight custom painter bar chart (no dependency), or add a chart package later.
- [ ] **Likely files**: rollups screen + `lib/ui/charts/**`

---

## 6) Settings screen — professional polish + useful controls

> Current state: email display + theme dropdown.

### 6.1 Make theme picker feel native and previewable
- [ ] **Goal**: Theme selection should be delightful, not a dropdown.
- [ ] **Acceptance criteria**:
  - [ ] Replace dropdown with a grid/list of theme “swatches” + names.
  - [ ] Current theme is clearly selected.
  - [ ] Change applies immediately and persists.
- [ ] **Likely files**: `lib/features/settings/settings_screen.dart`, `lib/app/theme.dart`

### 6.2 Add functional settings
- [ ] **Goal**: Provide expected controls.
- [ ] **Acceptance criteria**:
  - [ ] Demo reset (if demo mode enabled).
  - [ ] “About” section: app version/build (optional).
  - [ ] Logout button moved here (optional if using bottom nav).
- [ ] **Likely files**: Settings screen, repositories

---

## 7) Auth screen — usability + error handling polish

> Current state: works, but feels utilitarian and surfaces raw errors.

### 7.1 Improve form UX
- [ ] **Goal**: Reduce friction and improve clarity.
- [ ] **Acceptance criteria**:
  - [ ] Email validation (basic: contains `@`, trimmed).
  - [ ] Password reveal toggle.
  - [ ] Better inline error text (InputDecoration `errorText` where possible).
  - [ ] Loading state disables inputs + shows progress indicator.
- [ ] **Likely files**: `lib/features/auth/auth_screen.dart`, theme input styles

### 7.2 Friendly Supabase configuration state
- [ ] **Goal**: “Not configured” should guide the user without scaring them.
- [ ] **Acceptance criteria**:
  - [ ] Shows a polished info banner:
    - [ ] “Demo mode available”
    - [ ] “How to configure Supabase” (short)
- [ ] **Likely files**: Auth + Setup screens, common UI components

---

## 8) Assistant (text) — heuristic MVP

> Current state: not implemented.

### 8.1 Add assistant input on Today screen
- [ ] **Goal**: Fast capture of intent (“add must win: …”, “complete …”).
- [ ] **Acceptance criteria**:
  - [ ] Text input + send button.
  - [ ] Shows assistant response (“say”) and confirms executed commands.
  - [ ] Errors are non-destructive and explain what failed.
- [ ] **Likely files**: Today screen + assistant service

### 8.2 Implement command parsing + execution
- [ ] **Goal**: Convert natural-ish text into deterministic actions.
- [ ] **Acceptance criteria**:
  - [ ] Supported commands (heuristic):
    - [ ] date.shift {days}
    - [ ] date.set {ymd}
    - [ ] habit.create {name}
    - [ ] habit.setCompleted {name, completed}
    - [ ] task.create {title, taskType?}
    - [ ] task.setCompleted {title, completed}
    - [ ] task.delete {title}
    - [ ] reflection.append {text}
    - [ ] reflection.set {text}
  - [ ] Execution routes through the same repository/controller logic as UI buttons.
- [ ] **Likely files**: `lib/assistant/**`, Today controllers

---

## 9) Error handling, loading states, and resilience

### 9.1 Standardize “Async UI states”
- [ ] **Goal**: Consistent loading/error/empty handling across screens.
- [ ] **Acceptance criteria**:
  - [ ] Shared patterns/components exist for:
    - [ ] Loading skeleton or progress
    - [ ] Error state with retry
    - [ ] Empty state with CTA
- [ ] **Likely files**: `lib/ui/components/**`, all feature screens

### 9.2 Map raw exceptions to user-friendly messages
- [ ] **Goal**: Users should never see raw stack/SDK text.
- [ ] **Acceptance criteria**:
  - [ ] Errors shown in UI are concise and actionable.
  - [ ] Logging still retains raw exception details for debugging (optional).
- [ ] **Likely files**: `lib/app/errors.dart` (or similar), auth/today screens

---

## 10) Code organization & cleanup (keep it maintainable)

### 10.1 Establish folder conventions
- [ ] **Goal**: Clear separation: UI vs domain vs data.
- [ ] **Acceptance criteria**:
  - [ ] `lib/domain/**`: models + pure logic (scoring, rollup ranges).
  - [ ] `lib/data/**`: repositories + persistence.
  - [ ] `lib/ui/**`: shared UI components + scaffolds.
  - [ ] `lib/features/**`: screen composition + feature controllers/providers.
- [ ] **Likely files**: new folders + small refactors

### 10.2 Reduce widget bloat by extracting sub-widgets
- [ ] **Goal**: Each screen stays readable and testable.
- [ ] **Acceptance criteria**:
  - [ ] TodayScreen broken into small widgets (date header, score card, task section, habits section, reflection section, assistant).
- [ ] **Likely files**: `lib/features/today/**`

---

## 11) Testing & QA (minimal but meaningful)

### 11.1 Add a few smoke tests
- [ ] **Goal**: Prevent regressions on navigation + basic flows.
- [ ] **Acceptance criteria**:
  - [ ] At least:
    - [ ] Router redirect logic works for demo vs signed out vs setup required.
    - [ ] Theme persistence works.
    - [ ] Today scoring logic unit tests.
- [ ] **Likely files**: `test/**`, domain scoring file

### 11.2 Manual QA checklist (before shipping builds)
- [ ] **Goal**: Catch UX papercuts that tests won’t.
- [ ] **Acceptance criteria**:
  - [ ] Try on small phone + large phone + tablet/web width
  - [ ] Light and dark themes
  - [ ] Slow network simulation (Supabase) / offline mode (optional)
  - [ ] Very long task titles
  - [ ] Empty states everywhere

---

## Suggested implementation order (if you want the fastest “feels like an app” win)

- [ ] **A (UI foundation)**: 1.1 → 1.5
- [ ] **B (Navigation)**: 2.1 → 2.3
- [ ] **C (Data layer)**: 3.1 → 3.3
- [ ] **D (Today MVP)**: 4.1 → 4.6
- [ ] **E (Rollups MVP)**: 5.1 → 5.2
- [ ] **F (Settings/Auth polish)**: 6.1 → 7.2
- [ ] **G (Assistant)**: 8.1 → 8.2
- [ ] **H (Hardening)**: 9.1 → 11.2


