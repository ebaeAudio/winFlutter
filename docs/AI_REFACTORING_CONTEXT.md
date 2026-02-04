# AI Refactoring Context Sheet — winFlutter

> **Purpose:** This document provides context for AI assistants working on scalability improvements to the winFlutter codebase. Read this before starting any refactoring task.

---

## Project Overview

**App:** "Win the Year" — A daily execution app for ADHD-friendly task management, habits, reflections, and focus sessions.

**Stack:**
- Flutter (Dart) — Mobile app targeting iOS + Android
- Riverpod — State management
- Supabase — Backend (Postgres + Auth + Realtime)
- go_router — Navigation

**Key Files to Understand First:**
- `lib/app/bootstrap.dart` — App initialization
- `lib/app/router.dart` — Navigation structure
- `lib/app/theme.dart` — Design system + SharedPreferences provider
- `lib/features/today/today_controller.dart` — Core business logic (needs refactoring)
- `lib/data/tasks/supabase_tasks_repository.dart` — Data layer (needs refactoring)
- `agentPrompt.md` — Product requirements
- `docs/FRONTEND_SPEC.md` — UI conventions

---

## Current Architecture

```
lib/
├── app/           # Bootstrap, router, theme, auth, env
├── features/      # Feature modules (screens + controllers)
│   ├── today/     # Main daily view (LARGEST - needs splitting)
│   ├── focus/     # Focus sessions + policies
│   ├── tasks/     # All tasks view
│   ├── settings/  # User settings
│   └── ...
├── data/          # Repository pattern (interfaces + implementations)
│   ├── tasks/     # Task repositories (NEEDS REFACTORING)
│   ├── focus/     # Focus repositories
│   ├── habits/    # Habits repositories
│   └── linear/    # Linear.app integration
├── domain/        # Domain models (focus domain)
├── ui/            # Shared components + design system
│   ├── components/
│   ├── app_scaffold.dart
│   └── spacing.dart
├── platform/      # Platform-specific (notifications, restrictions)
├── assistant/     # AI assistant client
└── utils/         # Utility extensions
```

---

## Critical Problems (Prioritized)

### P0: Schema Migration Tech Debt in Repositories

**Location:** `lib/data/tasks/supabase_tasks_repository.dart`

**Problem:** 14 nested try-catch blocks per method to handle different database schema versions. This pattern is repeated in `listForDate()`, `create()`, and `update()` methods (~600 lines of try-catch hell).

**Example of the anti-pattern (DO NOT REPLICATE):**
```dart
// BAD - Current code has 14 levels of this
try {
  rows = await _client.from('tasks').select(_selectV1);
} catch (_) {
  try {
    rows = await _client.from('tasks').select(_selectV2);
  } catch (_) {
    try {
      rows = await _client.from('tasks').select(_selectV3);
    } catch (_) {
      // ... 11 more levels
    }
  }
}
```

**Fix Approach:**
1. Create a `SchemaDetector` that runs once at app startup
2. Store detected schema version in memory
3. Use single SELECT based on detected version
4. Remove all nested try-catch fallbacks

---

### P1: God-Class Files Need Splitting

**Files exceeding safe limits:**

| File | Lines | Target |
|------|-------|--------|
| `lib/features/today/today_screen.dart` | 2,337 | < 500 |
| `lib/features/today/today_controller.dart` | 1,181 | < 300 |
| `lib/features/focus/ui/focus_dashboard_screen.dart` | 1,447 | < 500 |
| `lib/features/tasks/all_tasks_screen.dart` | 1,079 | < 500 |

**For today_screen.dart, extract:**
- `widgets/date_navigation_header.dart`
- `widgets/task_section.dart`
- `widgets/habit_section.dart`
- `widgets/assistant_input.dart`
- `widgets/dashboard_drag_handle.dart`
- `controllers/today_speech_controller.dart` (speech recognition logic)

**For today_controller.dart, split into:**
- `today_tasks_controller.dart` — Task CRUD, completion, rollover
- `today_habits_controller.dart` — Habit CRUD, completion
- `today_reflection_controller.dart` — Reflection text
- `today_focus_controller.dart` — Focus mode, task selection, timebox

---

### P2: Model Duplication

**Problem:** Two parallel Task models with legacy field aliases.

**Locations:**
- `lib/features/today/today_models.dart` → `TodayTask`
- `lib/data/tasks/task.dart` → `Task`

