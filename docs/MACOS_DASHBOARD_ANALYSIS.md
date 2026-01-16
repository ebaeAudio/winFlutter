# macOS Dashboard Analysis & Improvement Proposals

**Document version**: 2026-01-15  
**Purpose**: Analyze the Comprehensive Feature List and propose ways to create a better macOS dashboard experience for Mac users

---

## Executive Summary

Win the Year is primarily designed as a mobile-first app with Flutter's cross-platform capabilities enabling macOS support. However, Mac users have fundamentally different interaction patterns, screen real estate, and expectations than mobile users. This document analyzes the current feature set and proposes macOS-specific enhancements to create a premium desktop experience.

**Core thesis**: Mac users are typically in "work mode" with larger screens, keyboard-centric workflows, and the expectation of multi-window/persistent UI. The app should transform from a "phone replacement" to a "desktop command center" on macOS.

---

## 1. Analysis of Current Mobile-First Design

### 1.1 What Works Well on macOS

| Feature | Why It Works |
|---------|--------------|
| Today screen sections | Card-based layout adapts well to larger screens |
| Task Details screen | Full editing experience benefits from larger viewport |
| Rollups charts | More room for data visualization |
| Settings organization | Nested sections are easy to navigate |
| Dashboard customization | Drag-to-reorder works with trackpad |

### 1.2 What Feels Suboptimal on macOS

| Feature | Issue |
|---------|-------|
| Single-window, single-screen | Can't see Today + Focus at once |
| Mobile nav shell | Bottom tabs feel out of place on desktop |
| Full-screen modals | Sheets cover entire window unnecessarily |
| No keyboard shortcuts | Mac users expect Cmd+K, Cmd+N patterns |
| No menu bar presence | App "disappears" when minimized |
| Voice assistant UX | Push-to-talk designed for mobile |
| Dumb Phone Mode | Core feature has no desktop equivalent |
| No persistent task visibility | Must open app to see tasks |

### 1.3 Unused macOS Capabilities

The current app doesn't leverage:
- **Menu bar** (always-visible quick access)
- **Multiple windows** (Today + details side-by-side)
- **Keyboard shortcuts** (power user efficiency)
- **Dock badges** (unread/pending counts)
- **Notification Center widgets** (at-a-glance status)
- **Global hotkeys** (system-wide capture)
- **Spotlight integration** (search for tasks)
- **Handoff** (seamless iPhone → Mac transition)
- **Focus modes** (system-level focus integration)

---

## 2. Proposed macOS Dashboard Improvements

### 2.1 Architecture: Multi-Pane Desktop Layout

**Proposal**: Replace the mobile tab navigation with a desktop-optimized pane system.

```
┌─────────────────────────────────────────────────────────────────────┐
│ [Toolbar: Date Nav] [AI Input] [Quick Actions]          [Settings] │
├───────────────┬─────────────────────────────────────────────────────┤
│               │                                                     │
│   Sidebar     │                  Main Pane                          │
│               │                                                     │
│  • Today      │   ┌──────────────────┐  ┌────────────────────┐     │
│  • Focus      │   │   Focus Task     │  │   Quick Add        │     │
│  • Rollups    │   │   ────────────── │  │   ────────────     │     │
│  • Projects   │   │   "Write report" │  │   [_____________]  │     │
│  • All Tasks  │   │   Next: Draft    │  │   [Must-Win ▼]     │     │
│               │   │   [Start 2min]   │  │   [+ Add]          │     │
│  ─────────    │   └──────────────────┘  └────────────────────┘     │
│  Quick View   │                                                     │
│  ─────────    │   ┌─────────────────────────────────────────┐      │
│  ☐ Task 1     │   │   Today's Tasks                         │      │
│  ☐ Task 2     │   │   ─────────────────────────────────     │      │
│  ☑ Task 3     │   │   Must-Wins: 2/3        Nice-to-Do: 0/2 │      │
│               │   │   ☐ Write report        ☐ Email John    │      │
│  ─────────    │   │   ☐ Call client         ☐ Review docs   │      │
│  Score: 45%   │   │   ☑ Morning routine                     │      │
│  ─────────    │   └─────────────────────────────────────────┘      │
│               │                                                     │
│  [AI] [📅]    │   [Habits: 3/5]  [Trackers]  [Reflection]          │
│               │                                                     │
└───────────────┴─────────────────────────────────────────────────────┘
```

