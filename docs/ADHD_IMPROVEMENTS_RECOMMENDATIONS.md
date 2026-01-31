# ADHD Improvements Recommendations

**Document version**: 2026-01-16  
**Purpose**: Comprehensive recommendations to make Win the Year more useful for people with ADHD, based on current implementation, planned features, and research-backed best practices.

---

## Executive Summary

Win the Year already has a strong ADHD-friendly foundation with focus mode, starter steps, timeboxing, and distraction blocking. This document proposes additional improvements organized by impact and implementation effort, drawing from:

- Current app features (see `COMPREHENSIVE_FEATURE_LIST.md`)
- Planned ADHD features (see `ADHD_EXECUTION_PRD.md`)
- Research-backed best practices for ADHD productivity tools (2025-2026)

---

## What's Already Great for ADHD Users

### ✅ Currently Implemented
1. **Focus Mode Action Lane** - Single obvious next action, reduces choice paralysis
2. **Starter Steps** - "Next 2 minutes" micro-commitments for task initiation
3. **Timebox Timer** - Visible time with 2/10/15/25/45 minute options
4. **"I'm Stuck" Rescue Flow** - Gentle recovery without shame (Make it smaller / Switch focus / Take a break)
5. **Dumb Phone Mode** - Distraction blocking with auto-focus integration
6. **Must-Win vs Nice-to-Do** - Reduces overwhelm by limiting critical tasks
7. **Daily Score** - Immediate feedback on progress
8. **Voice Assistant** - Reduces friction for task capture
9. **Brain Dump → Reflection** - Externalizes working memory

### ✅ Planned (from ADHD_EXECUTION_PRD.md)
- Brain dump → triage flow (F6)
- Gentle rewards without streak shame (F7)
- Routine templates (F8)
- Body doubling (F9)

---

## High-Impact Improvements (Prioritized)

### 1. Enhanced Time Visibility & Time Blindness Support

**Problem**: ADHD users struggle with time estimation and awareness. Current timer is good but could be more prominent and contextual.

**Recommendations**:

#### 1.1 Lock Screen / Widget Timer Display
- **Impact**: HIGH - Externalizes time awareness without opening app
- **Effort**: MEDIUM
- **Implementation**:
  - iOS: Live Activities / Dynamic Island integration
  - Android: Persistent notification with timer
  - Desktop: Menu bar timer (macOS already has dock badge)
- **Research basis**: Visual time made literal (countdowns, progress rings) is core to ADHD tools like Tiimo

#### 1.2 Visual Progress Indicators
- **Impact**: HIGH - Makes abstract time concrete
- **Effort**: LOW
- **Implementation**:
  - Circular progress ring around timer (not just numbers)
  - Visual "time remaining" bar that shrinks
  - Color transitions (green → yellow → red as time runs out)
- **Research basis**: ADHD users benefit from visual representations of time

#### 1.3 Transition Cues & Warnings
- **Impact**: MEDIUM - Helps with time blindness
- **Effort**: LOW
- **Implementation**:
  - Expand beyond 2-minute warning
  - Add 5-minute "halfway" cue
  - Gentle vibration/haptic at transition points (optional, behind setting)
  - "Wrap up" checklist suggestion when timer ends
- **Research basis**: Transition scaffolds (5-10 min wrap-up cues) help ADHD users

#### 1.4 Time Estimation Calibration
- **Impact**: MEDIUM - Helps users learn realistic time estimates
- **Effort**: MEDIUM
- **Implementation**:
  - Track estimated vs actual time for tasks
  - Show "You estimated 15 min, took 23 min" feedback
  - Suggest better estimates based on history
  - Optional: "Time coaching" insights ("You tend to underestimate by 30%")
- **Research basis**: ADHD users consistently underestimate time; calibration helps

---

### 2. Event-Based & Context-Aware Reminders

**Problem**: Time-based reminders fail for ADHD users. Event-based triggers (after lunch, when I arrive home) work better.

**Recommendations**:

#### 2.1 Location-Based Task Triggers
- **Impact**: HIGH - Addresses time-based prospective memory weakness
- **Effort**: HIGH (requires location permissions)
- **Implementation**:
  - "Remind me to [task] when I arrive at [location]"
  - "Remind me to [task] after [event]" (e.g., "after coffee", "after lunch")
  - Integration with calendar events
- **Research basis**: Event-anchored reminders outperform time-based for ADHD (prospective memory research)

#### 2.2 Activity-Based Triggers
- **Impact**: MEDIUM - Lower friction than location
- **Effort**: MEDIUM
- **Implementation**:
  - "When I open [app]" triggers
  - "After completing [habit]" triggers
  - "At start of focus session" triggers
- **Research basis**: Event-based > time-based for ADHD

#### 2.3 Smart Default Templates
- **Impact**: MEDIUM - Reduces decision fatigue
- **Effort**: LOW
- **Implementation**:
  - Pre-built templates: "After coffee", "When I sit at desk", "After lunch"
  - User can create custom event triggers
- **Research basis**: Templates reduce cognitive load

---

### 3. Just-In-Time Adaptive Interventions (JITAI)

**Problem**: Notifications often arrive at wrong times or feel overwhelming. ADHD users need personalized, well-timed prompts.

**Recommendations**:

#### 3.1 Adaptive Notification Timing
- **Impact**: HIGH - Increases receptivity to prompts
- **Effort**: HIGH (requires ML/pattern detection)
- **Implementation**:
  - Learn user's active hours and routine patterns
  - Adjust notification timing based on when user typically engages
  - "Pre-event" timing (notify shortly before likely behavior)
  - Respect "quiet hours" automatically
- **Research basis**: JITAI research shows personalized timing dramatically improves adherence

#### 3.2 Explain the "Why" of Prompts
- **Impact**: MEDIUM - Increases trust and receptivity
- **Effort**: LOW
- **Implementation**:
  - Notifications include brief rationale: "You set 3 Must-Wins today. 2 are done. Time to tackle the last one?"
  - "You usually start focus sessions at 9am. Ready to begin?"
- **Research basis**: Human-AI loops with explanations increase trust and accuracy

#### 3.3 Graded Prompts (Start Small)
- **Impact**: MEDIUM - Reduces overwhelm
- **Effort**: LOW
- **Implementation**:
  - Morning: "What's your one Must-Win today?" (not "plan your whole day")
  - Afternoon: "How's that Must-Win going?" (not "complete everything")
  - Evening: "Quick reflection: what helped today?"
- **Research basis**: Graded, actionable prompts improve engagement

---

### 4. Cognitive Accessibility Enhancements

**Problem**: Some ADHD users also have dyslexia, processing differences, or need reduced cognitive load.

**Recommendations**:

#### 4.1 Dyslexia-Friendly Font Option
- **Impact**: MEDIUM - Helps users with reading difficulties
- **Effort**: LOW
- **Implementation**:
  - Add font option in Settings (e.g., OpenDyslexic, Comic Sans, or system accessibility font)
  - Respect system accessibility font size settings
- **Research basis**: Tiimo and other ADHD apps highlight dyslexia-friendly fonts

#### 4.2 Multiple Representation Modes
- **Impact**: MEDIUM - Different users process differently
- **Effort**: MEDIUM
- **Implementation**:
  - List view (current)
  - Timeline view (visual schedule)
  - Card view (larger, more spaced)
  - Color/emoji labeling options
- **Research basis**: Multiple representations help different cognitive styles

#### 4.3 Reduced Animation / Motion Controls
- **Impact**: LOW-MEDIUM - Some ADHD users are sensitive to motion
- **Effort**: LOW
- **Implementation**:
  - Respect system "Reduce Motion" setting
  - Option to disable celebratory animations (W-drop, etc.)
  - Calm, minimal animations by default
- **Research basis**: WCAG cognitive accessibility guidelines

#### 4.4 Extra Time to Act
- **Impact**: MEDIUM - Reduces pressure and errors
- **Effort**: LOW
- **Implementation**:
  - Longer auto-save delays (current is good)
  - "Undo" for more actions (delete task, complete task, etc.)
  - Confirmation dialogs with "Are you sure?" for destructive actions
- **Research basis**: WCAG cognitive accessibility - extra time to act