**Legacy aliases to remove:**
- `nextStep` → use only `starterStep`
- `estimateMinutes` → use only `estimatedMinutes`

**Target:** Single canonical `Task` model in `lib/domain/tasks/task.dart`

---

### P3: Missing Pagination

**Location:** `lib/data/tasks/all_tasks_repository.dart`

**Current:** `Future<List<AllTask>> listAll()` — loads ALL tasks

**Target:**
```dart
Future<PaginatedResult<AllTask>> listAll({
  int limit = 50,
  String? cursor,
  AllTasksQuery? query,
});
```

---

### P4: Widget Rebuild Hotspots

**Location:** `lib/features/today/today_screen.dart` lines 460-490

**Problem:** Watching entire `TodayDayData` causes full rebuild on any change.

**Current:**
```dart
final today = ref.watch(todayControllerProvider(ymd));
```

**Target:**
```dart
final tasks = ref.watch(todayControllerProvider(ymd).select((s) => s.tasks));
final habits = ref.watch(todayControllerProvider(ymd).select((s) => s.habits));
```

---

### P5: Test Coverage < 6%

**Current test files:** 11 files for 192 source files

**Priority test targets:**
1. `lib/data/tasks/supabase_tasks_repository.dart` — Mock Supabase client
2. `lib/features/today/today_controller.dart` — In-memory repos
3. `lib/features/focus/focus_session_controller.dart` — Already has test pattern

**Test pattern to follow (from existing tests):**
```dart
// See: test/focus/focus_session_controller_test.dart
final container = ProviderContainer(
  overrides: [
    repositoryProvider.overrideWithValue(fakeRepo),
  ],
);
addTearDown(container.dispose);

await container.read(controllerProvider.notifier).someMethod();
expect(container.read(controllerProvider).value, expectedValue);
```

---

## Coding Standards

### Riverpod Patterns

**State Management:**
```dart
// Use StateNotifier for mutable state
final myControllerProvider = StateNotifierProvider<MyController, MyState>((ref) {
  return MyController(ref.watch(dependencyProvider));
});

// Use AsyncNotifier for async initialization
final myAsyncProvider = AsyncNotifierProvider<MyAsyncController, MyData>(
  MyAsyncController.new,
);

// Use .family for parameterized providers
final todayProvider = StateNotifierProvider.family<TodayController, TodayState, String>(
  (ref, ymd) => TodayController(ymd: ymd, ...),
);
```

**Granular Rebuilds:**
```dart
// BAD - rebuilds on any state change
final state = ref.watch(myProvider);

// GOOD - rebuilds only when specific field changes
final tasks = ref.watch(myProvider.select((s) => s.tasks));
```

**Optimistic Updates Pattern (follow existing):**
```dart
Future<bool> toggleTaskCompleted(String taskId) async {
  if (state.isTaskUpdating(taskId)) return false; // Prevent double-tap
  
  final previousState = state;
  state = state.copyWith(
    tasks: optimisticUpdate,
    updatingTaskIds: {...state.updatingTaskIds, taskId},
  );
  
  try {
    final result = await repository.update(...);
    state = state.copyWith(
      tasks: reconciledTasks,
      updatingTaskIds: {...state.updatingTaskIds}..remove(taskId),
    );
    return true;
  } catch (_) {
    state = previousState; // Rollback
    return false;
  }
}
```

### UI Conventions

**Use existing design system:**
```dart
// Spacing - use AppSpace constants
Gap.h12  // 12px vertical gap
Gap.w8   // 8px horizontal gap
AppSpace.s16  // 16px value

// Radii - use theme constants
BorderRadius.circular(kRadiusMedium)  // 12px
BorderRadius.circular(kRadiusSmall)   // 8px

// Scaffold - use AppScaffold for screens
return AppScaffold(
  title: 'Screen Title',
  children: [...],
);

// Sections - use SectionHeader
SectionHeader(title: 'Must-Win Tasks', trailing: addButton)
```

**Widget extraction pattern:**
```dart
// Extract to lib/features/<feature>/widgets/<widget_name>.dart
class TaskSectionWidget extends ConsumerWidget {
  const TaskSectionWidget({
    super.key,
    required this.tasks,
    required this.onToggle,
  });
  
  final List<TodayTask> tasks;
  final void Function(String taskId) onToggle;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep widgets "dumb" - data in, callbacks out
  }
}
```

