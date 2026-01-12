### PRD: ADHD Execution Upgrade (“Win Today” becomes the best daily execution app for ADHD)

### Status
- **Owner**: Product
- **Repo**: `winFlutter` (Flutter)
- **Audience**: Product + Design + Engineering
- **Last updated**: 2026-01-12

---

### 1) Executive summary
People with ADHD (and many people who struggle with daily follow-through) don’t primarily need “more planning.” They need **reduced decision friction**, **externalized working memory**, **visible time**, and **a single obvious next action**.

This PRD proposes an “ADHD Execution Upgrade” that builds on the app’s existing pillars:
- **Today**: Must‑Win / Nice‑to‑Do / Habits / Reflection + daily score
- **Focus mode (“One thing now”)** (already described as ADHD-friendly)
- **Dumb Phone Mode / restriction engine**
- **Assistant** (natural language → actions)

We’ll ship an MVP that makes starting and sustaining action dramatically easier without introducing a new category system or a complicated calendar planner.

---

### 2) Problem statement
Users with ADHD often report:
- **Task initiation failure** (“I know what to do, but can’t start.”)
- **Time blindness** (poor time estimation, missed transitions)
- **Overwhelm from choices** (too many tasks/inputs, hard to pick)
- **Working-memory overload** (forgetting steps, losing context mid-task)
- **Motivation volatility** (needs immediate feedback/reward; long tasks feel impossible)
- **Context switching cost** (getting pulled into distracting apps/sites)

In the current app, users can create tasks and see a score, but the “bridge” from *intention* → *action right now* can still be too thin.

---

### 3) Goals and non-goals

### Goals
- **G1 — Make “start” easy**: Any Must‑Win can be turned into a concrete “next 2 minutes” action with one tap.
- **G2 — Reduce choice**: Default to a single recommended “One thing now” target and keep it stable until the user changes it.
- **G3 — Make time visible**: Show time boxes and transition cues so users feel time passing.
- **G4 — Keep users in the action context**: Tight integration with Dumb Phone Mode + focus sessions.
- **G5 — Improve daily follow‑through**: Higher Must‑Win completion rate and reduced “abandoned days.”

### Non-goals (v1)
- Building a full calendar-first planner (Motion/Sunsama replacement).
- Medical treatment, diagnosis, symptom scoring, or clinical claims.
- Social network / feed.
- Complex gamification economy (inventory, trading, etc.).

---

### 4) Target users and JTBD

### Primary personas
- **P1: “Time-blind doer”**: Wants to execute, but consistently underestimates time and misses transitions.
- **P2: “Overwhelmed planner”**: Captures too much, freezes at prioritization.
- **P3: “Motivation spiky”**: Can hyperfocus sometimes, but struggles with consistency and task initiation.

### Jobs To Be Done
- **JTBD1**: “When I feel the urge to finally be productive, help me start the right thing immediately.”
- **JTBD2**: “When I’m distracted, help me return to my task without shame or complexity.”
- **JTBD3**: “When I lose track of time, make the next transition obvious.”

---

### 5) Research synthesis (what helps + how it maps to product)

### Core patterns seen across ADHD strategies + successful ADHD-oriented tools
- **Externalize**: Make tasks, steps, and time visible (visual schedules/timers are common in ADHD-focused planners).  
  - Example references from popular ADHD tools/articles: Tiimo-style visual planning and countdown timers show up frequently in ADHD app roundups (`https://www.morgen.so/blog-posts/adhd-productivity-apps`, `https://en.wikipedia.org/wiki/Tiimo`).
- **Short intervals + breaks**: Pomodoro-style timeboxing is widely used as a focus scaffold (common in ADHD-oriented recommendations and apps).  
  - Example references: `https://www.forbes.com/health/mind/apps-for-adhd/`
- **Immediate feedback / light rewards**: Gamified “done” feedback can help motivation (e.g., Habitica-style rewards).  
  - Example references: `https://www.techradar.com/reviews/habitica`
