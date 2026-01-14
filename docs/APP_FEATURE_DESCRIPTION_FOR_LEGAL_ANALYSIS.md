# Win the Year — App Feature Description for Legal Analysis

**Prepared for:** Patent/IP analysis by legal counsel or AI analysis tools  
**App Name:** Win the Year  
**Platform:** iOS, Android, macOS, Web (Flutter cross-platform)  
**Backend:** Supabase (PostgreSQL + Edge Functions)  
**Date:** January 2026

---

## Executive Summary

Win the Year is a daily execution and productivity application designed to help users complete important tasks each day. The app combines task management, habit tracking, journaling, focus assistance, and optional app-blocking features. It includes an AI-powered assistant that translates natural language input into structured commands executed by the app.

---

## Feature Category 1: Task Management

### 1.1 Daily Task Lists
- Users create tasks assigned to specific calendar dates
- Tasks are categorized into two priority tiers:
  - **"Must-Win"** tasks (high priority, critical for the day)
  - **"Nice-to-Do"** tasks (lower priority, optional)
- Each task has: title, type (must-win or nice-to-do), date, completion status
- Users can create, edit, delete, and mark tasks as complete/incomplete
- Tasks are displayed in list format grouped by priority tier

### 1.2 Task Attributes (Extended)
- **Starter Step:** Optional short text describing the first micro-action to begin a task (e.g., "Open laptop and write title line")
- **Estimated Minutes:** Optional integer for time estimation
- Tasks are referenced by title (not ID) in voice/natural language interfaces

### 1.3 Data Storage
- Stored in PostgreSQL database via Supabase with row-level security
- Local storage option (SharedPreferences) for demo/offline mode

---

## Feature Category 2: Habit Tracking

### 2.1 Habit Management
- Users create recurring habits (global list, not date-specific)
- Each habit has: name, creation timestamp
- Habits persist across all dates (unlike tasks which are date-specific)

### 2.2 Daily Habit Completion
- Users mark habits as complete or incomplete for each specific date
- Completion state is stored per habit per date (habit_id + date = unique record)
- Habits contribute to daily scoring calculations

---

## Feature Category 3: Daily Reflection / Journaling

### 3.1 Reflection Notes
- Users can write a free-text reflection note for each date
- One reflection entry per user per date
- Auto-save on blur (when user leaves the text field)
- Manual save option available

### 3.2 Reflection Manipulation
- Reflection can be set (replaced entirely) or appended to (added to existing text)
- Accessible via manual text entry and voice/AI assistant commands

---

## Feature Category 4: Daily Scoring System

### 4.1 Score Calculation
- Daily score (0-100%) computed from three weighted categories:
  - Must-Win tasks (default weight: 50%)
  - Nice-to-Do tasks (default weight: 20%)
  - Habits (default weight: 30%)

### 4.2 Calculation Method
- Group completion = completed items / total items in group
- If a group has zero items, it is excluded from calculation (no penalty)
- Final score = Σ(weight × completion) / Σ(weights of non-empty groups) × 100

### 4.3 Score Labels
- Excellent: ≥90%
- Good: ≥70%
- Fair: ≥50%
- Needs Improvement: <50%

### 4.4 Coach Messages
- Contextual motivational messages based on score and time of day
- Example: "Today is still winnable" (morning/evening when score < 100%)

---

## Feature Category 5: Focus Mode ("One Thing Now")

### 5.1 Focus Mode Concept
- User interface mode that highlights a single "focus task" from the Must-Win list
- Designed to reduce decision paralysis and aid task initiation
- Focus task remains stable across navigation and app restarts for the day

### 5.2 Focus Task Selection
- If user has previously selected a focus task, it persists
- Otherwise, automatically selects the first incomplete Must-Win task
- User can manually switch focus task or exit focus mode

### 5.3 Focus Mode UI Elements
- "Start (2 min)" button — encourages micro-commitment to begin
- Quick timebox presets: 10, 15, 25, 45 minutes
- "I'm stuck" rescue button (see Section 5.5)
- Display of focus task title and starter step (if set)

### 5.4 Timebox Timer
- Local countdown timer for focus sessions
- Shows remaining time during active timebox
- Controls: +5 minutes, End early, Switch task
- "Wrap up soon" indicator at 2 minutes remaining
- Timer state persists while app is open

