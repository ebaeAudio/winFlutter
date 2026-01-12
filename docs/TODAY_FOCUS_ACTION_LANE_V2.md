## Today Focus mode v2 — Action lane + starter step editor (Workstream B)

### What changed
- **Today → Focus (when enabled)** now renders an **Action lane**:
  - **One primary CTA**: **Start (2 min)**
  - **Quick timeboxes**: 10 / 15 / 25 / 45
  - **Secondary actions**: **I’m stuck**, **Switch task**, **Exit focus**
  - Shows **focus task title** + **starter step** (stored as `next_step`)
- Added **Starter step editor** bottom sheet:
  - Entry points:
    - From Focus lane (“Add/Edit starter step”)
    - From each task row menu (“Starter step”)
  - Supports **add / edit / clear**
  - **Error handling**: inline error + `SnackBar` on failure

### Data / persistence notes
- **Starter step uses the existing field** `next_step` (aka `TaskDetails.nextStep`).
  - **Supabase mode**: uses `TaskDetailsRepository.updateDetails(nextStep: ...)`
  - **Demo/local mode**: uses `TodayController.updateTaskDetails(nextStep: ...)`

### Screenshots to capture (recommended)
From `/today`:
1. **Focus enabled + focus task present + starter step present**
2. **Focus enabled + focus task present + starter step empty**
3. **Starter step editor sheet** (open from Focus lane)
4. **Starter step editor sheet** (open from a task row menu)
5. **I’m stuck** sheet (shows Make it smaller / Switch focus / Exit focus)

### Acceptance checklist
- **One primary CTA**: When Focus mode is enabled, the only visually-primary button in the lane is **Start (2 min)**.
- **Quick timeboxes present**: 10 / 15 / 25 / 45 are visible and tappable.
- **Secondary actions present**: **I’m stuck**, **Switch task**, **Exit focus** are visible and tappable.
- **Starter step displayed**: Focus lane shows the starter step when set.
- **Starter step editor entry points**:
  - Focus lane button opens editor
  - Task row menu item opens editor
- **Add/edit/clear**:
  - Save non-empty step → persists
  - Clear → persists as empty
- **Errors**:
  - Over max length shows inline error
  - Save failures show inline error + `SnackBar`
- **Accessibility basics**:
  - Buttons meet min tap targets (theme buttons are min height 48)
  - Text remains readable using themed colors (no hard-coded low-contrast text)