- **Body doubling**: Co-working/accountability is a commonly recommended tactic; productized by services like virtual co-working platforms (frequently mentioned as a helpful ADHD pattern, though evidence quality varies by source).  
  - Example reference: `https://en.wikipedia.org/wiki/Body_doubling`

### Repo-specific “research” already in our docs
- The app already explicitly frames **Today Focus mode** as ADHD-friendly and outlines why “one stable default task” helps (see `docs/DUMB_PHONE_SESSION_AUTO_TODAY_FOCUS_PRD.md`).

### Evidence honesty note
This PRD intentionally separates:
- **Evidence-aligned behavioral scaffolds** (reduce friction, externalize, timebox, prompts)
- **Popular-but-variable tactics** (gamification, body doubling) that we can ship carefully behind settings/experiments

---

### 6) Product principles (ADHD-first UX)
- **Default to one path**: If the user has to choose, we already lost.
- **Small commitments**: “Start for 2 minutes” beats “finish the project.”
- **Stable target**: Don’t silently change what “focus task” is.
- **Gentle recovery**: When users slip, help them restart without shame.
- **Low configuration**: Minimal setup; smart defaults; settings only after value.

---

### 7) Proposed features (prioritized)

### MVP (ship first)

#### F1 — Focus mode v2: “One thing now” becomes a full action lane
**Problem addressed**: choice paralysis, task initiation, context loss  
**What changes**:
- Focus mode shows one “focus task” and an explicit **Next Action** block:
  - “Start (2 min)” button
  - optional “Timebox” (10/15/25/45 min) quick picks
  - “I’m stuck” button (see F3)
- Focus task remains stable until user changes it.

**Acceptance criteria**
- When Focus mode enabled, Today shows exactly one primary CTA (“Start”).
- Focus task is stable across navigation and app restart for the day.

#### F2 — “Next 2 minutes” starter steps (micro-step scaffolding)
**Problem addressed**: task initiation, overwhelm  
**What changes**:
- Each task can optionally store:
  - **starterStep** (string, e.g., “Open laptop and write title line”)
  - optional **checklist steps** (later phase; start with starterStep only for MVP)
- When a task is created (or when Focus mode picks a task), user can add a starter step in 1 tap.
- Assistant can set this via natural language (“For ‘Taxes’, set starter step to ‘Find W2 PDF’”).

**Acceptance criteria**
- A task can be updated with a starterStep.
- Focus mode displays starterStep prominently if present.

#### F3 — “I’m stuck” quick rescue (anti-shame, anti-freeze)
**Problem addressed**: emotional friction, stuck states  
**What changes**:
Tapping “I’m stuck” offers 3 fast options:
- **Make it smaller** (prompts for a 2-minute starter step, stores to task)
- **Switch focus** (choose a different Must‑Win; no browsing huge lists)
- **Take a break** (starts a short break timer, then returns to the focus task)

**Acceptance criteria**
- User can recover to a single next action in < 3 taps.

#### F4 — Time visibility: lightweight timeboxing + transition cues
**Problem addressed**: time blindness  
**What changes**:
- Add optional **estimatedMinutes** per task (simple number; optional).
- Focus mode supports a **timebox timer** (local, no notifications required for v1):
  - shows remaining time
  - “+5 min”, “End early”, “Switch task”
- Adds subtle transition cues inside the app UI (not system notifications in MVP):
  - 2-minute warning label (“Wrap up soon”)

**Acceptance criteria**
- User can start/stop a timebox from Focus mode.
- Timer state is visible and clear while on Today.

#### F5 — Deep integration: Dumb Phone Mode → Today Focus (already PRD’d) + optional “auto timebox”
**Problem addressed**: distraction leakage during initiation  
**What changes**:
- Adopt/ship the existing PRD behavior: starting Dumb Phone Mode routes to Today and enables Focus mode.
- Add an optional setting: “When Dumb Phone starts, start a 25-minute timebox.”

**Acceptance criteria**
- Behavior remains predictable and reversible.

---

### Phase 2 (next)

#### F6 — Brain dump → triage (capture everything, decide later)
**Problem addressed**: working-memory overload, overwhelm  
**What changes**:
- One “Brain dump” input that creates **Nice‑to‑Do** items by default for Today or a selected date.
- A “Triage” flow that promotes up to N items to Must‑Win (default N=3).