---

### 5. Routine & Transition Support

**Problem**: ADHD users struggle with transitions and routine maintenance. Current app has habits but could better support routines.

**Recommendations**:

#### 5.1 Routine Templates with Auto-Generation
- **Impact**: HIGH - Reduces decision fatigue
- **Effort**: MEDIUM
- **Implementation**:
  - "Morning Routine" template → auto-creates Must-Wins/habits for today
  - "Work Routine" template → sets up focus session + tasks
  - User-defined templates
  - One-tap "Apply routine" button
- **Research basis**: Templates reduce decision fatigue (already in PRD as F8)

#### 5.2 Transition Checklists
- **Impact**: MEDIUM - Helps with context switching
- **Effort**: LOW
- **Implementation**:
  - When timer ends: "Wrap up checklist"
    - "Save your work"
    - "Note where you left off"
    - "Set next session focus"
  - When switching tasks: "Context save" prompt
- **Research basis**: Transition scaffolds (5-10 min wrap-up cues) help ADHD users

#### 5.3 Routine Insights
- **Impact**: MEDIUM - Helps users understand what works
- **Effort**: MEDIUM
- **Implementation**:
  - "You complete more Must-Wins on days you start before 9am"
  - "Your best focus sessions are 25 minutes, not 45"
  - "You tend to skip habits on weekends - that's okay"
- **Research basis**: Mood/reflection check-ins that feed planning (Tiimo 2025 updates)

---

### 6. Motivation & Engagement Without Shame

**Problem**: Streaks and perfectionism can backfire for ADHD users, leading to avoidance after missing a day.

**Recommendations**:

#### 6.1 Gentle Streak System (Already Planned)
- **Impact**: HIGH - Prevents shame spirals
- **Effort**: MEDIUM
- **Implementation**:
  - "Streak freeze" / grace days
  - "Comeback wins" (celebrate returning after 0% day)
  - "Wins this week" instead of "perfect streak"
  - No red/X marks for missed days - just neutral
- **Research basis**: Already in PRD (F7). Avoid over-frequent, mistimed nudges.

#### 6.2 Micro-Celebrations
- **Impact**: MEDIUM - Immediate positive feedback
- **Effort**: LOW
- **Implementation**:
  - Subtle haptic on task completion
  - "Nice!" or "Got it!" micro-messages
  - W-drop celebration (already exists) - keep it fun, not pressure
- **Research basis**: Immediate feedback / light rewards help motivation

#### 6.3 "What Helped Today?" Reflection Prompts
- **Impact**: MEDIUM - Builds self-awareness
- **Effort**: LOW
- **Implementation**:
  - Evening prompt: "What helped you focus today?"
  - Store answers, show patterns: "You mentioned 'morning routine' 5 times this week"
  - Feed into routine suggestions
- **Research basis**: Mood-to-routine insights (Tiimo 2025)

---

### 7. Working Memory & Context Support

**Problem**: ADHD users lose context mid-task. Current notes/reflection help but could be more integrated.

**Recommendations**:

#### 7.1 Context Save on Task Switch
- **Impact**: MEDIUM - Prevents lost context
- **Effort**: LOW
- **Implementation**:
  - When switching focus task: "Quick note: where did you leave off?"
  - Auto-saves to task notes
  - Shows when returning to task: "Last time: [context note]"
- **Research basis**: Externalized working memory is core ADHD strategy

#### 7.2 Task Breakdown with Progress
- **Impact**: MEDIUM - Makes large tasks manageable
- **Effort**: MEDIUM (partially exists as subtasks)
- **Implementation**:
  - Visual progress: "3 of 5 steps done"
  - Show only next 1-2 steps (not full list)
  - "Next step" always visible in focus mode
- **Research basis**: Small, concrete next steps with short horizons

#### 7.3 "Where Was I?" Quick Recovery
- **Impact**: MEDIUM - Helps after distraction
- **Effort**: LOW
- **Implementation**:
  - App remembers last active task/focus session
  - "Resume" button on Today screen
  - Shows: "You were working on [task] for 12 minutes"
- **Research basis**: Reduces context switching cost

---