### 5.5 "I'm Stuck" Rescue Flow
- Three quick options when user feels blocked:
  1. **Make it smaller:** Prompt to add a 2-minute starter step
  2. **Switch focus:** Choose a different Must-Win task
  3. **Take a break:** Start a short break timer (default 5 min), then return

---

## Feature Category 6: App Restriction / "Dumb Phone Mode"

### 6.1 Overview
- Feature that restricts access to distracting apps on the user's device
- User initiates a "session" with a specified duration
- During active session, selected apps are blocked or require friction to access

### 6.2 Platform Implementation — iOS
- Uses Apple Screen Time frameworks:
  - **FamilyControls** — authorization and family sharing
  - **ManagedSettings** — app restrictions and shields
  - **DeviceActivity** — monitoring device usage
- User grants Screen Time authorization
- App stores restriction selection in App Group UserDefaults
- Requires proper Apple Developer entitlements

### 6.3 Platform Implementation — Android
- Uses **AccessibilityService** to monitor foreground app changes
- When a blocked app comes to foreground, displays a blocking overlay
- Session configuration stored in SharedPreferences:
  - Allowed apps list (JSON)
  - Friction settings (JSON)
  - Emergency unlock timestamp
  - Card-required flag
- Blocking overlay provides options based on friction settings

### 6.4 Session Configuration
- **Allowed Apps:** Whitelist of apps that remain accessible during session
- **Blocked Apps:** Apps that trigger the blocking overlay
- **Duration:** User-selected session length
- **Friction Settings:** Configurable difficulty to bypass (e.g., wait timer, typing challenge)

### 6.5 Bypass Mechanisms
- **Emergency Unlock:** Temporary bypass window for urgent access
- **NFC Card Requirement:** Optional setting requiring physical NFC tag scan to end session early
- **Session End:** Normal termination when duration expires

### 6.6 Integration with Focus Mode
- Starting Dumb Phone Mode automatically:
  1. Navigates user to the Today screen
  2. Enables Focus Mode
  3. Auto-selects a focus task (first incomplete Must-Win)
- Optional setting: auto-start 25-minute timebox when Dumb Phone starts

---

## Feature Category 7: NFC Card Pairing

### 7.1 Purpose
- Physical NFC tag can be paired to the app
- Used as a friction mechanism for ending focus/restriction sessions early
- Requires user to physically access their NFC tag to bypass restrictions

### 7.2 Technical Implementation
- Reads NFC tag via platform NFC APIs
- Extracts either NDEF content or tag UID bytes
- Stores a **SHA-256 hash** of the tag data (not raw content)
- Hash stored in Flutter Secure Storage (platform keychain)
- Minimum 16 bytes of entropy required for pairing

### 7.3 Verification
- To end a session early (when card-required is enabled), user must scan the paired NFC tag
- App computes hash of scanned tag and compares to stored hash
- Match allows session termination; mismatch blocks termination

---

## Feature Category 8: AI Assistant

### 8.1 Architecture Overview
- **Translator model:** User input (text or voice transcript) is sent to a server that returns structured commands
- **Deterministic execution:** Client app executes commands via existing code paths (not autonomous agent behavior)
- **Allowlisted commands only:** Server only returns predefined command types; unknown commands rejected

### 8.2 Input Methods
- **Text input:** User types commands in assistant text field
- **Voice input:** Push-to-talk microphone captures speech, converted to text via on-device speech recognition (iOS Speech framework / Android SpeechRecognizer), then processed as text

### 8.3 Translation Layer
- **Remote translation:** Supabase Edge Function calls OpenAI API (when configured) with constrained prompt
- **Local fallback:** Heuristic/regex-based parsing when OpenAI not configured
- Both methods return the same structured command format

### 8.4 Supported Command Types (v1)
```
- date.shift { days: number }           — Move selected date forward/back
- date.set { ymd: string }              — Set selected date to specific date
- task.create { title, taskType? }      — Create new task
- task.setCompleted { title, completed } — Mark task complete/incomplete
- task.delete { title }                 — Delete task (requires confirmation)
- habit.create { name }                 — Create new habit
- habit.setCompleted { name, completed } — Mark habit complete for date
- reflection.append { text }            — Add text to reflection
- reflection.set { text }               — Replace reflection text
```

