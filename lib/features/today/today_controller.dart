import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/auth.dart';
import '../../app/linear_integration_controller.dart';
import '../../app/theme.dart';
import '../../data/habits/habits_repository.dart';
import '../../data/habits/habits_providers.dart';
import '../../data/linear/linear_issue_repository.dart';
import '../../data/tasks/task.dart' as data;
import '../../data/tasks/task_details_providers.dart';
import '../../data/tasks/task_details_repository.dart';
import '../../data/tasks/tasks_providers.dart';
import '../../data/tasks/tasks_repository.dart';
import '../../domain/focus/active_timebox.dart';
import 'linear_task_helper.dart';
import 'today_models.dart';
import 'morning_wizard/morning_wizard_data.dart';

final todayControllerProvider =
    StateNotifierProvider.family<TodayController, TodayDayData, String>(
        (ref, ymd) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final tasksRepo = ref.watch(tasksRepositoryProvider);
  final habitsRepo = ref.watch(habitsRepositoryProvider);
  final taskDetailsRepo = ref.watch(taskDetailsRepositoryProvider);
  final linearRepo = ref.watch(linearIssueRepositoryProvider);
  final recordLinearStatus =
      ref.read(linearIntegrationControllerProvider.notifier).recordSyncStatus;
  // Important: this must react to auth changes; otherwise Today can get stuck in
  // "local-only" mode if it initializes before Supabase session restoration.
  final auth = ref.watch(authStateProvider).valueOrNull;
  final isSignedIn = tasksRepo != null && (auth?.isSignedIn ?? false);
  return TodayController(
    prefs: prefs,
    ymd: ymd,
    tasksRepository: isSignedIn ? tasksRepo : null,
    taskDetailsRepository: taskDetailsRepo,
    habitsRepository: habitsRepo,
    linearIssueRepository: linearRepo,
    recordLinearSyncStatus: recordLinearStatus,
  );
});

class TodayController extends StateNotifier<TodayDayData> {
  TodayController({
    required SharedPreferences prefs,
    required String ymd,
    required TasksRepository? tasksRepository,
    required TaskDetailsRepository? taskDetailsRepository,
    required HabitsRepository habitsRepository,
    required LinearIssueRepository? linearIssueRepository,
    required Future<void> Function({required DateTime at, String? error})
        recordLinearSyncStatus,
  })  : _prefs = prefs,
        _ymd = ymd,
        _tasksRepository = tasksRepository,
        _taskDetailsRepository = taskDetailsRepository,
        _habitsRepository = habitsRepository,
        _linearIssueRepository = linearIssueRepository,
        _recordLinearSyncStatus = recordLinearSyncStatus,
        super(TodayDayData.empty(ymd)) {
    if (_tasksRepository == null) {
      // Local-only mode (demo/unconfigured): preserve existing behavior.
      final raw = _prefs.getString(_keyForLocalDay(_ymd));
      if (raw != null && raw.trim().isNotEmpty) {
        state = TodayDayData.fromJsonString(raw, fallbackYmd: _ymd);
      }
    } else {
      // Supabase mode: tasks come from DB; keep lightweight local prefs for reflection + focus.
      state = state.copyWith(
        reflection: _prefs.getString(_keyForReflection(_ymd)) ?? '',
        focusModeEnabled: _prefs.getBool(_keyForFocusEnabled(_ymd)) ?? false,
        focusTaskId: _prefs.getString(_keyForFocusTaskId(_ymd)),
        activeTimebox: ActiveTimebox.fromJsonString(
            _prefs.getString(_keyForActiveTimebox(_ymd)) ?? ''),
      );
      unawaited(_loadTasksFromSupabase());
    }
    unawaited(_loadHabitsForDay());
  }

  final SharedPreferences _prefs;
  final String _ymd;
  final TasksRepository? _tasksRepository;
  final TaskDetailsRepository? _taskDetailsRepository;
  final HabitsRepository _habitsRepository;
  final LinearIssueRepository? _linearIssueRepository;
  final Future<void> Function({required DateTime at, String? error})
      _recordLinearSyncStatus;

  static String _keyForLocalDay(String ymd) => 'today_day_$ymd';
  static String _keyForReflection(String ymd) => 'today_reflection_$ymd';
  static String _keyForFocusEnabled(String ymd) => 'today_focus_enabled_$ymd';
  static String _keyForFocusTaskId(String ymd) => 'today_focus_task_id_$ymd';
  static String _keyForActiveTimebox(String ymd) => 'today_active_timebox_$ymd';

  bool get _isSupabaseMode => _tasksRepository != null;

