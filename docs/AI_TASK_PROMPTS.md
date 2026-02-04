# AI Task Prompts — winFlutter Refactoring

> **Usage:** Copy the relevant prompt below, paste into your AI assistant, and start the session. Each prompt is self-contained and references the context sheet.

---

## Prompt Template (Copy This First)

```markdown
You are working on the winFlutter Flutter app. Before starting, read these files in order:

1. `docs/AI_REFACTORING_CONTEXT.md` — Full context on architecture, problems, and coding standards
2. `agentPrompt.md` — Product requirements
3. `docs/FRONTEND_SPEC.md` — UI conventions

Your task: [SPECIFIC TASK BELOW]

Constraints:
- Prefer incremental changes over rewrites
- Keep files under limits: 300 lines (controllers), 500 lines (screens)
- Follow existing Riverpod patterns
- Write tests for new code
- Run `flutter analyze` before considering done
```

---

## Phase 1 Tasks

### Task 1.1: Add Strict Lint Rules

```markdown
You are working on the winFlutter Flutter app. Before starting, read:
1. `docs/AI_REFACTORING_CONTEXT.md`

**Task:** Update `analysis_options.yaml` to add stricter lint rules.

**Requirements:**
1. Keep the existing `include: package:flutter_lints/flutter.yaml`
2. Add analyzer settings:
   - `strict-casts: true`
   - `strict-inference: true`  
   - `strict-raw-types: true`
3. Add linter rules:
   - `prefer_const_constructors: true`
   - `prefer_const_declarations: true`
   - `avoid_dynamic_calls: true`
   - `require_trailing_commas: true`
   - `unawaited_futures: true`
   - `prefer_single_quotes: true`

4. Run `flutter analyze` and report how many issues are found
5. Do NOT fix the issues yet — just update the config

**Output:** Updated `analysis_options.yaml` and count of lint issues found.
```

### Task 1.2: Create Schema Detector

```markdown
You are working on the winFlutter Flutter app. Before starting, read:
1. `docs/AI_REFACTORING_CONTEXT.md`
2. `lib/data/tasks/supabase_tasks_repository.dart` (understand the current schema columns)
3. `lib/app/bootstrap.dart` (where initialization happens)

**Task:** Create a SchemaDetector that detects database schema version at startup.

**Requirements:**
1. Create `lib/data/schema_detector.dart` with:
   - `SchemaVersion` enum with versions (e.g., `v1_base`, `v2_details`, `v3_inProgress`, `v4_focusV2`, `v5_goalDate`)
   - `SchemaDetector` class that probes the `tasks` table once to detect which columns exist
   - Provider: `schemaVersionProvider`

2. The detection should:
   - Make ONE lightweight query to check column existence
   - NOT use nested try-catch (use a single query with all columns, parse errors)
   - Cache the result for the session

3. Update `lib/app/bootstrap.dart` to initialize schema detection after Supabase init

4. Write a unit test in `test/data/schema_detector_test.dart`

**Columns to detect (in order of schema evolution):**
- Base: id, user_id, title, type, date, completed, created_at, updated_at
- v2: + details
- v3: + in_progress
- v4: + starter_step, estimated_minutes
- v5: + goal_date

**Output:** 
- `lib/data/schema_detector.dart`
- Updated `lib/app/bootstrap.dart`
- `test/data/schema_detector_test.dart`
```

### Task 1.3: Refactor SupabaseTasksRepository

