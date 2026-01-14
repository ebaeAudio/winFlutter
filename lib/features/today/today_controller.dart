import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/auth.dart';
import '../../app/linear_integration_controller.dart';
import '../../app/theme.dart';
import '../../data/habits/habits_repository.dart';
import '../../data/habits/habits_providers.dart';
import '../../data/linear/linear_issue_repository.dart';
import '../../data/linear/linear_models.dart';
import '../../data/tasks/task.dart' as data;
import '../../data/tasks/task_details_providers.dart';
import '../../data/tasks/task_details_repository.dart';
import '../../data/tasks/tasks_providers.dart';
import '../../data/tasks/tasks_repository.dart';
import '../../domain/focus/active_timebox.dart';
import 'today_models.dart';

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
        activeTimebox:
            ActiveTimebox.fromJsonString(_prefs.getString(_keyForActiveTimebox(_ymd)) ?? ''),
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

  Future<void> _maybeSyncLinear({
    required String taskId,
    bool? completed,
    bool? inProgress,
  }) async {
    final repo = _linearIssueRepository;
    if (repo == null) return;

    String notesText = '';
    try {
      if (_isSupabaseMode) {
        final detailsRepo = _taskDetailsRepository;
        if (detailsRepo == null) return;
        final details = await detailsRepo.getDetails(taskId: taskId);
        notesText = (details.notes ?? '').trim();
      } else {
        final match = state.tasks.where((t) => t.id == taskId).toList();
        if (match.isEmpty) return;
        final t = match.first;
        notesText = (t.notes ?? t.details ?? '').trim();
      }

      final ref = LinearIssueRef.tryParseFromText(notesText);
      if (ref == null) return;

      final issue = await repo.getIssueByIdentifier(ref.identifier);
      if (issue == null) {
        await _recordLinearSyncStatus(
          at: DateTime.now(),
          error: 'Linear issue not found: ${ref.identifier}',
        );
        return;
      }

      String? desiredType;
      if (inProgress == true) {
        desiredType = 'started';
      } else if (completed == true) {
        desiredType = 'completed';
      } else if (completed == false) {
        // Best-effort revert: move away from completed back to started/unstarted.
        desiredType = issue.findTeamStateByType('started') != null
            ? 'started'
            : (issue.findTeamStateByType('unstarted') != null ? 'unstarted' : null);
      } else if (inProgress == false) {
        // If user explicitly turns off in-progress, revert to unstarted if possible.
        desiredType = issue.findTeamStateByType('unstarted') != null
            ? 'unstarted'
            : (issue.findTeamStateByType('backlog') != null ? 'backlog' : null);
      }

      if (desiredType == null || desiredType.trim().isEmpty) return;

      final updated = await repo.setIssueStateType(issue: issue, stateType: desiredType);
      if (updated == null) {
        await _recordLinearSyncStatus(
          at: DateTime.now(),
          error: 'No Linear state of type “$desiredType” for team.',
        );
        return;
      }

      await _recordLinearSyncStatus(at: DateTime.now(), error: null);
    } catch (e) {
      // Never block the core task toggle; just record the failure.
      await _recordLinearSyncStatus(at: DateTime.now(), error: e.toString());
    }
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

    if (_isSupabaseMode) {
      final repo = _tasksRepository!;
      final created = await repo.create(
        title: trimmed,
        type: type == TodayTaskType.mustWin
            ? data.TaskType.mustWin
            : data.TaskType.niceToDo,
        ymd: _ymd,
      );
      state = state.copyWith(tasks: [...state.tasks, _toTodayTask(created)]);
      return true;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final id = '${nowMs}_${DateTime.now().microsecondsSinceEpoch}';
    final task = TodayTask(
        id: id,
        title: trimmed,
        type: type,
        completed: false,
        inProgress: false,
        createdAtMs: nowMs);
    await _saveLocalDay(state.copyWith(tasks: [...state.tasks, task]));
    return true;
  }

  Future<void> toggleTaskCompleted(String taskId) async {
    if (_isSupabaseMode) {
      final current = state.tasks.where((t) => t.id == taskId).toList();
      if (current.isEmpty) return;
      final nextCompleted = !current.first.completed;
      final updated =
          await _tasksRepository!.update(
            id: taskId,
            completed: nextCompleted,
            inProgress: nextCompleted ? false : null,
          );
      final nextTasks = [
        for (final t in state.tasks)
          if (t.id == taskId) _toTodayTask(updated) else t,
      ];
      state = state.copyWith(tasks: nextTasks);
      unawaited(_maybeSyncLinear(taskId: taskId, completed: nextCompleted));
      return;
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId)
          t.copyWith(
            completed: !t.completed,
            inProgress: (!t.completed) ? false : null,
          )
        else
          t
    ];
    await _saveLocalDay(state.copyWith(tasks: nextTasks));
    // Local mode can sync based on updated state tasks (notes stored locally).
    final nextCompleted = nextTasks
        .where((t) => t.id == taskId)
        .map((t) => t.completed)
        .firstOrNull;
    if (nextCompleted != null) {
      unawaited(_maybeSyncLinear(taskId: taskId, completed: nextCompleted));
    }
  }

  Future<void> setTaskCompleted(String taskId, bool completed) async {
    if (_isSupabaseMode) {
      final updated =
          await _tasksRepository!.update(
            id: taskId,
            completed: completed,
            inProgress: completed ? false : null,
          );
      final nextTasks = [
        for (final t in state.tasks)
          if (t.id == taskId) _toTodayTask(updated) else t,
      ];
      state = state.copyWith(tasks: nextTasks);
      unawaited(_maybeSyncLinear(taskId: taskId, completed: completed));
      return;
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId)
          t.copyWith(completed: completed, inProgress: completed ? false : null)
        else
          t
    ];
    await _saveLocalDay(state.copyWith(tasks: nextTasks));
    unawaited(_maybeSyncLinear(taskId: taskId, completed: completed));
  }

  Future<void> setTaskInProgress(String taskId, bool inProgress) async {
    if (_isSupabaseMode) {
      final updated = await _tasksRepository!.update(
        id: taskId,
        inProgress: inProgress,
        completed: inProgress ? false : null,
      );
      final nextTasks = [
        for (final t in state.tasks)
          if (t.id == taskId) _toTodayTask(updated) else t,
      ];
      state = state.copyWith(tasks: nextTasks);
      unawaited(_maybeSyncLinear(taskId: taskId, inProgress: inProgress));
      return;
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId)
          t.copyWith(
            inProgress: inProgress,
            completed: inProgress ? false : null,
          )
        else
          t,
    ];
    await _saveLocalDay(state.copyWith(tasks: nextTasks));
    unawaited(_maybeSyncLinear(taskId: taskId, inProgress: inProgress));
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
      throw const FormatException('Details must be $maxTaskDetailsChars characters or less.');
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

    final nextTasks = state.tasks.where((t) => t.id != taskId).toList();
    final nextFocus = state.focusTaskId == taskId ? null : state.focusTaskId;
    await _saveLocalDay(
        state.copyWith(tasks: nextTasks, focusTaskId: nextFocus));
  }

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

  Future<void> setHabitCompleted({
    required String habitId,
    required bool completed,
  }) async {
    await _habitsRepository.setCompleted(
      habitId: habitId,
      ymd: _ymd,
      completed: completed,
    );
    final nextHabits = [
      for (final h in state.habits)
        if (h.id == habitId) h.copyWith(completed: completed) else h,
    ];
    state = state.copyWith(habits: nextHabits);
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