  static String _formatYmd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String? _yesterdayYmd() {
    final parsed = DateTime.tryParse(_ymd);
    if (parsed == null) return null;
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    return _formatYmd(day.subtract(const Duration(days: 1)));
  }

  /// Returns yesterday recap context for the Morning Launch Wizard.
  ///
  /// Best-effort and non-throwing. If yesterday can't be loaded, returns an
  /// "empty" recap with 0% and no tasks.
  Future<YesterdayRecap> getYesterdayRecap() async {
    final yYmd = _yesterdayYmd();
    if (yYmd == null || yYmd.trim().isEmpty) {
      return const YesterdayRecap(
        percent: 0,
        label: 'Fresh start',
        mustWinTotal: 0,
        mustWinDone: 0,
        niceToDoTotal: 0,
        niceToDoDone: 0,
        habitsTotal: 0,
        habitsDone: 0,
        incompleteMustWins: [],
      );
    }

    List<TodayTask> tasks = const [];
    if (_isSupabaseMode) {
      final repo = _tasksRepository;
      if (repo != null) {
        try {
          final raw = await repo.listForDate(ymd: yYmd);
          tasks = [for (final t in raw) _toTodayTask(t)];
        } catch (_) {
          tasks = const [];
        }
      }
    } else {
      try {
        final raw = _prefs.getString(_keyForLocalDay(yYmd));
        if (raw != null && raw.trim().isNotEmpty) {
          tasks = TodayDayData.fromJsonString(raw, fallbackYmd: yYmd).tasks;
        }
      } catch (_) {
        tasks = const [];
      }
    }

    int mustWinTotal = 0;
    int mustWinDone = 0;
    int niceTotal = 0;
    int niceDone = 0;
    final incompleteMustWins = <TodayTask>[];

    for (final t in tasks) {
      if (t.isDeleted) continue;
      if (t.type == TodayTaskType.mustWin) {
        mustWinTotal++;
        if (t.completed) {
          mustWinDone++;
        } else {
          incompleteMustWins.add(t);
        }
      } else {
        niceTotal++;
        if (t.completed) niceDone++;
      }
    }

    int habitsTotal = 0;
    int habitsDone = 0;
    try {
      final habits = await _habitsRepository.listHabits();
      habitsTotal = habits.length;
      if (habitsTotal > 0) {
        final completedIds =
            await _habitsRepository.getCompletedHabitIds(ymd: yYmd);
        for (final h in habits) {
          if (completedIds.contains(h.id)) habitsDone++;
        }
      }
    } catch (_) {
      habitsTotal = 0;
      habitsDone = 0;
    }

    final percent = computeScorePercent(
      mustWinDone: mustWinDone,
      mustWinTotal: mustWinTotal,
      niceToDoDone: niceDone,
      niceToDoTotal: niceTotal,
      habitsDone: habitsDone,
      habitsTotal: habitsTotal,
    );

    return YesterdayRecap(
      percent: percent,
      label: scoreLabelForPercent(percent),
      mustWinTotal: mustWinTotal,
      mustWinDone: mustWinDone,
      niceToDoTotal: niceTotal,
      niceToDoDone: niceDone,
      habitsTotal: habitsTotal,
      habitsDone: habitsDone,
      incompleteMustWins: incompleteMustWins,
    );
  }

  /// Returns yesterday's incomplete tasks (best-effort, non-throwing).
  ///
  /// - Supabase mode: queries yesterday’s tasks from DB.
  /// - Local/demo mode: reads yesterday’s cached day JSON from SharedPreferences.
  Future<List<TodayTask>> getYesterdayIncompleteTasks() async {
    final yYmd = _yesterdayYmd();
    if (yYmd == null || yYmd.trim().isEmpty) return const [];

    if (_isSupabaseMode) {
      final repo = _tasksRepository;
      if (repo == null) return const [];
      try {
        final tasks = await repo.listForDate(ymd: yYmd);
        return [
          for (final t in tasks)
            if (!t.completed) _toTodayTask(t),
        ];
      } catch (_) {
        return const [];
      }
    }

    final raw = _prefs.getString(_keyForLocalDay(yYmd));
    if (raw == null || raw.trim().isEmpty) return const [];
    final yDay = TodayDayData.fromJsonString(raw, fallbackYmd: yYmd);
    return [for (final t in yDay.tasks) if (!t.completed) t];
  }