```markdown
You are working on the winFlutter Flutter app. Before starting, read:
1. `docs/AI_REFACTORING_CONTEXT.md`
2. `lib/data/tasks/supabase_tasks_repository.dart` (the file to refactor)
3. `lib/data/schema_detector.dart` (the new schema detector)
4. `lib/data/tasks/tasks_providers.dart` (provider wiring)

**Task:** Refactor SupabaseTasksRepository to use SchemaDetector instead of nested try-catch.

**Requirements:**
1. Inject `SchemaVersion` into the repository constructor
2. Create a helper method `_selectColumns` that returns the right SELECT string based on schema version
3. Remove ALL nested try-catch blocks in `listForDate()`, `create()`, `update()`
4. Each method should have ONE Supabase query, not 14 fallbacks
5. Update `tasks_providers.dart` to pass schema version to repository

**Target:** File should go from ~600 lines to ~200 lines

**Preserve:**
- All existing public method signatures
- Backward compatibility with all schema versions
- The `_isMissingColumn` helper (may still be useful for error messages)

**Test:** After refactoring, the app should work the same as before for any schema version.

**Output:**
- Refactored `lib/data/tasks/supabase_tasks_repository.dart`
- Updated `lib/data/tasks/tasks_providers.dart`
- Unit test `test/data/tasks/supabase_tasks_repository_test.dart`
```

---

## Phase 2 Tasks

### Task 2.1: Split TodayController — Tasks

```markdown
You are working on the winFlutter Flutter app. Before starting, read:
1. `docs/AI_REFACTORING_CONTEXT.md`
2. `lib/features/today/today_controller.dart` (the file to split)
3. `lib/features/today/today_models.dart` (data models)
4. `test/focus/focus_session_controller_test.dart` (test pattern to follow)

**Task:** Extract task-related logic from TodayController into a new TodayTasksController.

**Extract these methods:**
- `_loadTasksFromSupabase()`
- `refreshTasks()`
- `addTask()`
- `toggleTaskCompleted()`
- `setTaskCompleted()`
- `setTaskInProgress()`
- `updateTaskTitle()`
- `updateTaskStarterStep()`
- `updateTaskEstimatedMinutes()`
- `updateTaskDetailsText()`
- `moveTaskType()`
- `deleteTask()`
- `hardDeleteTask()`
- `restoreTask()`
- `setTaskGoalDate()`
- `rolloverYesterdayTasks()`
- `rolloverYesterdayTasksById()`
- `getYesterdayIncompleteTasks()`
- `getYesterdayRecap()`

**Create:**
1. `lib/features/today/controllers/today_tasks_controller.dart`
   - New `TodayTasksState` class with: `tasks`, `updatingTaskIds`, `isLoading`
   - New `TodayTasksController` with extracted methods
   - New `todayTasksControllerProvider` (family by ymd)

2. Update `lib/features/today/today_controller.dart`:
   - Remove extracted methods
   - Delegate to new controller OR compose state

3. Write tests in `test/today/today_tasks_controller_test.dart`

**Constraints:**
- Keep backward compatibility — existing code using `todayControllerProvider` should still work
- The new controller should be < 300 lines

**Output:**
- `lib/features/today/controllers/today_tasks_controller.dart`
- Updated `lib/features/today/today_controller.dart`
- `test/today/today_tasks_controller_test.dart`
```

### Task 2.2: Split TodayController — Habits

```markdown
You are working on the winFlutter Flutter app. Before starting, read:
1. `docs/AI_REFACTORING_CONTEXT.md`
2. `lib/features/today/today_controller.dart`
3. `lib/features/today/controllers/today_tasks_controller.dart` (if it exists, follow same pattern)

**Task:** Extract habit-related logic from TodayController into TodayHabitsController.

**Extract these methods:**
- `_loadHabitsForDay()`
- `addHabit()`
- `setHabitCompleted()`

**Create:**
1. `lib/features/today/controllers/today_habits_controller.dart`
   - `TodayHabitsState` with: `habits`, `updatingHabitIds`, `isLoading`
   - `TodayHabitsController` with extracted methods
   - `todayHabitsControllerProvider` (family by ymd)

2. Update `lib/features/today/today_controller.dart`

3. Write tests in `test/today/today_habits_controller_test.dart`

**Output:**
- `lib/features/today/controllers/today_habits_controller.dart`
- Updated `lib/features/today/today_controller.dart`
- `test/today/today_habits_controller_test.dart`
```

