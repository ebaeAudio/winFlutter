# Win the Year — Comprehensive Feature List

**Document version**: 2026-01-16  
**Purpose**: Exhaustive catalog of all features in the Win the Year app

---

## 1. Core Philosophy

Win the Year is a daily execution app designed to help users "win today" through:
- Focused task prioritization (Must-Wins vs Nice-to-Dos)
- Habit tracking with daily accountability
- Daily reflection and scoring
- Deep focus sessions with distraction blocking
- AI-powered voice and text assistant

The app specifically targets ADHD-friendly workflows with:
- Reduced decision friction
- Externalized working memory
- Visible time (timeboxing)
- Single obvious next action
- Gentle recovery from stuck states

---

## 2. Authentication & Account

### 2.1 Authentication Methods
- **Email/password login and signup** (minimum 8 characters)
- **Magic link login** (passwordless email)
- **Password recovery** flow
- **Session persistence** across app restarts
- **Protected routes** (authentication required for main features)

### 2.2 Demo Mode
- Local-only storage (no Supabase)
- Acts as authenticated demo user
- Reset demo data option
- Full feature parity for evaluation

---

## 3. Today Screen (Daily Command Center)

### 3.1 Date Navigation
- **Previous/Next day buttons**
- **Date picker** (calendar modal)
- **"Go to Today" button** (quick jump to current day)
- **Deep link support** (e.g., `/today?ymd=2026-01-15`)

### 3.2 Task Management

#### 3.2.1 Must-Win Tasks
- Critical tasks that "make today a win"
- Recommended: 1–3 per day (intentionally limited)
- Full CRUD: create, read, update, delete
- Completion toggle
- Strikethrough styling when completed
- Progress indicator (X/Y completed)
- "Big win" celebration when all Must-Wins completed

#### 3.2.2 Nice-to-Do Tasks
- Optional tasks without guilt if delayed
- Same CRUD and toggle functionality
- Lower scoring weight than Must-Wins
- Can be promoted to Must-Win (move between lists)

#### 3.2.3 Task Properties
- **Title** (required)
- **Type** (Must-Win or Nice-to-Do)
- **Completed** (boolean)
- **In Progress** indicator
- **Goal date** (optional due date with overdue highlighting)
- **Notes** (freeform text for context)
- **Next Step / Starter Step** (the "next 2 minutes" action)
- **Estimate** (minutes)
- **Actual** (minutes spent)
- **Subtasks** (checklist within a task)

#### 3.2.4 Task Details Screen
- Full-screen dedicated view for task editing
- Notes editor with auto-save
- Subtask management (add/complete/delete)
- Time tracking fields
- Linear integration preview (see Integrations)
- Quick status chips (Completed, In Progress)
- Reachability FAB cluster for one-hand navigation

### 3.3 Habits
- **Global habit list** (persists across days)
- **Daily completion toggle** per habit
- Create new habits inline
- Progress counter (X/Y completed for the day)

### 3.4 Daily Reflection
- **Brain dump textarea** (freeform daily journaling)
- **Auto-save on blur** (when leaving the field)
- Manual "Done" button
- Character count/limits

### 3.5 Custom Trackers
- **User-defined tracker categories** (e.g., "Energy", "Mood")
- **3-item structure per tracker** with emoji + description
- **Tap to increment** / **Long-press to decrement**
- **Daily, weekly, or yearly targets** with progress display

### 3.6 Daily Score
- **Weighted scoring model**:
  - Must-Wins: 50% weight (default)
  - Nice-to-Dos: 20% weight
  - Habits: 30% weight
- **Empty group handling**: groups with zero items don't penalize
- **Score calculation**: `score = Σ(weight × completion) / Σ(weight)`
- **Label thresholds**:
  - Excellent ≥ 90%
  - Good ≥ 70%
  - Fair ≥ 50%
  - Needs Improvement < 50%
- **Coach message** (contextual encouragement based on time of day and score)