**Key changes**:
- **Collapsible sidebar** with navigation + quick task list
- **Persistent focus card** always visible at top
- **Score always visible** in sidebar
- **Section tabs** instead of full-screen switching

---

### 2.2 Menu Bar App ("Always There")

**Proposal**: Add a macOS menu bar presence for quick access without opening the main window.

**Menu bar features**:
1. **Status indicator**: Today's score % (color-coded: green/yellow/red)
2. **Quick dropdown** on click:
   - Focus task with "Start 2 min" button
   - Next 3 incomplete tasks (toggleable)
   - Current habit status
   - "Add task" quick input
   - Active focus session timer
3. **Focus session controls** (if Dumb Phone active):
   - Remaining time
   - "I'm stuck" shortcut
4. **Keyboard shortcut hint**: "⌥Space: Add task"

**Implementation notes**:
- Use `macos_ui` or native Swift via Pigeon for menu bar
- Persist even when main window is closed
- Low resource footprint (no full Flutter engine for menu bar)

```
   ┌─────────────────────────────┐
   │ Win: 45%           (click) │
   └────────────┬────────────────┘
                │
   ┌────────────▼────────────────┐
   │ Focus: "Write report"       │
   │ [Start 2 min]  [Stuck?]     │
   ├─────────────────────────────┤
   │ ☐ Write report              │
   │ ☐ Call client               │
   │ ☑ Morning routine           │
   ├─────────────────────────────┤
   │ Habits: 3/5 ████░░░         │
   ├─────────────────────────────┤
   │ + Add task... (⌥Space)      │
   ├─────────────────────────────┤
   │ [Open Win] [Settings]       │
   └─────────────────────────────┘
```

---

### 2.3 Global Keyboard Shortcuts

**Proposal**: Implement comprehensive keyboard shortcuts for power users.

#### Global Hotkeys (work anywhere on Mac)
| Shortcut | Action |
|----------|--------|
| `⌥Space` | Quick add task (opens mini capture window) |
| `⌥⇧R` | Add to reflection / quick note |
| `⌥⇧F` | Toggle focus mode |
| `⌥⇧V` | Start voice capture |

#### In-App Shortcuts
| Shortcut | Action |
|----------|--------|
| `⌘N` | New task |
| `⌘⇧N` | New Must-Win |
| `⌘K` | Command palette (like VS Code) |
| `⌘1-5` | Navigate to Today/Focus/Rollups/Projects/Settings |
| `⌘↩` | Toggle focus task completion |
| `⌘⇧↩` | Mark focus task in progress |
| `⌘T` | Jump to today's date |
| `⌘←/→` | Previous/next day |
| `⌘F` | Focus on search |
| `⌘.` | Open task details |
| `⌘,` | Open settings |
| `Esc` | Close modal/sheet |
| `Space` | Start focus timer (when in focus mode) |
| `⌘⇧S` | "I'm stuck" menu |

#### Quick Navigation
| Shortcut | Action |
|----------|--------|
| `↑/↓` | Navigate task list |
| `⌘↑/↓` | Move task up/down in list |
| `Tab` | Move between sections |
| `⇧Tab` | Move between sections (reverse) |

---

### 2.4 Command Palette (⌘K)

**Proposal**: Implement a VS Code-style command palette for keyboard-driven workflows.

**Features**:
- Fuzzy search across all actions
- Recent commands at top
- Category filtering (tasks, habits, navigation, settings)
- Inline task/habit creation

**Example commands**:
```
> add must win: Finish presentation
> complete: Morning routine
> go to tomorrow
> start focus 25 min
> open settings
> toggle dark mode
> add habit: Drink water
> note: Had a great meeting with...
```

**UI**:
```
┌─────────────────────────────────────────────┐
│ 🔍 Type a command or search...              │
├─────────────────────────────────────────────┤
│ Recent                                      │
│   • add must win: Finish presentation       │
│   • complete: Morning routine               │
├─────────────────────────────────────────────┤
│ Tasks                                       │
│   ☐ Write report                           │
│   ☐ Call client                            │
├─────────────────────────────────────────────┤
│ Actions                                     │
│   → Start focus (25 min)                   │
│   → Go to today                            │
│   → Open settings                          │
└─────────────────────────────────────────────┘
```

