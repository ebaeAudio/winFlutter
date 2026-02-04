import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/auth.dart';
import '../../../app/linear_integration_controller.dart';
import '../../../app/theme.dart';
import '../../../data/habits/habits_providers.dart';
import '../../../data/habits/habits_repository.dart';
import '../../../data/linear/linear_issue_repository.dart';
import '../../../data/tasks/task_details_providers.dart';
import '../../../data/tasks/task_details_repository.dart';
import '../../../data/tasks/tasks_providers.dart';
import '../../../data/tasks/tasks_repository.dart';
import '../linear_task_helper.dart';
import '../morning_wizard/morning_wizard_data.dart';
import '../today_models.dart';

final todayTasksControllerProvider =
    StateNotifierProvider.family<TodayTasksController, TodayTasksState, String>(
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

  return TodayTasksController(
    prefs: prefs,
    ymd: ymd,
    tasksRepository: isSignedIn ? tasksRepo : null,
    taskDetailsRepository: taskDetailsRepo,
    habitsRepository: habitsRepo,
    linearIssueRepository: linearRepo,
    recordLinearSyncStatus: recordLinearStatus,
  );
});

class TodayTasksState {
  const TodayTasksState({
    required this.tasks,
    required this.updatingTaskIds,
    required this.isLoading,
  });

  final List<TodayTask> tasks;
  final Set<String> updatingTaskIds;
  final bool isLoading;

  bool isTaskUpdating(String taskId) => updatingTaskIds.contains(taskId);