### 8.5 Extended Commands (planned/implemented)
```
- task.setStarterStep { title, starterStep } — Set micro-action for task
- task.setEstimate { title, minutes }        — Set time estimate
- focus.start { title?, minutes? }           — Start focus mode/timer
- focus.stop {}                              — End focus mode
```

### 8.6 Safety Controls
- **Authentication required:** All assistant calls require valid user session
- **Rate limiting:** Per-user requests per minute (default 20 RPM)
- **Input limits:** Maximum transcript length (default 2000 chars)
- **Output validation:** Unknown command types are rejected
- **Confirmation required:** Destructive actions (delete) and multi-action sequences require user confirmation
- **Origin allowlist:** Optional CORS-style protection for web deployments

### 8.7 Voice-Specific Features
- Microphone permission requested only on user action
- Transcript displayed and editable before execution
- Optional text-to-speech readback of confirmations
- Graceful fallback to typed input if speech unavailable

---

## Feature Category 9: Analytics and Rollups

### 9.1 Historical View
- View past performance by week, month, or year
- Average score for selected period
- Comparison to previous period (delta percentage)

### 9.2 Visualization
- Bar chart showing daily scores
- Weekly/monthly view: one bar per day
- Yearly view: monthly averages
- Daily breakdown list

---

## Feature Category 10: User Settings

### 10.1 Theme Customization
- Theme mode: System default, Light, Dark
- Color palette options: Slate, Forest, Sunset, Grape
- Persisted locally on device

### 10.2 Account
- Display user email
- Logout functionality

### 10.3 Focus/Assistant Settings (planned)
- Voice input on/off
- Spoken confirmations on/off
- Auto-timebox on Dumb Phone start

---

## Technical Architecture Summary

### Client (Flutter)
- Cross-platform: iOS, Android, macOS, Web, Windows, Linux
- State management via Riverpod providers
- Navigation via go_router
- Local persistence via SharedPreferences (non-sensitive) and Flutter Secure Storage (sensitive)
- Platform channels for native features (Screen Time, Accessibility, NFC)

### Backend (Supabase)
- PostgreSQL database with Row Level Security (RLS)
- Supabase Auth for authentication (email/password, magic link)
- Supabase Edge Functions for AI assistant translation
- All user data scoped to authenticated user via RLS policies

### Third-Party Services
- **OpenAI API** (optional): Used server-side only for natural language translation
- **Platform Speech APIs**: On-device speech-to-text (not cloud)

---

## What This App Does NOT Do

For clarity in legal analysis, the app explicitly does NOT:

1. **Make medical claims** — Not a medical device, does not diagnose or treat ADHD or any condition
2. **Provide autonomous AI agents** — AI only translates; all execution is deterministic client code
3. **Access other users' data** — All data scoped to authenticated user via database policies
4. **Run background surveillance** — No always-on listening, no background tracking beyond active restriction sessions
5. **Bypass OS security** — Uses official platform APIs (Screen Time, Accessibility Service) as intended
6. **Store biometric data** — NFC uses tag data hash only, no fingerprint/face data
7. **Require cloud for core features** — Can run in demo mode with local-only storage

---

## Summary of Key Technical Mechanisms

| Feature | Technical Approach |
|---------|-------------------|
| Task/Habit storage | PostgreSQL + RLS (Supabase) or SharedPreferences (local) |
| Daily scoring | Client-side weighted average calculation |
| Focus mode | UI state management (Riverpod), persisted per-day locally |
| Timebox timer | Local countdown timer, client-side only |
| App blocking (iOS) | Apple Screen Time APIs (FamilyControls, ManagedSettings) |
| App blocking (Android) | AccessibilityService monitoring + blocking overlay |
| NFC verification | SHA-256 hash comparison of tag data |
| AI translation | OpenAI API via Supabase Edge Function OR local heuristics |
| Voice input | Platform speech recognition APIs (on-device) |
| Authentication | Supabase Auth (JWT-based) |

---

## Document Version

- **Version:** 1.0
- **Generated:** January 2026
- **Source:** winFlutter repository documentation and codebase analysis

---

*This document is intended for legal review purposes. It describes implemented and planned features based on product requirements documents and source code analysis.*