---

### 2.5 Quick Capture Window

**Proposal**: A lightweight, always-accessible capture window (like Raycast/Alfred).

**Behavior**:
- Global hotkey `⌥Space` summons it
- Appears as floating window near cursor
- Single input field with smart parsing
- Auto-dismisses after capture
- No need to open full app

**Smart parsing examples**:
- "Buy groceries" → Task (Nice-to-Do, today)
- "!Call client" → Must-Win (! prefix)
- "tomorrow !Review contract" → Must-Win for tomorrow
- "#Water 8 glasses" → Habit
- "note: Great idea for..." → Reflection append
- "/focus 25" → Start 25-min focus session

```
┌─────────────────────────────────────────┐
│ ⌥ Quick Capture                         │
├─────────────────────────────────────────┤
│ [_________________________________]     │
│                                         │
│ Tips: !task for Must-Win, #habit,       │
│       tomorrow, note:, /focus 25        │
│                                ⏎ Add    │
└─────────────────────────────────────────┘
```

---

### 2.6 "Desktop Focus Mode" (Dumb Phone Equivalent)

**Proposal**: Since Dumb Phone Mode doesn't apply to desktops, create a "Desktop Focus Mode" that helps users stay focused on Mac.

**Features**:

1. **App blocking (optional integration)**
   - Block distracting macOS apps via Screen Time API
   - Or: "Gentle block" — show overlay when opening blocked apps
   - Integrates with existing Focus Policy system

2. **Website blocker (new)**
   - Browser extension integration or DNS-level blocking
   - Whitelist/blacklist per focus policy
   - Block social media, news, etc.

3. **Full-screen focus overlay**
   - Hides dock, menu bar (except Win the Year)
   - Shows only: Focus task, timer, "I'm stuck"
   - Prevents desktop distractions

4. **Focus session sync**
   - If you start Dumb Phone Mode on iPhone, Mac shows:
     - "Focus session active on iPhone"
     - Matching timer
     - Encouragement to stay on task

5. **Pomodoro integration**
   - Built-in Pomodoro timer
   - Auto-start break reminders
   - Session logging for analytics

**Desktop Focus Mode UI**:
```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                         Focus Mode                              │
│                         ──────────                              │
│                                                                 │
│                    Write quarterly report                       │
│                    ─────────────────────                        │
│                                                                 │
│                    Next step: Draft introduction                │
│                                                                 │
│                         23:45                                   │
│                    [+5 min] [End] [I'm stuck]                  │
│                                                                 │
│                                                                 │
│                    Blocked: Twitter, Reddit, YouTube            │
│                    ─────────────────────────────                │
│                                                                 │
│                                                          [Exit] │
└─────────────────────────────────────────────────────────────────┘
```

---

### 2.7 Multi-Window Support

**Proposal**: Allow multiple windows for different views simultaneously.

**Use cases**:
- **Today + Task Details**: Edit task while seeing list
- **Today + Rollups**: Monitor progress while working
- **Detached timer**: Floating focus timer window
- **Quick note window**: Persistent reflection input

**Implementation**:
- `⌘⇧N`: New window
- Window type selector (Today, Focus Timer, etc.)
- Sync state across windows
- Remember window positions

---

### 2.8 Notification Center Widget

**Proposal**: Add a macOS Notification Center widget for at-a-glance status.

**Widget sizes**:

**Small**:
```
┌──────────────┐
│  Win: 45%    │
│  Must: 2/3   │
└──────────────┘
```

**Medium**:
```
┌─────────────────────────────┐
│  Today's Score: 45%         │
│  ████████████░░░░░░░░░░     │
│  Must-Wins: 2/3             │
│  Habits: 3/5                │
└─────────────────────────────┘
```

**Large**:
```
┌─────────────────────────────┐
│  Today's Score: 45%         │
│  ████████████░░░░░░░░░░     │
│                             │
│  Focus: Write report        │
│  [Start 2 min]              │
│                             │
│  ☐ Write report             │
│  ☐ Call client              │
│  ☑ Morning routine          │
└─────────────────────────────┘
```