### 3.7 Dashboard Customization
- **Reorderable sections** via drag handles
- **Section types**:
  - Date
  - Assistant
  - Focus
  - Quick Add
  - Habits
  - Trackers
  - Must-Wins
  - Nice-to-Do
  - Reflection
- **Reset to default order** option
- Persistent layout preferences

---

## 4. Focus Mode ("One Thing Now")

### 4.1 Today Focus Mode
- **Toggle on/off** from Today screen
- **Single focus task** selection
- **Stable target** (doesn't silently change)
- **Focus Action Lane** UI when enabled:
  - Prominent display of focus task title
  - Starter step display (if set)
  - Primary CTA: "Start (2 min)"
  - Quick timebox buttons: 10 / 15 / 25 / 45 minutes
  - Secondary actions: "I'm stuck", "Switch task", "Exit focus"

### 4.2 Starter Step (Micro-Step Scaffolding)
- **"Next 2 minutes" action** for any task
- Displayed prominently in Focus lane
- Editable via bottom sheet
- Helps overcome task initiation paralysis

### 4.3 "I'm Stuck" Rescue Flow
- **Make it smaller**: Prompt to add/edit a starter step
- **Switch focus**: Pick a different Must-Win
- **Exit focus**: Turn off focus mode entirely
- Goal: recover to a next action in ≤3 taps

### 4.4 Timebox Timer
- Start/stop local timer
- Duration options: 2 / 10 / 15 / 25 / 45 minutes
- "+5 min" extension
- "End early" option
- "Wrap up soon" warning at 2 minutes remaining
- Timer persists while navigating within app

---

## 5. Dumb Phone Mode (Distraction Blocking)

### 5.1 Core Concept
- Transforms smartphone into a "dumb phone"
- Blocks distracting apps
- Allows essential apps (phone, messages, maps)
- Integrates with platform-specific restriction APIs

### 5.2 Platform Support
- **iOS**: Screen Time API, Family Controls framework
- **Android**: Accessibility Service, Device Admin API, Usage Stats
- **Blocking behavior**: Shows blocking screen when opening restricted apps

### 5.3 Focus Policies
- **Named policies** (e.g., "Work Mode", "Sleep Mode")
- **Allowed apps list** per policy
- **Multiple policies** for different contexts
- Policy editor screen

### 5.4 Session Management
- **Duration-based sessions** (slider: 5–180 minutes)
- **End-at time** (pick a specific end time)
- **Session presets**:
  - Light (low friction)
  - Normal (balanced)
  - Extreme (high friction, no emergency exits)
- **Friction settings** per preset:
  - Hold-to-unlock duration (seconds)
  - Unlock delay (seconds)
  - Emergency unlock time (minutes)
  - Max emergency unlocks per session

### 5.5 End Session Controls
- **Hold to end early** button with configurable duration
- **Unlock delay** after hold completes
- **Automatic end** at planned time

### 5.6 Advanced Friction (Optional)
- **NFC card requirement** to end early
  - Pair/unpair card in Settings
  - Scan card to validate end
  - Constant-time hash comparison for security
  - Purpose-based scanning (pair, validate start/end, unpair)
  - Enhanced error handling with user-friendly messages
  - Fallback to Android sheet when system prompt unavailable
- **Clown camera check** to end early
  - Opens selfie camera with clown overlay
  - Saves a photo with the overlay on the device
- **Task unlock requirement**
  - Must complete N selected tasks to unlock early
  - Task picker during session start
  - Task completion UI in session card
  - Active session task unlock configuration
  - Task unlock picker sheet for selecting required tasks

### 5.7 Integration with Today
- **Auto-navigate to Today** on session start
- **Auto-enable Focus mode** for Today
- **Auto-select focus task** (first incomplete Must-Win)
- **Optional: Auto-start 25-minute timebox** (configurable)
- **Snackbar confirmation** ("Dumb Phone Mode started — Focus is on")

### 5.8 Session History
- View past focus sessions
- Session duration and outcomes

### 5.9 Active Session Sync
- **Cross-device session sync** via `focus_active_sessions` table
- Sync active Dumb Phone Mode session across devices (e.g., iPhone → macOS)
- Real-time session state (started_at, planned_end_at, emergency_unlocks_used)
- Platform metadata (source_platform) for debugging
- Automatic cleanup when session ends

### 5.10 "W" Celebration
- Random chance to trigger W-drop animation on session completion
- Particle rain effect
- Celebrates completing focus sessions

---

## 6. AI Assistant

### 6.1 Text Input
- Text field in Assistant section on Today
- "Run" button to execute commands
- Shows response message from assistant
- Command history/tips displayed

### 6.2 Voice Input
- **Push-to-talk** microphone button
- **Tap-to-toggle** or **press-and-hold** interaction
- **Live transcript** in text field
- **Mic level visualization** (animated waveform)
- **Auto-run on speech end** (VAD-based)
- **Platform speech recognition** (on-device)
- Permission handling for microphone access

### 6.3 Command Execution
- **Allowlisted command set** (security by design)
- **Sequential execution** with confirmations
- **Preview sheet** before destructive/multi-action commands

### 6.4 Supported Commands
- **Date commands**:
  - `date.shift { days }` (relative: "tomorrow", "yesterday")
  - `date.set { ymd }` (absolute date)
- **Task commands**:
  - `task.create { title, taskType? }` ("add must win: X")
  - `task.setCompleted { title, completed }` ("complete task X")
  - `task.delete { title }` (with confirmation)
  - `task.setStarterStep { title, starterStep }`
  - `task.setEstimate { title, minutes }`
- **Habit commands**:
  - `habit.create { name }` ("add habit: X")
  - `habit.setCompleted { name, completed }` ("complete habit X")
- **Reflection commands**:
  - `reflection.append { text }` ("note: X")
  - `reflection.set { text }` (replace entire note)
- **Focus commands** (planned):
  - `focus.start { title?, minutes? }`
  - `focus.stop {}`

### 6.5 Assistant Backend
- **Heuristic fallback** (regex-based, no API key required)
- **LLM-backed translator** (OpenAI when configured)
- **Safety**: Server only translates; client executes via trusted code paths
- **Rate limiting** and cost caps

### 6.6 Text-to-Speech (Optional)
- Read back assistant responses
- Speak execution summaries
- Respects device mute settings

---

## 7. Rollups (Analytics)

### 7.1 Range Selection
- **Segmented control**: Week / Month / Year
- Automatic date range calculation

### 7.2 Summary Card
- **Average percentage** for the period
- **Delta vs previous period** (+X% / -X% / ±0)
- **Date range label** (e.g., "Jan 6 – Jan 12")
- Color-coded delta (positive = primary, negative = error)

### 7.3 Bar Chart
- **Week/Month view**: one bar per day
- **Year view**: monthly averages
- Bar height represents daily score percentage
- Responsive layout

### 7.4 Daily Breakdown List
- Per-day details:
  - Date (friendly format)
  - Must-Wins: X/Y
  - Nice-to-Dos: X/Y
  - Habits: X/Y
  - Overall percentage
- Empty state for days with no activity

---

## 8. Projects (Planned/MVP)

### 8.1 Vision
- Cross-device workspace for planning and brainstorming
- Connected to execution (days + tasks)
- Synced via Supabase

### 8.2 Planned Features
- **Fast inbox** for notes (zero friction capture)
- **Project notes** with structure: goal, status, next actions, resources
- **Daily scratchpad** (auto-created each day)
- **Linking** between notes ⇄ tasks ⇄ dates
- **Search + filters**: recent, pinned, active

### 8.3 Secret Notes (Current)
- **Markdown editor** with edit/preview modes
- **Obsidian-style wiki links** (`[[Note]]` syntax)
- **Multiple notes support** (create new notes on demand)
- **Auto-save with debouncing** (saves 550ms after typing stops)
- **Formatting toolbar**:
  - Bold, italic, inline code, code blocks
  - Headings (H1, H2)
  - Checkboxes, wiki links, markdown links
- **Navigation via wiki links** (tap links in preview to navigate)
- **Seed content** from `assets/secret_notes.md` for main note
- **Local storage** per note (SharedPreferences)
- **Privacy-focused access pattern** (hidden entry via long-press)

---

## 9. All Tasks View

### 9.1 Query Capabilities
- View tasks across all dates
- Filter by type (Must-Win / Nice-to-Do)
- Filter by completion status
- Sort by date

### 9.2 Task Actions
- Open task details
- Toggle completion
- Navigate to task's date

---

## 10. Admin Dashboard

### 10.1 Access Control
- **Admin-only access** (enforced via RLS policies)
- `is_admin()` database function for privilege checking
- Admin status provider for UI gating
- Access denied message for non-admins

### 10.2 User Management
- **User list view**:
  - All users with email, signup date, admin status
  - Search by email (partial match)
  - Sort by signup date (newest/oldest)
  - Admin badge indicator
  - Expandable details (account info, admin audit trail)
- **Grant admin access**:
  - Action button for non-admin users
  - Confirmation dialog
  - Tracks who granted access (`created_by`)
  - Success feedback
- **Revoke admin access**:
  - Action button for admin users
  - Warning confirmation dialog
  - Self-revocation prevention (cannot revoke own access)
  - Success feedback
- **Admin audit trail**:
  - Shows when admin access was granted
  - Shows who granted access (email or user ID)
  - Historical data preserved

### 10.3 Feedback Triage
- **View all user feedback** (bugs and improvements)
- **Grouped by kind** (Bug Reports, Improvement Ideas)
- **Expandable cards** with full details:
  - Description, details, entry point
  - Context (JSON formatted)
  - User ID and feedback ID
  - Creation timestamp
- **Empty state** when no feedback exists

## 11. Settings

### 11.1 Account Section
- Display user email
- Log out functionality (with confirmation)

### 11.2 Trackers Section
- Link to Custom Trackers editor
- Create/edit/delete tracker categories
- Configure tracker items and targets

### 11.3 Integrations

#### 11.3.1 Linear Integration
- **Personal API key** storage (secure)
- **Issue detection** in task notes (auto-parses `ABC-123` identifiers)
- **Issue preview card** in Task Details:
  - Title, description, state, assignee
  - Team states for status updates
  - Direct link to Linear
- **Refresh** issue data on demand

### 11.4 Dumb Phone Mode Settings
- **Auto-start 25-minute timebox** toggle
- **Require NFC card to end early** toggle
- **Require clown camera check to end early** toggle
- **NFC card pairing** (pair/unpair/replace)

### 11.5 Appearance

#### 11.5.1 Mode
- System / Light / Dark (segmented control)

#### 11.5.2 Theme Palette
- **Slate** (blue-gray)
- **Forest** (green)
- **Sunset** (orange)
- **Grape** (purple)
- Color swatch picker with selection indicator

#### 11.5.3 Layout Options
- **Full-width layout** toggle (reduces horizontal padding)
- **One-hand mode** toggle (adds reachability gutter)
- **Hand selection** (Left / Right) for one-hand mode

### 11.6 Support Section
- **About / Pitch page** link
- **Send feedback** (bug reports, feature suggestions)

### 11.7 Demo Mode Section
- Reset demo data controls (when in demo mode)

---

## 12. Command Palette & Quick Capture

### 12.1 Command Palette
- **Keyboard-driven interface** (⌘K / Ctrl+K)
- **Searchable commands** with fuzzy matching
- **Command categories**:
  - Navigation (Go to Today, Focus, Rollups, Projects, Tasks, Settings)
  - Actions (New Task, New Must-Win)
- **Keyboard navigation**:
  - Arrow keys to navigate
  - Enter to execute
  - Escape to close
- **Shortcut hints** displayed for each command
- **Grouped by category** for easy scanning
- **Empty state** when no matches found

### 12.2 Quick Capture
- **Global quick capture dialog** (⌥N / Alt+N)
- **Smart input parsing**:
  - `!task` → Must-Win task
  - `#habit` → Habit
  - `note:` → Reflection note
  - `tomorrow` → Schedule for tomorrow
  - `/focus 25` → Start 25-minute focus timer
- **Real-time type inference** with visual indicator
- **Date inference** (today, tomorrow)
- **Auto-focus** on open
- **Keyboard shortcuts** (Enter to submit, Escape to cancel)
- **Visual feedback** for inferred type and date

## 13. UI/UX Features

### 13.1 Design System
- **Material 3** foundation
- **Custom theme** with 4 color palettes
- **Consistent spacing scale** (`AppSpace`, `Gap`)
- **AppScaffold** for standardized screen layout
- Max width constraints for large screens
- Card-based content organization

### 13.2 Components Library
- Section headers
- Empty state cards (icon + title + description + CTA)
- Info banners
- Task lists with overflow menus
- NFC scan sheet
- Clown cam gate sheet
- Linear issue card
- Conversation border (animated ring for voice input)
- W-drop celebration overlay
- Hold-to-confirm button
- Reachability FAB cluster
- Command palette dialog
- Quick capture dialog
- Task unlock picker sheet

### 13.3 Accessibility
- Touch targets ≥ 44px
- Good contrast ratios
- Semantic labels for screen readers
- Focus traversal order
- Large text support
- Non-gesture fallbacks for all interactions

### 13.4 Feedback (Non-Audio)
- **Task complete** (visual state change + optional snackbar)
- **Big win** (W-drop celebration overlay)
- **Voice input**: mic level visualization (animated ring/waveform)
- **Errors**: inline error copy + snackbar where appropriate

### 13.5 Navigation
- **Bottom nav shell** with tabs: Today, Focus, Rollups, Settings
- **GoRouter** for declarative routing
- **Deep linking** support
- **Smooth transitions** between screens

### 13.6 Responsive Design
- Mobile-first layout
- Adaptive padding for larger screens
- Max content width for readability
- One-hand mode for thumb reachability

---

## 14. Keyboard Shortcuts

### 14.1 System
- **Platform-aware** (⌘ on macOS, Ctrl on Windows/Linux)
- **Centralized definitions** in `AppShortcuts` class
- **Intent-based architecture** (separates "what" from "how")

### 14.2 Navigation Shortcuts
- **⌘1 / Ctrl+1**: Go to Today
- **⌘2 / Ctrl+2**: Go to Focus
- **⌘3 / Ctrl+3**: Go to Rollups
- **⌘4 / Ctrl+4**: Go to Projects
- **⌘5 / Ctrl+5**: Go to Settings
- **⌘, / Ctrl+,**: Go to Settings (alternative)
- **⌘← / Ctrl+←**: Previous day
- **⌘→ / Ctrl+→**: Next day
- **⌘T / Ctrl+T**: Jump to today

### 14.3 Action Shortcuts
- **⌘K / Ctrl+K**: Open command palette
- **⌘N / Ctrl+N**: New task
- **⌘⇧N / Ctrl+Shift+N**: New Must-Win
- **⌘⏎ / Ctrl+Enter**: Toggle focus task completion
- **⌘⇧F / Ctrl+Shift+F**: Toggle focus mode
- **⌘⇧S / Ctrl+Shift+S**: "I'm stuck" menu
- **⌘F / Ctrl+F**: Focus search field
- **⌥N / Alt+N**: Open quick capture

## 15. Platform-Specific Features

### 15.1 iOS
- Screen Time API integration
- Family Controls framework
- NFC reading support
- Speech recognition (Apple Speech framework)

### 15.2 Android
- Accessibility Service for app blocking
- Device Admin API
- Usage Stats API
- NFC reading support
- Speech recognition (Android SpeechRecognizer)

### 15.3 macOS
- Desktop layout adaptations
- **Dock badge** showing incomplete Must-Win count
- **Auto-updating badge** when tasks change
- **Keyboard shortcuts** (full support)
- Menu bar (potential)

### 15.4 Web
- Progressive web app capable
- Fallback for missing native features
- Responsive desktop experience

---

## 16. Data & Sync

### 16.1 Backend
- **Supabase** (PostgreSQL + Auth)
- **Row Level Security** (RLS) policies
- User-scoped data isolation

### 16.2 Data Models
- `tasks` (id, user_id, title, type, date, completed, notes, estimate, actual, next_step, goal_ymd, in_progress)
- `habits` (id, user_id, name)
- `habit_completions` (id, habit_id, date, completed)
- `daily_reflections` (id, user_id, date, note)
- `task_subtasks` (id, task_id, title, completed, sort_order)
- `focus_policies` (id, user_id, name, allowed_apps, friction_settings)
- `focus_sessions` (id, user_id, policy_id, started_at, planned_end_at, actual_end_at, friction)
- `focus_active_sessions` (user_id, session_id, policy_id, started_at, planned_end_at, emergency_unlocks_used, source_platform, updated_at)
- `trackers` (id, user_id, name, items)
- `tracker_tallies` (id, tracker_id, item_key, date, count)
- `scoring_settings` (user_id, categories with weights)
- `admin_users` (user_id, created_at, created_by)
- `user_feedback` (id, user_id, kind, description, details, entry_point, context, created_at)

### 16.3 Local Storage
- **SharedPreferences** for demo mode
- **JSON serialization** for offline data
- **Theme and settings** persistence
- **Dashboard layout** order storage

---

## 17. Security & Privacy

### 17.1 Authentication
- Secure session management via Supabase Auth
- Token refresh handling
- Logout clears local state

### 17.2 Data Protection
- RLS policies ensure data isolation
- API keys stored securely
- NFC card hashes (not raw data)
- Clown camera photos are stored locally on device

### 17.3 Assistant Safety
- Allowlisted commands only
- Server-side rate limiting
- Cost caps on LLM usage
- Input validation and sanitization
- CSRF protection via origin allowlist

---

### 17.4 Admin Security
- **Row Level Security (RLS)** policies for admin operations
- **Admin-only functions** (`is_admin()`, `admin_list_users()`)
- **Audit trail** for privilege changes
- **Self-revocation prevention**
- **Access control** at UI and database levels

## 18. Notifications (Planned)

### 18.1 Potential Features
- Focus session end reminders
- Timebox completion alerts
- Daily planning prompts
- Habit reminders

---

## 19. Onboarding

### 19.1 Restriction Permissions
- Guided permission request flow
- Platform-specific setup instructions
- iOS Screen Time setup guide
- Android accessibility service setup

### 19.2 Dumb Phone Onboarding
- Feature explanation
- Policy creation guidance
- First session walkthrough

---

## 20. Developer/Debug Features

### 20.1 Debug Mode
- W-celebration test button
- Verbose logging
- Demo data reset

### 20.2 Error Handling
- User-friendly error messages
- Retry mechanisms
- Graceful degradation
- Error reporting via feedback system

---

## Summary Statistics

- **Major Feature Categories**: 20
- **Screen Types**: ~18+
- **UI Components**: 25+
- **Theme Palettes**: 4
- **Supported Platforms**: 5 (iOS, Android, macOS, Linux, Web)
- **Assistant Commands**: 10+ types
- **Data Tables**: 12+
- **Keyboard Shortcuts**: 15+

This app is designed as a comprehensive daily execution system with a strong focus on ADHD-friendly patterns, distraction blocking, and seamless task-to-action workflows.