### 8. Cross-Device & Ecosystem Integration

**Problem**: ADHD users switch devices. Consistency and sync are critical.

**Recommendations**:

#### 8.1 Watch Complications / Widgets
- **Impact**: HIGH - Glanceable without context switch
- **Effort**: HIGH (platform-specific)
- **Implementation**:
  - Apple Watch: complication showing "Next: [task]" or timer
  - Android Wear: similar
  - Desktop widgets: "Focus task" always visible
- **Research basis**: Cross-device consistency and glanceable widgets keep "what's next" in view

#### 8.2 Instant Sync Across Devices
- **Impact**: HIGH - Prevents data loss anxiety
- **Effort**: MEDIUM (Supabase already supports this)
- **Implementation**:
  - Real-time sync (Supabase realtime subscriptions)
  - Conflict resolution (last-write-wins is fine for MVP)
  - "Syncing..." indicator when offline
- **Research basis**: Cross-device consistency is critical

#### 8.3 Calendar Integration
- **Impact**: MEDIUM - Reduces app switching
- **Effort**: MEDIUM
- **Implementation**:
  - Import calendar events as "Nice-to-Do" tasks
  - Export focus sessions to calendar
  - Show calendar context in Today view
- **Research basis**: Reduces context switching

---

### 9. Onboarding & Progressive Disclosure

**Problem**: Too many features at once overwhelms ADHD users. Need progressive reveal.

**Recommendations**:

#### 9.1 Minimal First-Run Experience
- **Impact**: HIGH - Reduces initial overwhelm
- **Effort**: MEDIUM
- **Implementation**:
  - Start with just Today screen + one Must-Win
  - "Add your first Must-Win" prominent CTA
  - Unlock features gradually: "Ready for habits? → Add your first habit"
  - Skip-able tutorials (not forced)
- **Research basis**: Progressive reveal - start with day view + timer

#### 9.2 Contextual Help (Not Overwhelming)
- **Impact**: MEDIUM - Reduces cognitive load
- **Effort**: LOW
- **Implementation**:
  - Tooltips on first use (dismissible)
  - "What is this?" links to brief explanations
  - No long onboarding videos
  - Help text is skimmable (bullets, not paragraphs)
- **Research basis**: Cognitive accessibility - plain language, predictable

#### 9.3 Feature Discovery
- **Impact**: LOW-MEDIUM - Helps users find value
- **Effort**: LOW
- **Implementation**:
  - "Try focus mode" prompt after 3 days of use
  - "You have 5 Must-Wins - try limiting to 3" gentle suggestion
  - "New: Starter steps help with getting started" (one-time, dismissible)
- **Research basis**: Progressive reveal as needed

---

### 10. Privacy & Trust (Critical for ADHD Users)

**Problem**: ADHD users may have sensitive tasks/reflections. Privacy concerns can prevent engagement.

**Recommendations**:

#### 10.1 Clear Privacy Controls
- **Impact**: HIGH - Builds trust
- **Effort**: LOW
- **Implementation**:
  - Privacy policy clearly linked
  - "Your data is encrypted" messaging
  - Option to use local-only mode (demo mode exists)
  - Clear data retention policies
- **Research basis**: Privacy sensitivity in mental health/productivity spaces (FTC guidance)

#### 10.2 No Ad Tech with Sensitive Data
- **Impact**: HIGH - Legal/trust requirement
- **Effort**: LOW (should already be true)
- **Implementation**:
  - Audit: no sharing health-related data with advertisers
  - Explicit consent for any third-party sharing
  - Minimize data retention
- **Research basis**: FTC actions against BetterHelp/GoodRx show the standard

#### 10.3 Transparent Billing (If Applicable)
- **Impact**: MEDIUM - Prevents trust erosion
- **Effort**: N/A (if free) or LOW (if paid)
- **Implementation**:
  - One-tap cancellation
  - No dark patterns
  - Clear pricing
- **Research basis**: Community backlash to deceptive billing erodes trust

---

## Implementation Priority Matrix