### Repository Pattern

**Interface definition:**
```dart
// lib/data/<domain>/<domain>_repository.dart
abstract interface class TasksRepository {
  Future<List<Task>> listForDate({required String ymd});
  Future<Task> create({required String title, required TaskType type, required String ymd});
  Future<Task> update({required String id, String? title, bool? completed});
  Future<void> delete({required String id});
}
```

**Implementation:**
```dart
// lib/data/<domain>/supabase_<domain>_repository.dart
class SupabaseTasksRepository implements TasksRepository {
  SupabaseTasksRepository(this._client, this._schemaVersion);
  
  final SupabaseClient _client;
  final SchemaVersion _schemaVersion;
  
  // Single SELECT based on schema version - NO nested try-catch
}
```

**Provider wiring:**
```dart
// lib/data/<domain>/<domain>_providers.dart
final tasksRepositoryProvider = Provider<TasksRepository?>((ref) {
  final env = ref.watch(envProvider);
  final supabase = ref.watch(supabaseProvider);
  if (env.demoMode || !supabase.isInitialized) return null;
  return SupabaseTasksRepository(supabase.client!, ref.watch(schemaVersionProvider));
});
```

---

## Task Queue (In Priority Order)

### Phase 1: Foundation (Week 1-2)

1. **Add strict lint rules** — `analysis_options.yaml`
   - Enable `strict-casts`, `strict-inference`, `prefer_const_constructors`
   
2. **Create SchemaDetector** — New file `lib/data/schema_detector.dart`
   - Detect schema version once at startup
   - Store in provider
   
3. **Refactor SupabaseTasksRepository** — Remove nested try-catch
   - Use SchemaDetector
   - Single SELECT per method

### Phase 2: Controller Splitting (Week 3-4)

4. **Split TodayController** into:
   - `TodayTasksController`
   - `TodayHabitsController`
   - `TodayReflectionController`
   - `TodayFocusController`
   
5. **Add unit tests** for each new controller

### Phase 3: UI Cleanup (Week 5-6)

6. **Extract widgets from today_screen.dart**
   - Target: < 500 lines for main screen file
   
7. **Add select() for granular rebuilds**

### Phase 4: Data Layer (Week 7-8)

8. **Unify Task models** — Single canonical model
9. **Add pagination** to AllTasksRepository
10. **Implement caching layer** (Hive or drift)

---

## Do's and Don'ts

### DO:
- ✅ Read existing code before modifying
- ✅ Follow existing patterns (optimistic updates, provider structure)
- ✅ Keep files < 300 lines (controllers) or < 500 lines (screens)
- ✅ Use `select()` for Riverpod watches
- ✅ Write tests for new code
- ✅ Use existing UI components from `lib/ui/components/`
- ✅ Preserve backward compatibility for data migrations

### DON'T:
- ❌ Add nested try-catch for schema compatibility
- ❌ Create new god-classes
- ❌ Import directly across feature boundaries
- ❌ Use `dynamic` types (except JSON parsing)
- ❌ Add new packages without justification
- ❌ Modify working code without tests in place first
- ❌ Remove legacy field support without migration path

---

## Quick Reference: File Locations

| Concern | Location |
|---------|----------|
| App bootstrap | `lib/app/bootstrap.dart` |
| Navigation | `lib/app/router.dart` |
| Theme/design tokens | `lib/app/theme.dart` |
| Spacing constants | `lib/ui/spacing.dart` |
| Shared components | `lib/ui/components/` |
| Task repository | `lib/data/tasks/supabase_tasks_repository.dart` |
| Today controller | `lib/features/today/today_controller.dart` |
| Today screen | `lib/features/today/today_screen.dart` |
| Focus controller | `lib/features/focus/focus_session_controller.dart` |
| Test examples | `test/focus/focus_session_controller_test.dart` |

---

## Validation Checklist

Before marking any refactoring task complete:

- [ ] `flutter analyze` passes with zero issues
- [ ] `flutter test` passes
- [ ] No new lint warnings introduced
- [ ] File is under line limit (300 for controllers, 500 for screens)
- [ ] Existing functionality still works (manual smoke test)
- [ ] No new cross-feature imports added
- [ ] Documentation updated if API changed

---

*Last updated: 2026-01-31*
*Based on scalability analysis of winFlutter codebase*
