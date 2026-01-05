import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../data/habits/habits_repository.dart';
import '../../data/habits/habits_providers.dart';
import '../../data/tasks/task.dart' as data;
import '../../data/tasks/tasks_providers.dart';
import '../../data/tasks/tasks_repository.dart';
import 'today_models.dart';

final todayControllerProvider =
    StateNotifierProvider.family<TodayController, TodayDayData, String>(
        (ref, ymd) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final tasksRepo = ref.watch(tasksRepositoryProvider);
  final habitsRepo = ref.watch(habitsRepositoryProvider);
  final isSignedIn =
      tasksRepo != null && Supabase.instance.client.auth.currentSession != null;
  return TodayController(
    prefs: prefs,
    ymd: ymd,
    tasksRepository: isSignedIn ? tasksRepo : null,
    habitsRepository: habitsRepo,
  );
});

class TodayController extends StateNotifier<TodayDayData> {
  TodayController({
    required SharedPreferences prefs,
    required String ymd,
    required TasksRepository? tasksRepository,
    required HabitsRepository habitsRepository,
  })  : _prefs = prefs,
        _ymd = ymd,
        _tasksRepository = tasksRepository,
        _habitsRepository = habitsRepository,
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
      );
      unawaited(_loadTasksFromSupabase());
    }
    unawaited(_loadHabitsForDay());
  }

  final SharedPreferences _prefs;
  final String _ymd;
  final TasksRepository? _tasksRepository;
  final HabitsRepository _habitsRepository;

  static String _keyForLocalDay(String ymd) => 'today_day_$ymd';
  static String _keyForReflection(String ymd) => 'today_reflection_$ymd';
  static String _keyForFocusEnabled(String ymd) => 'today_focus_enabled_$ymd';
  static String _keyForFocusTaskId(String ymd) => 'today_focus_task_id_$ymd';

  bool get _isSupabaseMode => _tasksRepository != null;

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
      createdAtMs: t.createdAt.millisecondsSinceEpoch,
    );
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

  Future<void> _loadTasksFromSupabase() async {
    final repo = _tasksRepository;
    if (repo == null) return;
    try {
      final tasks = await repo.listForDate(ymd: _ymd);
      state = state.copyWith(tasks: [for (final t in tasks) _toTodayTask(t)]);
    } catch (_) {
      // Keep existing state (empty tasks). UI surfaces this later with empty-state affordances.
    }
  }

  Future<void> _loadHabitsForDay() async {
    try {
      final habits = await _habitsRepository.listHabits();
      final completedIds = await _habitsRepository.getCompletedHabitIds(ymd: _ymd);
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
          await _tasksRepository!.update(id: taskId, completed: nextCompleted);
      final nextTasks = [
        for (final t in state.tasks)
          if (t.id == taskId) _toTodayTask(updated) else t,
      ];
      state = state.copyWith(tasks: nextTasks);
      return;
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId) t.copyWith(completed: !t.completed) else t
    ];
    await _saveLocalDay(state.copyWith(tasks: nextTasks));
  }

  Future<void> setTaskCompleted(String taskId, bool completed) async {
    if (_isSupabaseMode) {
      final updated =
          await _tasksRepository!.update(id: taskId, completed: completed);
      final nextTasks = [
        for (final t in state.tasks)
          if (t.id == taskId) _toTodayTask(updated) else t,
      ];
      state = state.copyWith(tasks: nextTasks);
      return;
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId) t.copyWith(completed: completed) else t
    ];
    await _saveLocalDay(state.copyWith(tasks: nextTasks));
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