### Task 2.3: Split TodayController — Focus

```markdown
You are working on the winFlutter Flutter app. Before starting, read:
1. `docs/AI_REFACTORING_CONTEXT.md`
2. `lib/features/today/today_controller.dart`

**Task:** Extract focus-related logic from TodayController into TodayFocusController.

**Extract these methods/state:**
- `focusModeEnabled` state
- `focusTaskId` state
- `activeTimebox` state
- `setFocusModeEnabled()`
- `setFocusTaskId()`
- `setActiveTimebox()`
- `enableFocusModeAndSelectDefaultTask()`
- `_autoSelectFocusTaskIfNeeded()`
- Related SharedPreferences keys and save methods

**Create:**
1. `lib/features/today/controllers/today_focus_controller.dart`
2. Update `lib/features/today/today_controller.dart`
3. Write tests

**Output:**
- `lib/features/today/controllers/today_focus_controller.dart`
- Updated `lib/features/today/today_controller.dart`
- `test/today/today_focus_controller_test.dart`
```

---

## Phase 3 Tasks

### Task 3.1: Extract TodayScreen Widgets — Task Section

```markdown
You are working on the winFlutter Flutter app. Before starting, read:
1. `docs/AI_REFACTORING_CONTEXT.md`
2. `docs/FRONTEND_SPEC.md`
3. `lib/features/today/today_screen.dart` (find task-related widget code)
4. `lib/ui/components/task_list.dart` (existing component to use)

**Task:** Extract task list rendering from TodayScreen into a dedicated widget.

**Create:** `lib/features/today/widgets/task_section_widget.dart`

**Requirements:**
1. Widget should be "dumb" — data in, callbacks out
2. Props: `tasks`, `title`, `onToggle`, `onTap`, `onAdd`, `isEditing`
3. Use existing `TaskListCard` and `TaskListRow` from `lib/ui/components/task_list.dart`
4. Follow existing widget patterns in `lib/features/today/widgets/`

**Update:** `lib/features/today/today_screen.dart` to use the new widget

**Target:** Reduce today_screen.dart by ~200 lines

**Output:**
- `lib/features/today/widgets/task_section_widget.dart`
- Updated `lib/features/today/today_screen.dart`
```

### Task 3.2: Extract TodayScreen Widgets — Assistant Input

```markdown
You are working on the winFlutter Flutter app. Before starting, read:
1. `docs/AI_REFACTORING_CONTEXT.md`
2. `lib/features/today/today_screen.dart` (find speech/assistant code ~lines 130-450)

**Task:** Extract assistant/speech input logic into a dedicated widget and controller.

**Create:**
1. `lib/features/today/controllers/today_speech_controller.dart`
   - Move all `_speech*` fields and methods
   - Move `_ensureSpeechReady()`, `_startAssistantListening()`, etc.
   
2. `lib/features/today/widgets/assistant_input_widget.dart`
   - UI for text input + mic button + sound level indicator
   - Props: controller reference, onSubmit callback

**Update:** `lib/features/today/today_screen.dart` to use new components

**Target:** Reduce today_screen.dart by ~300 lines

**Output:**
- `lib/features/today/controllers/today_speech_controller.dart`
- `lib/features/today/widgets/assistant_input_widget.dart`
- Updated `lib/features/today/today_screen.dart`
```

### Task 3.3: Add select() for Granular Rebuilds

```markdown
You are working on the winFlutter Flutter app. Before starting, read:
1. `docs/AI_REFACTORING_CONTEXT.md`
2. `lib/features/today/today_screen.dart` (find all `ref.watch` calls)

**Task:** Optimize Riverpod watches to use `select()` for granular rebuilds.

**Find and update:**
All `ref.watch(todayControllerProvider(ymd))` calls that only use part of the state.

**Example transformation:**
```dart
// Before
final today = ref.watch(todayControllerProvider(ymd));
final mustWins = today.tasks.where((t) => t.type == TodayTaskType.mustWin).toList();