  TodayTasksState copyWith({
    List<TodayTask>? tasks,
    Set<String>? updatingTaskIds,
    bool? isLoading,
  }) {
    return TodayTasksState(
      tasks: tasks ?? this.tasks,
      updatingTaskIds: updatingTaskIds ?? this.updatingTaskIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  static const initial = TodayTasksState(
    tasks: [],
    updatingTaskIds: {},
    isLoading: false,
  );
}

class TodayTasksController extends StateNotifier<TodayTasksState> {
  TodayTasksController({
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
        super(TodayTasksState.initial) {
    if (_isSupabaseMode) {
      state = state.copyWith(isLoading: true);
      unawaited(_loadTasksFromSupabase());
    } else {
      state = state.copyWith(tasks: _loadLocalTasks(), isLoading: false);
    }
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

  List<TodayTask> _loadLocalTasks() {
    final raw = _prefs.getString(_keyForLocalDay(_ymd));
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      return TodayDayData.fromJsonString(raw, fallbackYmd: _ymd).tasks;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveLocalTasks(List<TodayTask> tasks) async {
    final raw = _prefs.getString(_keyForLocalDay(_ymd));
    final current = (raw == null || raw.trim().isEmpty)
        ? TodayDayData.empty(_ymd)
        : TodayDayData.fromJsonString(raw, fallbackYmd: _ymd);

    final next = TodayDayData(
      ymd: _ymd,
      tasks: tasks,
      habits: current.habits,
      reflection: current.reflection,
      focusModeEnabled: current.focusModeEnabled,
      focusTaskId: current.focusTaskId,
      activeTimebox: current.activeTimebox,
    );
    await _prefs.setString(_keyForLocalDay(_ymd), next.toJsonString());
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

  /// Defensive normalization for UI invariants.
  ///
  /// - Completed tasks should never be in progress.
  TodayTask _normalizeTask(TodayTask t) {
    if (!t.completed) return t;
    return t.inProgress ? t.copyWith(inProgress: false) : t;
  }

  Future<void> _loadTasksFromSupabase() async {
    final repo = _tasksRepository;
    if (repo == null) return;
    try {
      final tasks = await repo.listForDate(ymd: _ymd);
      state = state.copyWith(
        tasks: [for (final t in tasks) _normalizeTask(t)],
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
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

  Future<bool> addTask({
    required String title,
    required TodayTaskType type,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return false;

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
        type: type,
        ymd: _ymd,
      );
      state = state.copyWith(tasks: [...state.tasks, _normalizeTask(created)]);

      if (resolvedNotes != null && resolvedNotes.trim().isNotEmpty) {
        try {
          final detailsRepo = _taskDetailsRepository;
          if (detailsRepo != null) {
            await detailsRepo.updateDetails(
                taskId: created.id, notes: resolvedNotes,);
          } else {
            await repo.update(id: created.id, details: resolvedNotes);
          }
        } catch (_) {
          // ignore: notes are a nice-to-have
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
      date: _ymd,
      completed: false,
      inProgress: false,
      details: resolvedNotes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
    );
    final nextTasks = [...state.tasks, task];
    state = state.copyWith(tasks: nextTasks);
    await _saveLocalTasks(nextTasks);
    return true;
  }

  Future<bool> toggleTaskCompleted(String taskId) async {
    if (state.isTaskUpdating(taskId)) return false;

    final current = state.tasks.where((t) => t.id == taskId).toList();
    if (current.isEmpty) return false;

    final task = current.first;
    final nextCompleted = !task.completed;

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
        final reconciledTasks = [
          for (final t in state.tasks)
            if (t.id == taskId) _normalizeTask(updated) else t,
        ];
        state = state.copyWith(
          tasks: reconciledTasks,
          updatingTaskIds: {...state.updatingTaskIds}..remove(taskId),
        );
        unawaited(_syncLinearTask(taskId: taskId, completed: nextCompleted));
        return true;
      }

      await _saveLocalTasks(optimisticTasks);
      state = state.copyWith(
        updatingTaskIds: {...state.updatingTaskIds}..remove(taskId),
      );
      unawaited(_syncLinearTask(taskId: taskId, completed: nextCompleted));
      return true;
    } catch (_) {
      state = previousState;
      return false;
    }
  }

  Future<bool> setTaskCompleted(String taskId, bool completed) async {
    if (state.isTaskUpdating(taskId)) return false;

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
        final reconciledTasks = [
          for (final t in state.tasks)
            if (t.id == taskId) _normalizeTask(updated) else t,
        ];
        state = state.copyWith(
          tasks: reconciledTasks,
          updatingTaskIds: {...state.updatingTaskIds}..remove(taskId),
        );
        unawaited(_syncLinearTask(taskId: taskId, completed: completed));
        return true;
      }

      await _saveLocalTasks(optimisticTasks);
      state = state.copyWith(
        updatingTaskIds: {...state.updatingTaskIds}..remove(taskId),
      );
      unawaited(_syncLinearTask(taskId: taskId, completed: completed));
      return true;
    } catch (_) {
      state = previousState;
      return false;
    }
  }

  Future<bool> setTaskInProgress(String taskId, bool inProgress) async {
    if (state.isTaskUpdating(taskId)) return false;

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
        final reconciledTasks = [
          for (final t in state.tasks)
            if (t.id == taskId) _normalizeTask(updated) else t,
        ];
        state = state.copyWith(
          tasks: reconciledTasks,
          updatingTaskIds: {...state.updatingTaskIds}..remove(taskId),
        );
        unawaited(_syncLinearTask(taskId: taskId, inProgress: inProgress));
        return true;
      }

      await _saveLocalTasks(optimisticTasks);
      state = state.copyWith(
        updatingTaskIds: {...state.updatingTaskIds}..remove(taskId),
      );
      unawaited(_syncLinearTask(taskId: taskId, inProgress: inProgress));
      return true;
    } catch (_) {
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
      state = state.copyWith(
        tasks: [
          for (final t in state.tasks)
            if (t.id == taskId) _normalizeTask(updated) else t,
        ],
      );
      return;
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId) t.copyWith(title: trimmed) else t,
    ];
    state = state.copyWith(tasks: nextTasks);
    await _saveLocalTasks(nextTasks);
  }

  Future<void> updateTaskStarterStep({
    required String taskId,
    required String starterStep,
  }) async {
    final trimmed = starterStep.trimRight();

    if (_isSupabaseMode) {
      final updated =
          await _tasksRepository!.update(id: taskId, starterStep: trimmed);
      state = state.copyWith(
        tasks: [
          for (final t in state.tasks)
            if (t.id == taskId) _normalizeTask(updated) else t,
        ],
      );
      return;
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId) t.copyWith(starterStep: trimmed) else t,
    ];
    state = state.copyWith(tasks: nextTasks);
    await _saveLocalTasks(nextTasks);
  }

  Future<void> updateTaskEstimatedMinutes({
    required String taskId,
    required int? estimatedMinutes,
  }) async {
    if (_isSupabaseMode) {
      final updated = await _tasksRepository!
          .update(id: taskId, estimatedMinutes: estimatedMinutes);
      state = state.copyWith(
        tasks: [
          for (final t in state.tasks)
            if (t.id == taskId) _normalizeTask(updated) else t,
        ],
      );
      return;
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId)
          t.copyWith(estimatedMinutes: estimatedMinutes)
        else
          t,
    ];
    state = state.copyWith(tasks: nextTasks);
    await _saveLocalTasks(nextTasks);
  }

  static const int maxTaskDetailsChars = 2000;

  Future<void> updateTaskDetailsText({
    required String taskId,
    required String details,
  }) async {
    final trimmed = details.trim();
    if (trimmed.length > maxTaskDetailsChars) {
      throw const FormatException(
          'Details must be $maxTaskDetailsChars characters or less.',);
    }
    final next = trimmed.isEmpty ? null : trimmed;

    if (_isSupabaseMode) {
      final updated = await _tasksRepository!.update(
        id: taskId,
        details: trimmed,
      );
      state = state.copyWith(
        tasks: [
          for (final t in state.tasks)
            if (t.id == taskId) _normalizeTask(updated) else t,
        ],
      );
      return;
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId) t.copyWith(details: next) else t,
    ];
    state = state.copyWith(tasks: nextTasks);
    await _saveLocalTasks(nextTasks);
  }

  Future<void> moveTaskType(String taskId, TodayTaskType type) async {
    if (_isSupabaseMode) {
      final updated = await _tasksRepository!.update(
        id: taskId,
        type: type,
      );
      state = state.copyWith(
        tasks: [
          for (final t in state.tasks)
            if (t.id == taskId) _normalizeTask(updated) else t,
        ],
      );
      return;
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId) t.copyWith(type: type) else t,
    ];
    state = state.copyWith(tasks: nextTasks);
    await _saveLocalTasks(nextTasks);
  }