---

### 2.9 System Integration

#### 2.9.1 macOS Focus Mode Integration
- Detect when system Focus mode is active
- Auto-enable app Focus mode when "Work" system focus is on
- Suggest enabling app Focus when system Focus starts

#### 2.9.2 Calendar Integration
- Show today's calendar events in sidebar
- Auto-create tasks from calendar items
- Block time for focus sessions

#### 2.9.3 Dock Badge
- Show incomplete Must-Win count
- Color-code by urgency (red if overdue)
- Animate on completion

#### 2.9.4 Handoff
- Start adding task on iPhone → continue on Mac
- Focus session started on phone → visible on Mac
- Seamless device switching

#### 2.9.5 Spotlight Integration
- Search tasks via Spotlight
- Quick actions from search results
- "Show in Win the Year" action

---

### 2.10 Voice Assistant for Desktop

**Proposal**: Redesign voice input for desktop context.

**Changes from mobile**:
- **Keyboard activation**: `⌥V` instead of tap
- **Continuous listening option**: "Hey Win" wake word (opt-in)
- **Visual feedback**: Compact waveform in menu bar during listening
- **Transcription window**: Shows live transcript as you speak
- **Multi-modal**: Speak + type to correct before executing

**Desktop voice UI**:
```
┌─────────────────────────────────────────┐
│ 🎤 Listening...                    [■]  │
├─────────────────────────────────────────┤
│                                         │
│  "Add must win call the client about    │
│   the contract..."                      │
│                                         │
│  ▁▂▃▅▂▁▂▅▃▂▁▂▃▅▂▁  ← Waveform          │
│                                         │
├─────────────────────────────────────────┤
│  [Run]  [Edit]  [Cancel]                │
└─────────────────────────────────────────┘
```

---

### 2.11 Data Visualization Dashboard

**Proposal**: Create a dedicated analytics dashboard view for Mac's larger screen.

**Features**:
- **Multi-period comparison**: Week, month, quarter, year side-by-side
- **Trend lines**: 7-day rolling average
- **Heat map**: Calendar view with daily scores as intensity
- **Category breakdown**: Must-Win vs Nice-to-Do vs Habits contribution
- **Time tracking**: Estimated vs actual time charts
- **Habit streaks**: Visual streak calendar
- **Focus analytics**: Session duration, completion rate, stuck events

