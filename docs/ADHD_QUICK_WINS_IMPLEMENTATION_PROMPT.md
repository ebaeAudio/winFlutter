# ADHD Quick Wins Implementation Prompt

**For**: AI Agent / Developer  
**Purpose**: Implement the 8 "Quick Wins" from `ADHD_IMPROVEMENTS_RECOMMENDATIONS.md`  
**Priority**: High Impact, Low Effort improvements for ADHD users  
**Status**: Ready for implementation

---

## Context

This prompt implements the **Quick Wins** section from `docs/ADHD_IMPROVEMENTS_RECOMMENDATIONS.md`. These are low-effort, high-impact improvements specifically designed to make Win the Year more useful for people with ADHD.

**Key principles to follow**:
- Maintain existing design system (`lib/app/theme.dart`, `lib/ui/app_scaffold.dart`, `lib/ui/spacing.dart`)
- Use Material 3 widgets and existing components
- Keep UI accessible (≥44px touch targets, good contrast)
- Follow ADHD-first UX: default to one path, small commitments, gentle recovery

**Reference documents**:
- `docs/ADHD_IMPROVEMENTS_RECOMMENDATIONS.md` - Full recommendations with research basis
- `docs/FRONTEND_SPEC.md` - UI implementation guidelines
- `docs/ADHD_EXECUTION_PRD.md` - Existing ADHD features
- `agentPrompt.md` - Product spec

---

## Quick Wins to Implement

### 1. Visual Progress Indicators for Timer

**Problem**: Current timer shows numbers but lacks visual representation of time passing. ADHD users benefit from visual time awareness.

**Implementation**:
- Add **circular progress ring** around the timer display
- Add **visual "time remaining" bar** that shrinks as time passes
- Add **color transitions**: 
  - Green (plenty of time) → Yellow (halfway/warning) → Red (almost done)
  - Transition thresholds: >50% = green, 25-50% = yellow, <25% = red
- Keep numeric display but make visual elements prominent

**Acceptance criteria**:
- [ ] Circular progress ring shows time remaining (fills as time passes)
- [ ] Color transitions smoothly based on time remaining
- [ ] Visual bar (horizontal or vertical) shrinks as time decreases
- [ ] Works in both light and dark themes
- [ ] Accessible (color is not the only indicator - also has shape/numeric)

**Files to modify**:
- `lib/features/today/widgets/focus_action_lane.dart` (timer display)
- Possibly create: `lib/ui/components/timer_progress_ring.dart`

---

### 2. Explain "Why" in Notifications/Prompts

**Problem**: Notifications and prompts feel arbitrary. ADHD users need context to trust and act on prompts.

**Implementation**:
- Add brief rationale to any prompts/notifications
- Examples:
  - "You set 3 Must-Wins today. 2 are done. Time to tackle the last one?"
  - "You usually start focus sessions at 9am. Ready to begin?"
  - "Your focus timer ended. What did you accomplish?"
- Keep explanations short (1 sentence max)
- Use calm, direct tone (see `docs/FRONTEND_SPEC.md`)

**Acceptance criteria**:
- [ ] All user-facing prompts include brief "why" context
- [ ] Explanations are skimmable (not paragraphs)
- [ ] Tone matches existing app voice (calm, direct)
- [ ] No overwhelming information

**Files to modify**:
- Any notification/prompt code (search for `SnackBar`, `showDialog`, notification code)
- Coach messages in Today screen
- Focus mode prompts

---

### 3. Graded Prompts (Start Small)

**Problem**: Prompts can feel overwhelming. ADHD users need small, actionable prompts.

**Implementation**:
- **Morning prompts**: "What's your one Must-Win today?" (not "plan your whole day")
- **Afternoon prompts**: "How's that Must-Win going?" (not "complete everything")
- **Evening prompts**: "Quick reflection: what helped today?" (not "write a long journal")
- Break large actions into micro-steps
- Show one prompt at a time, not multiple

**Acceptance criteria**:
- [ ] Prompts ask for one small action, not many
- [ ] Morning/afternoon/evening prompts are appropriately sized
- [ ] No overwhelming lists of things to do in prompts
- [ ] Prompts feel achievable, not stressful

**Files to modify**:
- Coach message logic in Today screen
- Any onboarding or feature discovery prompts
- Reflection prompts

---

### 4. Transition Checklists When Timer Ends

**Problem**: ADHD users struggle with transitions. When timer ends, they need help wrapping up and transitioning.

**Implementation**:
- When timebox timer ends, show a **"Wrap up checklist"** bottom sheet:
  - "Save your work" (checkbox)
  - "Note where you left off" (quick text input, saves to task notes)
  - "Set next session focus" (optional, picks next incomplete Must-Win)