  Future<void> deleteTask(String taskId) async {
    if (_isSupabaseMode) {
      await _tasksRepository!.delete(id: taskId);
      state = state.copyWith(
        tasks: state.tasks.where((t) => t.id != taskId).toList(),
      );
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId)
          t.copyWith(deletedAt: DateTime.fromMillisecondsSinceEpoch(nowMs))
        else
          t,
    ];
    state = state.copyWith(tasks: nextTasks);
    await _saveLocalTasks(nextTasks);
  }

  Future<void> hardDeleteTask(String taskId) async {
    if (_isSupabaseMode) {
      await _tasksRepository!.hardDelete(id: taskId);
      state = state.copyWith(
        tasks: state.tasks.where((t) => t.id != taskId).toList(),
      );
      return;
    }

    final nextTasks = state.tasks.where((t) => t.id != taskId).toList();
    state = state.copyWith(tasks: nextTasks);
    await _saveLocalTasks(nextTasks);
  }

  Future<void> restoreTask(String taskId) async {
    if (_isSupabaseMode) {
      final restored = await _tasksRepository!.restore(id: taskId);
      state = state.copyWith(tasks: [...state.tasks, _normalizeTask(restored)]);
      return;
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId) t.copyWith(deletedAt: null) else t,
    ];
    state = state.copyWith(tasks: nextTasks);
    await _saveLocalTasks(nextTasks);
  }

  Future<void> setTaskGoalDate(String taskId, String? goalYmd) async {
    if (_isSupabaseMode) {
      final repo = _tasksRepository;
      if (repo == null) return;
      final updated = await repo.update(id: taskId, goalYmd: goalYmd);
      state = state.copyWith(
        tasks: [
          for (final t in state.tasks)
            if (t.id == taskId) _normalizeTask(updated) else t,
        ],
      );
      return;
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId) t.copyWith(goalDate: goalYmd) else t,
    ];
    state = state.copyWith(tasks: nextTasks);
    await _saveLocalTasks(nextTasks);
  }

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
            if (!t.completed) _normalizeTask(t),
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

  Future<int> rolloverYesterdayTasksById(Set<String> taskIds) async {
    if (taskIds.isEmpty) return 0;
    final yYmd = _yesterdayYmd();
    if (yYmd == null || yYmd.trim().isEmpty) return 0;

    if (_isSupabaseMode) {
      final repo = _tasksRepository;
      if (repo == null) return 0;

      try {
        final todayExisting = await repo.listForDate(ymd: _ymd);
        if (todayExisting.isNotEmpty) return 0;
      } catch (_) {
        return 0;
      }

      List<TodayTask> yesterday;
      try {
        final raw = await repo.listForDate(ymd: yYmd);
        yesterday = [for (final t in raw) _normalizeTask(t)];
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

    final remainingYesterday = TodayDayData(
      ymd: yYmd,
      tasks: [
        for (final t in yDay.tasks)
          if (!taskIds.contains(t.id) || t.completed) t,
      ],
      habits: yDay.habits,
      reflection: yDay.reflection,
      focusModeEnabled: yDay.focusModeEnabled,
      focusTaskId: yDay.focusTaskId,
      activeTimebox: yDay.activeTimebox,
    );
    await _prefs.setString(
        _keyForLocalDay(yYmd), remainingYesterday.toJsonString(),);

    final nextTodayTasks = [...state.tasks, ...moving];
    state = state.copyWith(tasks: nextTodayTasks);
    await _saveLocalTasks(nextTodayTasks);
    return moving.length;
  }

  Future<int> rolloverYesterdayTasks() async {
    final yYmd = _yesterdayYmd();
    if (yYmd == null || yYmd.trim().isEmpty) return 0;

    if (_isSupabaseMode) {
      final repo = _tasksRepository;
      if (repo == null) return 0;

      try {
        final todayExisting = await repo.listForDate(ymd: _ymd);
        if (todayExisting.isNotEmpty) return 0;
      } catch (_) {
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

    if (state.tasks.isNotEmpty) return 0;

    final rawYesterday = _prefs.getString(_keyForLocalDay(yYmd));
    final yDay = (rawYesterday == null || rawYesterday.trim().isEmpty)
        ? TodayDayData.empty(yYmd)
        : TodayDayData.fromJsonString(rawYesterday, fallbackYmd: yYmd);

    final moving = [for (final t in yDay.tasks) if (!t.completed) t];
    if (moving.isEmpty) return 0;

    final remainingYesterday = TodayDayData(
      ymd: yYmd,
      tasks: [for (final t in yDay.tasks) if (t.completed) t],
      habits: yDay.habits,
      reflection: yDay.reflection,
      focusModeEnabled: yDay.focusModeEnabled,
      focusTaskId: yDay.focusTaskId,
      activeTimebox: yDay.activeTimebox,
    );
    await _prefs.setString(
        _keyForLocalDay(yYmd), remainingYesterday.toJsonString(),);

    final nextTodayTasks = [...state.tasks, ...moving];
    state = state.copyWith(tasks: nextTodayTasks);
    await _saveLocalTasks(nextTodayTasks);
    return moving.length;
  }

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
          tasks = [for (final t in raw) _normalizeTask(t)];
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
}