#### F7 — Gentle rewards without streak shame
**Problem addressed**: motivation volatility, avoidance after missing a day  
**What changes**:
- Celebrate completion with micro feedback (copy + subtle UI)
- Replace hard streak obsession with:
  - “Wins this week”
  - “Comeback wins” (days you returned after 0% yesterday)

#### F8 — Routines that become tasks automatically (templates)
**Problem addressed**: decision fatigue  
**What changes**:
- “Templates” that generate today’s Must‑Wins/Nice‑to‑Dos/habits quickly (opt-in).

---

### Phase 3 (bigger bets)

#### F9 — Body doubling (accountability sessions)
**Problem addressed**: initiation + sustained attention  
**What changes**:
- Lightweight “co-work” sessions (invite link; audio optional; privacy-first).
- Start with “solo body double”: an AI “presence” that checks in and anchors focus (non-therapeutic).

#### F10 — Calendar/time-blocking (only if demanded)
Only pursue if user research shows strong pull and retention impact.

---

### 8) Functional requirements (detailed)

### Data model additions (conceptual)
Extend existing task model with optional fields:
- **starter_step**: text nullable
- **estimated_minutes**: int nullable
- (Phase 2+) **steps**: json array (or separate table) if checklists are added

Local-only UI state (can be persisted locally per day):
- **active_timebox**: { taskId, startedAt, durationMinutes, remainingSeconds }

### Assistant commands (extend)
Add commands (local execution; can be heuristic or LLM-backed translator, per `agentPrompt.md`):
- `task.setStarterStep { title, starterStep }`
- `task.setEstimate { title, minutes }`
- `focus.start { title?, minutes? }` (minutes optional)
- `focus.stop {}`

---

### 9) UX requirements (fits this repo)
- Use **Material 3** + existing theme (`lib/app/theme.dart`)
- Screens use `AppScaffold` and spacing via `AppSpace` + `Gap` (see `docs/FRONTEND_SPEC.md`)
- Accessibility:
  - touch targets ≥ 44px
  - clear empty states + error states
  - calm, direct copy (“Start for 2 minutes”, “Pick a different task”)

---

### 10) Metrics and success criteria

### North Star
- **% of days where at least one Must‑Win is completed**

### Supporting metrics
- **Task initiation rate**: % of days with at least one “Start (2 min)” action
- **Focus timebox starts per day**
- **Return-to-focus rate**: after leaving Today, how often users resume the same focus task
- **Abandoned day reduction**: fewer days with 0 completions after opening app
- **Time estimate calibration** (optional): estimated vs actual timebox durations

---

### 11) Risks and mitigations
- **R1 — Feature bloat**: ADHD apps can overwhelm users with options.  
  - **Mitigation**: strict MVP, one primary CTA, progressive disclosure.
- **R2 — Shame/avoidance loops**: streaks can backfire.  
  - **Mitigation**: emphasize “comeback wins,” gentle language.
- **R3 — Privacy sensitivity**: tasks/reflections can be personal.  
  - **Mitigation**: clear privacy controls; no unnecessary sharing; minimize data retention for experiments.
- **R4 — Over-promising outcomes**: avoid “clinical” claims.  
  - **Mitigation**: position as productivity scaffolding, not treatment.

---

### 12) Rollout plan
- **Phase 0**: internal dogfood (team) on MVP Focus v2 + starter steps
- **Phase 1**: 10–20% feature flag rollout (if flags exist); otherwise ship with conservative defaults
- **Phase 2**: add Brain dump + triage and gentle rewards

---

### 13) Open questions
- Should timebox timers persist across app restarts (local persistence) in MVP, or is “while app is open” acceptable?
- Do we want estimates on **Must‑Wins only** at first to keep UI simpler?
- Should “Start for 2 minutes” create a lightweight log event for later “what worked” insights?


---

### 14) Implementation checklist (agent-ready, parallelizable)