- Make checklist dismissible (don't force completion)
- Show gentle transition cue: "Time's up! Let's wrap up smoothly."

**Acceptance criteria**:
- [ ] Timer end triggers wrap-up checklist sheet
- [ ] Checklist has 2-3 simple items
- [ ] "Note where you left off" saves to task notes automatically
- [ ] Checklist is dismissible (not forced)
- [ ] Gentle, non-judgmental language

**Files to modify**:
- `lib/features/today/today_timebox_controller.dart` (timer end logic)
- Create: `lib/features/today/widgets/wrap_up_checklist_sheet.dart`
- Task notes saving logic

---

### 5. "Where Was I?" Resume Feature

**Problem**: ADHD users lose context after distraction. Need quick way to resume.

**Implementation**:
- Add **"Resume" button/card** on Today screen when:
  - User had an active focus session that was interrupted
  - User was working on a task but didn't complete it
- Show: "You were working on [task name] for [X] minutes"
- Tapping "Resume" restores focus mode with that task
- Store last active task/session in local state (persist across app restarts)

**Acceptance criteria**:
- [ ] "Resume" card appears when user had interrupted work
- [ ] Shows task name and approximate time spent
- [ ] Tapping resume restores focus mode with that task
- [ ] Persists across app restarts (local storage)
- [ ] Only shows if relevant (not always visible)

**Files to modify**:
- `lib/features/today/today_screen.dart` (add resume card)
- `lib/features/today/today_controller.dart` (track last active task)
- Local persistence for resume state

---

### 6. Context Save on Task Switch

**Problem**: When switching tasks, ADHD users lose context. Need to capture "where did I leave off?"

**Implementation**:
- When user switches focus task (or exits focus mode), show optional prompt:
  - "Quick note: where did you leave off?" (text input)
  - Auto-saves to task notes
- When returning to a task that has a "last time" note, show it:
  - "Last time: [context note]" (subtle, below task title or in focus lane)
- Make this optional (don't force, just offer)

**Acceptance criteria**:
- [ ] Optional context save prompt when switching tasks
- [ ] Context note saves to task notes automatically
- [ ] "Last time" note displays when returning to task
- [ ] Non-intrusive (optional, dismissible)
- [ ] Works with existing task notes system

**Files to modify**:
- Focus task switching logic
- Task notes display in focus action lane
- Task details/notes saving

---

### 7. Dyslexia-Friendly Font Option

**Problem**: Some ADHD users also have dyslexia. Need accessible font option.

**Implementation**:
- Add font option in Settings → Appearance
- Options:
  - "System Default" (current)
  - "Dyslexia-Friendly" (use system accessibility font or OpenDyslexic if available)
- Respect system font size settings (already should work)
- Apply font globally via theme

**Acceptance criteria**:
- [ ] Font option in Settings → Appearance
- [ ] Font applies globally when selected
- [ ] Respects system font size settings
- [ ] Works in light and dark themes
- [ ] Option is clearly labeled

**Files to modify**:
- `lib/features/settings/settings_screen.dart` (add font picker)
- `lib/app/theme.dart` (apply font to textTheme)
- Settings persistence

**Note**: May need to add `open_dyslexic` package or use system accessibility font. Check Flutter packages for dyslexia-friendly fonts.

---

### 8. Reduce Motion / Animation Controls

**Problem**: Some ADHD users are sensitive to motion. Need to respect system settings and provide controls.

**Implementation**:
- Respect system "Reduce Motion" setting automatically
- Add setting: "Reduce Animations" (in Settings → Appearance)
- When enabled:
  - Disable or minimize celebratory animations (W-drop, etc.)
  - Use subtle transitions only
  - Keep essential UI animations (but make them minimal)
- Option to disable specific animations (W-drop celebration)

**Acceptance criteria**:
- [ ] Respects system "Reduce Motion" setting
- [ ] "Reduce Animations" toggle in Settings
- [ ] When enabled, animations are minimal or disabled
- [ ] W-drop celebration can be disabled separately (optional)
- [ ] Essential UI still works (no broken interactions)

**Files to modify**:
- `lib/features/settings/settings_screen.dart` (add animation controls)
- Animation code (W-drop, transitions)
- Check for `MediaQuery.of(context).disableAnimations` or similar

---

## Implementation Order (Suggested)

1. **Visual Progress Indicators** (#1) - Most visible impact
2. **Transition Checklists** (#4) - Complements timer improvements
3. **"Where Was I?" Resume** (#5) - Quick to implement, high value
4. **Context Save** (#6) - Works with resume feature
5. **Explain "Why"** (#2) - Touch multiple areas, but straightforward
6. **Graded Prompts** (#3) - Review existing prompts, update copy
7. **Reduce Motion** (#8) - System integration
8. **Dyslexia Font** (#7) - May require package research

---

## Testing Checklist

After implementation, test:

- [ ] All features work in light and dark themes
- [ ] All features work with existing focus mode
- [ ] Timer visualizations are accurate and smooth
- [ ] Settings persist across app restarts
- [ ] No breaking changes to existing functionality
- [ ] Accessibility: touch targets ≥44px, good contrast
- [ ] Empty states handled gracefully
- [ ] Error states show helpful messages

---

## Acceptance Criteria (Overall)

- [ ] All 8 quick wins implemented
- [ ] Code follows existing patterns (`AppScaffold`, `Gap`, `AppSpace`)
- [ ] UI is accessible (contrast, touch targets, semantics)
- [ ] Settings persist correctly
- [ ] No regressions in existing features
- [ ] ADHD-first principles maintained (one path, small commitments, gentle recovery)

---

## Questions to Resolve

1. **Dyslexia font**: Which package/library to use? (OpenDyslexic, system font, or other?)
2. **Animation reduction**: Should W-drop be completely disabled or just minimized?
3. **Context save**: Should it be automatic (on focus switch) or manual (prompt)?
4. **Resume persistence**: How long should resume state persist? (24 hours? Until manually cleared?)

---

## Notes

- These are **low-effort, high-impact** improvements
- Focus on **user experience** over perfect implementation
- **Iterate** - these can be refined based on user feedback
- Maintain **calm, direct** tone in all copy
- Keep **one primary CTA** principle (don't add too many buttons)

---

**Ready to implement?** Start with #1 (Visual Progress Indicators) and work through the list. Each item should be independently testable and shippable.