### Quick Wins (Low Effort, High Impact)
1. ✅ Visual progress indicators for timer (circular ring, color transitions)
2. ✅ Explain "why" in notifications/prompts
3. ✅ Graded prompts (start small)
4. ✅ Transition checklists when timer ends
5. ✅ "Where was I?" resume feature
6. ✅ Context save on task switch
7. ✅ Dyslexia-friendly font option
8. ✅ Reduce motion / animation controls

### High-Value Features (Medium Effort, High Impact)
1. ⭐ Lock screen / widget timer display
2. ⭐ Location/event-based reminders
3. ⭐ Adaptive notification timing (JITAI)
4. ⭐ Routine templates with auto-generation
5. ⭐ Time estimation calibration
6. ⭐ Watch complications / widgets
7. ⭐ Multiple representation modes (timeline view)

### Strategic Investments (High Effort, High Impact)
1. 🚀 Full JITAI system with ML pattern detection
2. 🚀 Calendar integration
3. 🚀 Real-time cross-device sync (Supabase realtime)
4. 🚀 Body doubling features (already planned)

---

## Research-Backed Principles to Maintain

### Core Principles (Already Strong)
- ✅ **Default to one path** - Focus mode does this
- ✅ **Small commitments** - "Start (2 min)" does this
- ✅ **Stable target** - Focus task stability does this
- ✅ **Gentle recovery** - "I'm stuck" flow does this
- ✅ **Low configuration** - Smart defaults exist

### Additional Principles to Emphasize
- **Externalize everything** - Make time, tasks, steps visible
- **Event-based > time-based** - For reminders and triggers
- **Visual > textual** - When possible, show don't tell
- **Immediate feedback** - Celebrate small wins
- **No shame** - Avoid perfectionism, streaks without grace
- **Progressive disclosure** - Don't show everything at once
- **Cognitive accessibility** - Plain language, extra time, multiple representations

---

## Metrics to Track (ADHD-Specific)

### Engagement Metrics
- **Task initiation rate**: % of days with at least one "Start (2 min)" action
- **Return-to-focus rate**: After leaving Today, how often users resume same focus task
- **Abandoned day reduction**: Fewer days with 0 completions after opening app
- **Timebox completion rate**: % of started timeboxes that complete (vs abandoned)

### Effectiveness Metrics
- **Must-Win completion rate**: Target improvement from baseline
- **Time estimation accuracy**: Track estimated vs actual over time
- **Notification receptivity**: Do users act on prompts? (A/B test timing)
- **Feature adoption**: Which ADHD features are actually used?

### Wellbeing Metrics (Optional, Privacy-Sensitive)
- **Shame/avoidance indicators**: Do users return after 0% days?
- **Overwhelm indicators**: Do users abandon after adding too many tasks?
- **Engagement without pressure**: Are users using app without feeling judged?

---

## Open Questions & Considerations

1. **Medical Claims**: Avoid therapeutic/medical language. Frame as productivity scaffolding, not treatment.
2. **Data Sensitivity**: Tasks/reflections can be very personal. Ensure encryption, clear privacy policy.
3. **Platform Limitations**: Some features (Live Activities, watch complications) are platform-specific.
4. **User Research**: Validate these recommendations with actual ADHD users before large investments.
5. **Feature Bloat Risk**: ADHD apps can overwhelm with options. Maintain "one primary CTA" principle.

---

## Next Steps

1. **Review & Prioritize**: Team review of this document, select top 3-5 improvements
2. **User Research**: Interview ADHD users about current pain points
3. **Quick Wins First**: Implement low-effort, high-impact items
4. **Measure & Iterate**: Track ADHD-specific metrics, adjust based on data
5. **Document Patterns**: As features ship, document what works for ADHD users

---

## References

- `docs/ADHD_EXECUTION_PRD.md` - Planned ADHD features
- `docs/COMPREHENSIVE_FEATURE_LIST.md` - Current feature catalog
- Web search results: ADHD productivity app best practices (2025-2026)
- Tiimo app analysis (2025 iPhone App of the Year)
- JITAI research (just-in-time adaptive interventions)
- WCAG cognitive accessibility guidelines
- Prospective memory research (time-based vs event-based)

---

**Last Updated**: 2026-01-16  
**Status**: Recommendations document - ready for team review and prioritization