**Layout**:
```
┌─────────────────────────────────────────────────────────────────────┐
│ Analytics Dashboard                                        [Export] │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │ This Week        │  │ This Month       │  │ This Year        │  │
│  │ Avg: 72%         │  │ Avg: 68%         │  │ Avg: 65%         │  │
│  │ ▲ +5% vs last    │  │ ▲ +2% vs last    │  │ ▼ -3% vs last    │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ Daily Scores - Last 30 Days                                 │   │
│  │ 100 ┤                                                       │   │
│  │  75 ┤    ▂▄▆    ▂▄▆█▆▄▂    ▂▄▆█▆▄                          │   │
│  │  50 ┤▂▄▆████▆▄▂████████▆▄▂████████▆▄▂                       │   │
│  │  25 ┤                                                       │   │
│  │   0 └───────────────────────────────────────────────────    │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────┐  ┌──────────────────────────────┐    │
│  │ Category Breakdown       │  │ Habit Streaks                │    │
│  │ ▓▓▓▓▓▓ Must-Win 45%     │  │ Morning: 🔥 12 days          │    │
│  │ ░░░░ Nice-to-Do 25%     │  │ Exercise: 🔥 5 days          │    │
│  │ ████ Habits 30%         │  │ Reading: 3 days              │    │
│  └──────────────────────────┘  └──────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

### 2.12 Sidebar Quick Actions

**Proposal**: Add a persistent quick-action bar in the sidebar.

**Actions**:
- **AI chat bubble**: Opens assistant
- **Calendar**: Date picker
- **Timer**: Quick start Pomodoro
- **Note**: Add to reflection
- **Habit**: Quick habit toggle

---

## 3. Implementation Priorities

### Phase 1: Foundation (High Impact, Moderate Effort)
1. **Menu bar app** — Always-visible presence
2. **Keyboard shortcuts** — Power user efficiency
3. **Command palette (⌘K)** — Unified action access
4. **Multi-pane layout** — Sidebar + main content

### Phase 2: Quick Capture (High Impact, Lower Effort)
5. **Quick capture window** — Global hotkey task entry
6. **Smart parsing** — Natural language task input
7. **Dock badge** — At-a-glance pending count

### Phase 3: Focus Enhancement (Medium Impact, Higher Effort)
8. **Desktop Focus Mode** — Desktop equivalent of Dumb Phone
9. **Website blocker** — Browser integration
10. **Focus overlay** — Distraction-free full-screen mode

### Phase 4: System Integration (Medium Impact, Variable Effort)
11. **Notification Center widget** — At-a-glance status
12. **macOS Focus mode sync** — System integration
13. **Calendar integration** — Event-to-task workflow
14. **Handoff** — Device continuity

### Phase 5: Analytics & Advanced (Lower Priority)
15. **Analytics dashboard** — Rich visualization
16. **Multi-window** — Parallel views
17. **Spotlight integration** — System search

---

## 4. Technical Considerations

### 4.1 Flutter macOS Capabilities
- Full macOS widget support
- Platform channels for native features
- `macos_ui` package for native controls
- `macos_window_utils` for window management

### 4.2 Native Swift Requirements
Some features require native implementation via Pigeon/FFI:
- Menu bar app (NSStatusItem)
- Global hotkeys (CGEventTap)
- Notification Center widgets (WidgetKit)
- Screen Time API
- Spotlight indexing

### 4.3 State Management
- Shared Riverpod state across windows
- Platform-aware feature flags
- Graceful degradation for unsupported features

### 4.4 Performance
- Menu bar should not run full Flutter engine
- Lazy-load analytics visualizations
- Cache frequently accessed data
- Background sync for real-time updates

---

## 5. Success Metrics

| Metric | Target | Rationale |
|--------|--------|-----------|
| Menu bar click rate | 20+ daily opens | Validates always-there UX |
| Keyboard shortcut usage | 50%+ of actions | Power user adoption |
| Quick capture usage | 10+ captures/week | Validates friction reduction |
| Desktop Focus sessions | 3+ per day | Feature relevance |
| Multi-window usage | 30%+ users | Layout preference |

---

## 6. Competitive Analysis

| Feature | Win the Year (Current) | Todoist | Things 3 | Sunsama |
|---------|------------------------|---------|----------|---------|
| Menu bar | ❌ | ✅ | ✅ | ✅ |
| Keyboard shortcuts | ❌ | ✅ | ✅✅ | ✅ |
| Command palette | ❌ | ✅ | ❌ | ❌ |
| Quick capture | ❌ | ✅ | ✅✅ | ✅ |
| Focus mode | ✅ (mobile) | ❌ | ❌ | ✅ |
| Multi-window | ❌ | ✅ | ❌ | ❌ |
| Widgets | ❌ | ✅ | ✅ | ❌ |
| ADHD-friendly | ✅✅ | ❌ | ❌ | ✅ |

**Opportunity**: Win the Year can differentiate by being the **ADHD-friendly productivity app with best-in-class Mac integration**.

---

## 7. Summary

The current Win the Year app is a powerful mobile-first productivity tool. To create a premium macOS experience, we should:

1. **Be always present** — Menu bar app with quick access
2. **Embrace the keyboard** — Comprehensive shortcuts and command palette
3. **Remove friction** — Global quick capture for instant task entry
4. **Respect screen space** — Multi-pane layout, not mobile tabs
5. **Integrate deeply** — Calendar, Focus modes, Notifications, Handoff
6. **Reinvent Dumb Phone** — Desktop Focus Mode with app/site blocking
7. **Visualize progress** — Rich analytics dashboard for larger screens

The goal is to make Mac users feel like they have a purpose-built desktop app, not a mobile port. The ADHD-friendly philosophy (reduce friction, make action obvious, recover gracefully) translates well to desktop—it just needs Mac-native patterns to deliver it.