// After
final tasks = ref.watch(todayControllerProvider(ymd).select((s) => s.tasks));
final mustWins = tasks.where((t) => t.type == TodayTaskType.mustWin).toList();
```

**Apply to:**
- `today_screen.dart`
- `all_tasks_screen.dart`
- `focus_dashboard_screen.dart`

**Output:** Updated files with optimized watches
```

---

## Phase 4 Tasks

### Task 4.1: Unify Task Models

```markdown
You are working on the winFlutter Flutter app. Before starting, read:
1. `docs/AI_REFACTORING_CONTEXT.md`
2. `lib/features/today/today_models.dart` (TodayTask class)
3. `lib/data/tasks/task.dart` (Task class)
4. `lib/data/tasks/all_tasks_models.dart` (AllTask class)

**Task:** Create a single canonical Task model and migrate existing code.

**Create:** `lib/domain/tasks/task.dart`
- Single `Task` class with all fields
- Remove legacy aliases (`nextStep` → `starterStep`, `estimateMinutes` → `estimatedMinutes`)
- Add `fromDbJson()` and `toDbJson()` for Supabase
- Add `copyWith()`

**Update:**
1. `lib/features/today/today_models.dart` — Use domain Task or remove TodayTask
2. `lib/data/tasks/task.dart` — Forward to domain model or merge
3. All files importing the old models

**Constraints:**
- Preserve all existing functionality
- Handle migration of local storage data that uses old field names

**Output:**
- `lib/domain/tasks/task.dart`
- Updated imports across codebase
- Migration helper for old field names in JSON
```

### Task 4.2: Add Pagination to AllTasksRepository

```markdown
You are working on the winFlutter Flutter app. Before starting, read:
1. `docs/AI_REFACTORING_CONTEXT.md`
2. `lib/data/tasks/all_tasks_repository.dart`
3. `lib/data/tasks/supabase_all_tasks_repository.dart`
4. `lib/features/tasks/all_tasks_screen.dart`

**Task:** Add cursor-based pagination to AllTasksRepository.

**Update interface:**
```dart
abstract interface class AllTasksRepository {
  Future<PaginatedResult<AllTask>> listAll({
    int limit = 50,
    String? cursor,
  });
  // ... other methods
}

class PaginatedResult<T> {
  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
}
```

**Update implementation:**
- Use Supabase `.range()` or cursor-based pagination
- Return `PaginatedResult` instead of `List`

**Update UI:**
- `all_tasks_screen.dart` — Implement infinite scroll
- Load more when user scrolls near bottom

**Output:**
- Updated `lib/data/tasks/all_tasks_repository.dart`
- Updated `lib/data/tasks/supabase_all_tasks_repository.dart`
- Updated `lib/features/tasks/all_tasks_screen.dart`
- New `lib/data/paginated_result.dart`
```

---

## Utility Prompts

### Code Review Prompt

```markdown
You are reviewing code changes in the winFlutter Flutter app. Read `docs/AI_REFACTORING_CONTEXT.md` first.

Review these changes for:
1. File size limits (< 300 lines controllers, < 500 lines screens)
2. No nested try-catch for schema compat
3. Using `select()` for Riverpod watches where appropriate
4. No cross-feature direct imports
5. Tests included for new code
6. Follows existing patterns

Provide specific feedback with file:line references.
```

### Bug Fix Prompt

```markdown
You are fixing a bug in the winFlutter Flutter app. Read `docs/AI_REFACTORING_CONTEXT.md` first.

**Bug:** [DESCRIBE BUG]

**Steps:**
1. Identify root cause
2. Write a failing test that reproduces the bug
3. Fix the bug
4. Verify test passes
5. Run `flutter analyze` to check for issues

Do not introduce new technical debt while fixing.
```

---

*Last updated: 2026-01-31*