  /// Moves a selected set of yesterday tasks onto this controller’s day.
  ///
  /// Safety: if today already has tasks (in DB or local state), this is a no-op.
  /// The provided [taskIds] should typically come from yesterday data.
  Future<int> rolloverYesterdayTasksById(Set<String> taskIds) async {
    if (taskIds.isEmpty) return 0;
    final yYmd = _yesterdayYmd();
    if (yYmd == null || yYmd.trim().isEmpty) return 0;

    if (_isSupabaseMode) {
      final repo = _tasksRepository;
      if (repo == null) return 0;

      // Safety check: don’t roll over if today already has tasks in DB.
      try {
        final todayExisting = await repo.listForDate(ymd: _ymd);
        if (todayExisting.isNotEmpty) return 0;
      } catch (_) {
        // If we can't verify, fail safe (don’t move data).
        return 0;
      }

      List<TodayTask> yesterday;
      try {
        final raw = await repo.listForDate(ymd: yYmd);
        yesterday = [for (final t in raw) _toTodayTask(t)];
      } catch (_) {
        return 0;
      }

      final moving = <TodayTask>[
        for (final t in yesterday)
          if (taskIds.contains(t.id) && !t.completed) t,
      ];
      if (moving.isEmpty) return 0;

      await Future.wait([
        for (final t in moving) repo.update(id: t.id, ymd: _ymd),
      ]);
      await _loadTasksFromSupabase();
      return moving.length;
    }

    // Local/demo mode.
    if (state.tasks.isNotEmpty) return 0;

    final rawYesterday = _prefs.getString(_keyForLocalDay(yYmd));
    final yDay = (rawYesterday == null || rawYesterday.trim().isEmpty)
        ? TodayDayData.empty(yYmd)
        : TodayDayData.fromJsonString(rawYesterday, fallbackYmd: yYmd);

    final moving = <TodayTask>[
      for (final t in yDay.tasks)
        if (taskIds.contains(t.id) && !t.completed) t,
    ];
    if (moving.isEmpty) return 0;

    final remainingYesterday = yDay.copyWith(
      tasks: [
        for (final t in yDay.tasks)
          if (!taskIds.contains(t.id) || t.completed) t,
      ],
    );
    await _prefs.setString(
        _keyForLocalDay(yYmd), remainingYesterday.toJsonString());

    final nextToday = state.copyWith(tasks: [...state.tasks, ...moving]);
    await _saveLocalDay(nextToday);
    unawaited(_autoSelectFocusTaskIfNeeded());
    return moving.length;
  }

  /// Moves yesterday’s incomplete tasks onto this controller’s day.
  ///
  /// Safety: if today already has tasks (in DB or local state), this is a no-op.
  Future<int> rolloverYesterdayTasks() async {
    final yYmd = _yesterdayYmd();
    if (yYmd == null || yYmd.trim().isEmpty) return 0;

    if (_isSupabaseMode) {
      final repo = _tasksRepository;
      if (repo == null) return 0;

      // Safety check: don’t roll over if today already has tasks in DB.
      try {
        final todayExisting = await repo.listForDate(ymd: _ymd);
        if (todayExisting.isNotEmpty) return 0;
      } catch (_) {
        // If we can't verify, fail safe (don’t move data).
        return 0;
      }

      final yesterday = await getYesterdayIncompleteTasks();
      if (yesterday.isEmpty) return 0;

      await Future.wait([
        for (final t in yesterday) repo.update(id: t.id, ymd: _ymd),
      ]);

      await _loadTasksFromSupabase();
      return yesterday.length;
    }

    // Local/demo mode.
    if (state.tasks.isNotEmpty) return 0;

    final rawYesterday = _prefs.getString(_keyForLocalDay(yYmd));
    final yDay = (rawYesterday == null || rawYesterday.trim().isEmpty)
        ? TodayDayData.empty(yYmd)
        : TodayDayData.fromJsonString(rawYesterday, fallbackYmd: yYmd);

    final moving = [for (final t in yDay.tasks) if (!t.completed) t];
    if (moving.isEmpty) return 0;

    final remainingYesterday =
        yDay.copyWith(tasks: [for (final t in yDay.tasks) if (t.completed) t]);
    await _prefs.setString(
        _keyForLocalDay(yYmd), remainingYesterday.toJsonString());

    // Use current state as "today" day data.
    final nextToday = state.copyWith(tasks: [...state.tasks, ...moving]);
    await _saveLocalDay(nextToday);
    unawaited(_autoSelectFocusTaskIfNeeded());
    return moving.length;
  }

  Future<void> _syncLinearTask({
    required String taskId,
    bool? completed,
    bool? inProgress,
  }) {
    return maybeSyncLinearTask(
      taskId: taskId,
      isSupabaseMode: _isSupabaseMode,
      localTasks: state.tasks,
      taskDetailsRepository: _taskDetailsRepository,
      linearIssueRepository: _linearIssueRepository,
      recordLinearSyncStatus: _recordLinearSyncStatus,
      completed: completed,
      inProgress: inProgress,
    );
  }