### Workstream A — Data model + persistence
- [ ] **Add task fields**: `starter_step` (text nullable), `estimated_minutes` (int nullable)
  - [ ] **DB migration** (Supabase) + RLS check (no policy changes expected if using existing tasks table policies)
  - [ ] **Data layer**: update task DTO/model + serializers
  - [ ] **CRUD**: update task update/upsert flows to support these fields
  - [ ] **Acceptance**: can set/clear starter step and estimate; persists and loads correctly
- [ ] **Timebox session local persistence**
  - [ ] **Model**: `ActiveTimebox { taskId, startedAt, durationMinutes }`
  - [ ] **Storage**: persist per-day (and restore on app relaunch)
  - [ ] **Acceptance**: timer restores after app restart and continues accurately

### Workstream B — Today Focus mode v2 UI (“Action lane”) + starter step editor
- [ ] **Focus lane UI** on Today when focus mode enabled
  - [ ] **Primary CTA**: “Start (2 min)”
  - [ ] **Quick timeboxes**: 10 / 15 / 25 / 45
  - [ ] **Secondary actions**: “I’m stuck”, “Switch task”, “Exit focus”
  - [ ] **Display**: focus task title + (if present) starter step
  - [ ] **Acceptance**: exactly one visually primary CTA; accessible touch targets; uses `AppScaffold` + `Gap`/`AppSpace`
- [ ] **Starter step editor UI**
  - [ ] **Entry points**: from focus lane + from task row/menu
  - [ ] **Interaction**: add/edit/clear starter step
  - [ ] **Acceptance**: updates persist; inline error state + snackbar on failure

### Workstream C — Timer mechanics + “I’m stuck” rescue flow
- [ ] **Start/stop timebox** tied to focus task
  - [ ] **Start**: from “Start (2 min)” and quick timeboxes
  - [ ] **Controls**: +5 min, End early, Switch task
  - [ ] **Cue**: 2-minute remaining “Wrap up soon”
  - [ ] **Acceptance**: timer accuracy, no double-start, clear states
- [ ] **Edge cases**
  - [ ] Starting timer with no focus task: auto-pick per existing rules
  - [ ] Switching focus while timer running: prompt (end/switch/keep)
  - [ ] Leaving Today screen: timer remains visible/active when returning
- [ ] **“I’m stuck” modal/sheet** launched from Focus lane
  - [ ] **Make it smaller**: prompt for a 2-minute starter step → saves to task
  - [ ] **Switch focus**: pick from incomplete Must‑Wins (short list, no giant list browsing)
  - [ ] **Take a break**: start a short break timer (5 min default) then return to focus lane
  - [ ] **Acceptance**: user gets back to a single next action in ≤3 taps

### Workstream D — Assistant commands (optional but recommended)
- [ ] **Command schema additions**
  - [ ] `task.setStarterStep { title, starterStep }`
  - [ ] `task.setEstimate { title, minutes }`
  - [ ] `focus.start { title?, minutes? }`
  - [ ] `focus.stop {}`
- [ ] **Executor implementations**
  - [ ] Map commands → existing task update + focus/timebox controllers
  - [ ] **Acceptance**: assistant can set starter step/estimate and start/stop focus/timebox reliably

### Workstream E — Dumb Phone Mode integration
- [ ] **Ship the existing flow**: Dumb Phone start → navigate to Today + enable Focus mode (see `docs/DUMB_PHONE_SESSION_AUTO_TODAY_FOCUS_PRD.md`)
- [ ] **Optional setting**: “Auto-start 25-minute timebox when Dumb Phone starts”
- [ ] **Acceptance**: only navigates on successful session start; no behavior change on failure/cancel

### Cross-cutting (do once)
- [ ] **Accessibility review**: focus lane + sheets meet contrast and 44px targets
- [ ] **Copy pass**: calm, direct, no shame language
- [ ] **QA scenarios** (smoke list)
  - [ ] Fresh day with no Must‑Wins
  - [ ] Focus enabled + picks first incomplete Must‑Win
  - [ ] Starter step set/cleared
  - [ ] Timer start/stop, +5, end early, switch task
  - [ ] Dumb Phone start success/failure paths