  TodayTask _toTodayTask(data.Task t) {
    final type = switch (t.type) {
      data.TaskType.mustWin => TodayTaskType.mustWin,
      data.TaskType.niceToDo => TodayTaskType.niceToDo,
    };
    return TodayTask(
      id: t.id,
      title: t.title,
      type: type,
      completed: t.completed,
      inProgress: t.inProgress && !t.completed,
      details: t.details,
      goalYmd: t.goalDate,
      starterStep: t.starterStep,
      estimatedMinutes: t.estimatedMinutes,
      createdAtMs: t.createdAt.millisecondsSinceEpoch,
    );
  }

  Future<void> setTaskGoalDate(String taskId, String? goalYmd) async {
    if (_isSupabaseMode) {
      final repo = _tasksRepository;
      if (repo == null) return;
      final updated = await repo.update(id: taskId, goalYmd: goalYmd);
      state = state.copyWith(
        tasks: [
          for (final t in state.tasks)
            if (t.id == taskId) _toTodayTask(updated) else t,
        ],
      );
      return;
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId) t.copyWith(goalYmd: goalYmd) else t,
    ];
    await _saveLocalDay(state.copyWith(tasks: nextTasks));
  }

  Future<void> _saveLocalDay(TodayDayData next) async {
    state = next;
    await _prefs.setString(_keyForLocalDay(_ymd), next.toJsonString());
  }

  Future<void> _saveReflection(String text) async {
    await _prefs.setString(_keyForReflection(_ymd), text);
  }

  Future<void> _saveFocusEnabled(bool enabled) async {
    await _prefs.setBool(_keyForFocusEnabled(_ymd), enabled);
  }

  Future<void> _saveFocusTaskId(String? taskId) async {
    if (taskId == null || taskId.trim().isEmpty) {
      await _prefs.remove(_keyForFocusTaskId(_ymd));
      return;
    }
    await _prefs.setString(_keyForFocusTaskId(_ymd), taskId);
  }

  Future<void> _saveActiveTimebox(ActiveTimebox? timebox) async {
    if (timebox == null) {
      await _prefs.remove(_keyForActiveTimebox(_ymd));
      return;
    }
    await _prefs.setString(
        _keyForActiveTimebox(_ymd), ActiveTimebox.toJsonString(timebox));
  }

  Future<void> _loadTasksFromSupabase() async {
    final repo = _tasksRepository;
    if (repo == null) return;
    try {
      final tasks = await repo.listForDate(ymd: _ymd);
      state = state.copyWith(tasks: [for (final t in tasks) _toTodayTask(t)]);
      unawaited(_autoSelectFocusTaskIfNeeded());
    } catch (_) {
      // Keep existing state (empty tasks). UI surfaces this later with empty-state affordances.
    }
  }

  /// Refresh tasks from Supabase.
  ///
  /// Called by [taskRealtimeSyncProvider] when a task change is detected
  /// from another device. This enables cross-device sync.
  Future<void> refreshTasks() async {
    if (!_isSupabaseMode) return;
    await _loadTasksFromSupabase();
  }

  Future<void> _loadHabitsForDay() async {
    try {
      final habits = await _habitsRepository.listHabits();
      final completedIds =
          await _habitsRepository.getCompletedHabitIds(ymd: _ymd);
      final todayHabits = [
        for (final h in habits)
          TodayHabit(
            id: h.id,
            name: h.name,
            completed: completedIds.contains(h.id),
            createdAtMs: h.createdAtMs,
          ),
      ];
      state = state.copyWith(habits: todayHabits);
    } catch (_) {
      // ignore
    }
  }

  Future<void> setFocusModeEnabled(bool enabled) async {
    final next = state.copyWith(focusModeEnabled: enabled);
    state = next;
    if (_isSupabaseMode) {
      await _saveFocusEnabled(enabled);
    } else {
      await _saveLocalDay(next);
    }
    if (enabled) {
      unawaited(_autoSelectFocusTaskIfNeeded());
    }
  }

  Future<void> setFocusTaskId(String? taskId) async {
    final next = state.copyWith(focusTaskId: taskId);
    state = next;
    if (_isSupabaseMode) {
      await _saveFocusTaskId(taskId);
    } else {
      await _saveLocalDay(next);
    }
  }

  /// Persist (or clear) the active timebox for this day.
  ///
  /// This is stored per-day and restored on app relaunch.
  Future<void> setActiveTimebox(ActiveTimebox? timebox) async {
    final next = state.copyWith(activeTimebox: timebox);
    state = next;
    if (_isSupabaseMode) {
      await _saveActiveTimebox(timebox);
    } else {
      await _saveLocalDay(next);
    }
  }

  /// Enable Today focus mode and ensure a stable default focus task is selected.
  ///
  /// ADHD-friendly default:
  /// - Preserve an existing `focusTaskId`.
  /// - Otherwise, pick the first incomplete Must‑Win (if any) and persist it.
  Future<void> enableFocusModeAndSelectDefaultTask() async {
    if (!state.focusModeEnabled) {
      await setFocusModeEnabled(true);
    } else {
      // Even if already enabled, we may still want to select a default task if
      // none has been chosen yet (e.g., tasks loaded after enabling).
      await _autoSelectFocusTaskIfNeeded();
    }
  }

  Future<void> _autoSelectFocusTaskIfNeeded() async {
    if (!state.focusModeEnabled) return;
    if ((state.focusTaskId ?? '').trim().isNotEmpty) return;

    for (final t in state.tasks) {
      if (t.type == TodayTaskType.mustWin && !t.completed) {
        await setFocusTaskId(t.id);
        return;
      }
    }
  }

  Future<bool> addTask({
    required String title,
    required TodayTaskType type,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return false;

    // If the user pastes a Linear URL or identifier, best-effort "import" it
    // into a nice title + notes so the task reads cleanly.
    //
    // This is intentionally best-effort and must never block task creation.
    String resolvedTitle = trimmed;
    String? resolvedNotes;
    final resolution = await resolveLinearTaskInput(
      input: trimmed,
      linearIssueRepository: _linearIssueRepository,
    );
    if (resolution != null) {
      resolvedTitle = resolution.title;
      resolvedNotes = resolution.notes;
    }

    if (_isSupabaseMode) {
      final repo = _tasksRepository!;
      final created = await repo.create(
        title: resolvedTitle,
        type: type == TodayTaskType.mustWin
            ? data.TaskType.mustWin
            : data.TaskType.niceToDo,
        ymd: _ymd,
      );
      state = state.copyWith(tasks: [...state.tasks, _toTodayTask(created)]);

      // Best-effort: write notes after creation (schema may not have notes yet).
      if (resolvedNotes != null && resolvedNotes.trim().isNotEmpty) {
        try {
          final detailsRepo = _taskDetailsRepository;
          if (detailsRepo != null) {
            await detailsRepo.updateDetails(
                taskId: created.id, notes: resolvedNotes);
          } else {
            // Back-compat: if we don't have a details repo, still try to store
            // in the tasks table `details` column for older schemas.
            await repo.update(id: created.id, details: resolvedNotes);
          }
        } catch (_) {
          // Ignore: notes are a nice-to-have.
        }
      }
      return true;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final id = '${nowMs}_${DateTime.now().microsecondsSinceEpoch}';
    final task = TodayTask(
        id: id,
        title: resolvedTitle,
        type: type,
        completed: false,
        inProgress: false,
        createdAtMs: nowMs,
        // Local mode stores details/notes inline with the task.
        details: resolvedNotes,
        notes: resolvedNotes);
    await _saveLocalDay(state.copyWith(tasks: [...state.tasks, task]));
    return true;
  }

  /// Toggles task completion status with optimistic update.
  ///
  /// Returns `true` on success, `false` on failure (state is rolled back).
  /// Ignores rapid double-clicks while an update is in-flight.
  Future<bool> toggleTaskCompleted(String taskId) async {
    // Ignore if already updating this task (prevents rapid double-click bugs)
    if (state.isTaskUpdating(taskId)) return false;

    final current = state.tasks.where((t) => t.id == taskId).toList();
    if (current.isEmpty) return false;

    final task = current.first;
    final nextCompleted = !task.completed;

    // Mark as updating + optimistic update
    final optimisticTasks = [
      for (final t in state.tasks)
        if (t.id == taskId)
          t.copyWith(
            completed: nextCompleted,
            inProgress: nextCompleted ? false : null,
          )
        else
          t,
    ];
    final previousState = state;
    state = state.copyWith(
      tasks: optimisticTasks,
      updatingTaskIds: {...state.updatingTaskIds, taskId},
    );

    try {
      if (_isSupabaseMode) {
        final updated = await _tasksRepository!.update(
          id: taskId,
          completed: nextCompleted,
          inProgress: nextCompleted ? false : null,
        );
        // Reconcile with server response (in case server modified other fields)
        final reconciledTasks = [
          for (final t in state.tasks)
            if (t.id == taskId) _toTodayTask(updated) else t,
        ];
        state = state.copyWith(
          tasks: reconciledTasks,
          updatingTaskIds: {...state.updatingTaskIds}..remove(taskId),
        );
        unawaited(_syncLinearTask(taskId: taskId, completed: nextCompleted));
        return true;
      }

      // Local mode: persist to storage
      await _saveLocalDay(state.copyWith(
        updatingTaskIds: {...state.updatingTaskIds}..remove(taskId),
      ));
      state = state.copyWith(
        updatingTaskIds: {...state.updatingTaskIds}..remove(taskId),
      );
      unawaited(_syncLinearTask(taskId: taskId, completed: nextCompleted));
      return true;
    } catch (_) {
      // Rollback on failure and clear updating flag
      state = previousState;
      return false;
    }
  }

  /// Sets task completion status with optimistic update.
  ///
  /// Returns `true` on success, `false` on failure (state is rolled back).
  /// Ignores rapid double-clicks while an update is in-flight.
  Future<bool> setTaskCompleted(String taskId, bool completed) async {
    // Ignore if already updating this task (prevents rapid double-click bugs)
    if (state.isTaskUpdating(taskId)) return false;

    // Mark as updating + optimistic update
    final optimisticTasks = [
      for (final t in state.tasks)
        if (t.id == taskId)
          t.copyWith(
            completed: completed,
            inProgress: completed ? false : null,
          )
        else
          t,
    ];
    final previousState = state;
    state = state.copyWith(
      tasks: optimisticTasks,
      updatingTaskIds: {...state.updatingTaskIds, taskId},
    );

    try {
      if (_isSupabaseMode) {
        final updated = await _tasksRepository!.update(
          id: taskId,
          completed: completed,
          inProgress: completed ? false : null,
        );
        // Reconcile with server response
        final reconciledTasks = [
          for (final t in state.tasks)
            if (t.id == taskId) _toTodayTask(updated) else t,
        ];
        state = state.copyWith(
          tasks: reconciledTasks,
          updatingTaskIds: {...state.updatingTaskIds}..remove(taskId),
        );
        unawaited(_syncLinearTask(taskId: taskId, completed: completed));
        return true;
      }

      // Local mode: persist to storage
      await _saveLocalDay(state.copyWith(
        updatingTaskIds: {...state.updatingTaskIds}..remove(taskId),
      ));
      state = state.copyWith(
        updatingTaskIds: {...state.updatingTaskIds}..remove(taskId),
      );
      unawaited(_syncLinearTask(taskId: taskId, completed: completed));
      return true;
    } catch (_) {
      // Rollback on failure and clear updating flag
      state = previousState;
      return false;
    }
  }

  /// Sets task in-progress status with optimistic update.
  ///
  /// Returns `true` on success, `false` on failure (state is rolled back).
  /// Ignores rapid double-clicks while an update is in-flight.
  Future<bool> setTaskInProgress(String taskId, bool inProgress) async {
    // Ignore if already updating this task (prevents rapid double-click bugs)
    if (state.isTaskUpdating(taskId)) return false;

    // Mark as updating + optimistic update
    final optimisticTasks = [
      for (final t in state.tasks)
        if (t.id == taskId)
          t.copyWith(
            inProgress: inProgress,
            completed: inProgress ? false : null,
          )
        else
          t,
    ];
    final previousState = state;
    state = state.copyWith(
      tasks: optimisticTasks,
      updatingTaskIds: {...state.updatingTaskIds, taskId},
    );

    try {
      if (_isSupabaseMode) {
        final updated = await _tasksRepository!.update(
          id: taskId,
          inProgress: inProgress,
          completed: inProgress ? false : null,
        );
        // Reconcile with server response
        final reconciledTasks = [
          for (final t in state.tasks)
            if (t.id == taskId) _toTodayTask(updated) else t,
        ];
        state = state.copyWith(
          tasks: reconciledTasks,
          updatingTaskIds: {...state.updatingTaskIds}..remove(taskId),
        );
        unawaited(_syncLinearTask(taskId: taskId, inProgress: inProgress));
        return true;
      }

      // Local mode: persist to storage
      await _saveLocalDay(state.copyWith(
        updatingTaskIds: {...state.updatingTaskIds}..remove(taskId),
      ));
      state = state.copyWith(
        updatingTaskIds: {...state.updatingTaskIds}..remove(taskId),
      );
      unawaited(_syncLinearTask(taskId: taskId, inProgress: inProgress));
      return true;
    } catch (_) {
      // Rollback on failure and clear updating flag
      state = previousState;
      return false;
    }
  }

  Future<void> updateTaskTitle(String taskId, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    if (_isSupabaseMode) {
      final updated =
          await _tasksRepository!.update(id: taskId, title: trimmed);
      final nextTasks = [
        for (final t in state.tasks)
          if (t.id == taskId) _toTodayTask(updated) else t
      ];
      state = state.copyWith(tasks: nextTasks);
      return;
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId) t.copyWith(title: trimmed) else t
    ];
    await _saveLocalDay(state.copyWith(tasks: nextTasks));
  }

  Future<void> updateTaskStarterStep({
    required String taskId,
    required String starterStep,
  }) async {
    final trimmed = starterStep.trimRight();
    if (_isSupabaseMode) {
      final updated =
          await _tasksRepository!.update(id: taskId, starterStep: trimmed);
      final nextTasks = [
        for (final t in state.tasks)
          if (t.id == taskId) _toTodayTask(updated) else t,
      ];
      state = state.copyWith(tasks: nextTasks);
      return;
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId) t.copyWith(starterStep: trimmed) else t,
    ];
    await _saveLocalDay(state.copyWith(tasks: nextTasks));
  }

  Future<void> updateTaskEstimatedMinutes({
    required String taskId,
    required int? estimatedMinutes,
  }) async {
    if (_isSupabaseMode) {
      final updated = await _tasksRepository!
          .update(id: taskId, estimatedMinutes: estimatedMinutes);
      final nextTasks = [
        for (final t in state.tasks)
          if (t.id == taskId) _toTodayTask(updated) else t,
      ];
      state = state.copyWith(tasks: nextTasks);
      return;
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId)
          t.copyWith(estimatedMinutes: estimatedMinutes)
        else
          t,
    ];
    await _saveLocalDay(state.copyWith(tasks: nextTasks));
  }

  static const int maxTaskDetailsChars = 2000;

  Future<void> updateTaskDetailsText({
    required String taskId,
    required String details,
  }) async {
    final trimmed = details.trim();
    if (trimmed.length > maxTaskDetailsChars) {
      throw const FormatException(
          'Details must be $maxTaskDetailsChars characters or less.');
    }
    final next = trimmed.isEmpty ? null : trimmed;

    if (_isSupabaseMode) {
      final updated = await _tasksRepository!.update(
        id: taskId,
        details: trimmed,
      );
      final nextTasks = [
        for (final t in state.tasks)
          if (t.id == taskId) _toTodayTask(updated) else t,
      ];
      state = state.copyWith(tasks: nextTasks);
      return;
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId) t.copyWith(details: next) else t
    ];
    await _saveLocalDay(state.copyWith(tasks: nextTasks));
  }

  Future<void> updateTaskDetails({
    required String taskId,
    String? notes,
    String? nextStep,
    int? estimateMinutes,
    int? actualMinutes,
  }) async {
    if (_isSupabaseMode) {
      // Details are stored separately in Supabase mode (see TaskDetailsRepository).
      throw UnsupportedError(
          'Task details updates are not supported here in Supabase mode.');
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId)
          t.copyWith(
            notes: notes ?? t.notes,
            nextStep: nextStep ?? t.nextStep,
            estimateMinutes: estimateMinutes ?? t.estimateMinutes,
            actualMinutes: actualMinutes ?? t.actualMinutes,
          )
        else
          t,
    ];
    await _saveLocalDay(state.copyWith(tasks: nextTasks));
  }

  Future<void> addSubtask({
    required String taskId,
    required String title,
  }) async {
    if (_isSupabaseMode) {
      throw UnsupportedError(
          'Subtasks are not supported here in Supabase mode.');
    }
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final id = '${nowMs}_${DateTime.now().microsecondsSinceEpoch}';
    final subtask = TodaySubtask(
      id: id,
      title: trimmed,
      completed: false,
      createdAtMs: nowMs,
    );

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId)
          t.copyWith(subtasks: [...t.subtasks, subtask])
        else
          t,
    ];
    await _saveLocalDay(state.copyWith(tasks: nextTasks));
  }

  Future<void> setSubtaskCompleted({
    required String taskId,
    required String subtaskId,
    required bool completed,
  }) async {
    if (_isSupabaseMode) {
      throw UnsupportedError(
          'Subtasks are not supported here in Supabase mode.');
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId)
          t.copyWith(
            subtasks: [
              for (final s in t.subtasks)
                if (s.id == subtaskId) s.copyWith(completed: completed) else s,
            ],
          )
        else
          t,
    ];
    await _saveLocalDay(state.copyWith(tasks: nextTasks));
  }

  Future<void> deleteSubtask({
    required String taskId,
    required String subtaskId,
  }) async {
    if (_isSupabaseMode) {
      throw UnsupportedError(
          'Subtasks are not supported here in Supabase mode.');
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId)
          t.copyWith(
              subtasks: t.subtasks.where((s) => s.id != subtaskId).toList())
        else
          t,
    ];
    await _saveLocalDay(state.copyWith(tasks: nextTasks));
  }

  Future<void> moveTaskType(String taskId, TodayTaskType type) async {
    if (_isSupabaseMode) {
      final updated = await _tasksRepository!.update(
        id: taskId,
        type: type == TodayTaskType.mustWin
            ? data.TaskType.mustWin
            : data.TaskType.niceToDo,
      );
      final nextTasks = [
        for (final t in state.tasks)
          if (t.id == taskId) _toTodayTask(updated) else t
      ];
      state = state.copyWith(tasks: nextTasks);
      return;
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId) t.copyWith(type: type) else t
    ];
    await _saveLocalDay(state.copyWith(tasks: nextTasks));
  }

  Future<void> deleteTask(String taskId) async {
    if (_isSupabaseMode) {
      await _tasksRepository!.delete(id: taskId);
      final nextTasks = state.tasks.where((t) => t.id != taskId).toList();
      final nextFocus = state.focusTaskId == taskId ? null : state.focusTaskId;
      state = state.copyWith(tasks: nextTasks, focusTaskId: nextFocus);
      if (state.focusTaskId != nextFocus) {
        await _saveFocusTaskId(nextFocus);
      }
      return;
    }

    // Local mode: soft delete by setting deletedAtMs.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId) t.copyWith(deletedAtMs: nowMs) else t,
    ];
    final nextFocus = state.focusTaskId == taskId ? null : state.focusTaskId;
    await _saveLocalDay(
        state.copyWith(tasks: nextTasks, focusTaskId: nextFocus));
  }

  /// Permanently removes a task (local mode only; Supabase uses hardDelete).
  Future<void> hardDeleteTask(String taskId) async {
    if (_isSupabaseMode) {
      await _tasksRepository!.hardDelete(id: taskId);
      final nextTasks = state.tasks.where((t) => t.id != taskId).toList();
      final nextFocus = state.focusTaskId == taskId ? null : state.focusTaskId;
      state = state.copyWith(tasks: nextTasks, focusTaskId: nextFocus);
      if (state.focusTaskId != nextFocus) {
        await _saveFocusTaskId(nextFocus);
      }
      return;
    }

    final nextTasks = state.tasks.where((t) => t.id != taskId).toList();
    final nextFocus = state.focusTaskId == taskId ? null : state.focusTaskId;
    await _saveLocalDay(
        state.copyWith(tasks: nextTasks, focusTaskId: nextFocus));
  }

  /// Restores a soft-deleted task.
  Future<void> restoreTask(String taskId) async {
    if (_isSupabaseMode) {
      final restored = await _tasksRepository!.restore(id: taskId);
      state = state.copyWith(tasks: [...state.tasks, _toTodayTask(restored)]);
      return;
    }

    // Local mode: clear deletedAtMs.
    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId) t.copyWith(deletedAtMs: null) else t,
    ];
    await _saveLocalDay(state.copyWith(tasks: nextTasks));
  }

  /// Returns soft-deleted tasks for this day (local mode only; Supabase uses listDeleted).
  List<TodayTask> get deletedTasks =>
      state.tasks.where((t) => t.isDeleted).toList();

  Future<void> setReflection(String text) async {
    final next = state.copyWith(reflection: text);
    state = next;
    if (_isSupabaseMode) {
      await _saveReflection(text);
    } else {
      await _saveLocalDay(next);
    }
  }

  Future<bool> addHabit({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    try {
      final created = await _habitsRepository.create(name: trimmed);
      final next = [
        ...state.habits,
        TodayHabit(
          id: created.id,
          name: created.name,
          completed: false,
          createdAtMs: created.createdAtMs,
        ),
      ];
      state = state.copyWith(habits: next);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sets habit completion status with optimistic update.
  ///
  /// Returns `true` on success, `false` on failure (state is rolled back).
  /// Ignores rapid double-clicks while an update is in-flight.
  Future<bool> setHabitCompleted({
    required String habitId,
    required bool completed,
  }) async {
    // Ignore if already updating this habit (prevents rapid double-click bugs)
    if (state.isHabitUpdating(habitId)) return false;

    // Mark as updating + optimistic update
    final optimisticHabits = [
      for (final h in state.habits)
        if (h.id == habitId) h.copyWith(completed: completed) else h,
    ];
    final previousState = state;
    state = state.copyWith(
      habits: optimisticHabits,
      updatingHabitIds: {...state.updatingHabitIds, habitId},
    );

    try {
      await _habitsRepository.setCompleted(
        habitId: habitId,
        ymd: _ymd,
        completed: completed,
      );
      state = state.copyWith(
        updatingHabitIds: {...state.updatingHabitIds}..remove(habitId),
      );
      return true;
    } catch (_) {
      // Rollback on failure and clear updating flag
      state = previousState;
      return false;
    }
  }
}
