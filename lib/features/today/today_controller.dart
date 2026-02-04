import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/auth.dart';
import '../../app/theme.dart';
import '../../data/tasks/tasks_providers.dart';
import '../../domain/focus/active_timebox.dart';
import 'controllers/today_habits_controller.dart';
import 'controllers/today_focus_controller.dart';
import 'controllers/today_tasks_controller.dart';
import 'today_models.dart';
import 'morning_wizard/morning_wizard_data.dart';

final todayControllerProvider =
    StateNotifierProvider.family<TodayController, TodayDayData, String>(
        (ref, ymd) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final tasksRepo = ref.watch(tasksRepositoryProvider);
  // Important: this must react to auth changes; otherwise Today can get stuck in
  // "local-only" mode if it initializes before Supabase session restoration.
  final auth = ref.watch(authStateProvider).valueOrNull;
  final isSignedIn = tasksRepo != null && (auth?.isSignedIn ?? false);
  final controller = TodayController(
    ref: ref,
    prefs: prefs,
    ymd: ymd,
    isSupabaseMode: isSignedIn,
  );

  controller._setTasksState(ref.read(todayTasksControllerProvider(ymd)));
  ref.listen<TodayTasksState>(
    todayTasksControllerProvider(ymd),
    (_, next) => controller._setTasksState(next),
  );

  controller._setHabitsState(ref.read(todayHabitsControllerProvider(ymd)));
  ref.listen<TodayHabitsState>(
    todayHabitsControllerProvider(ymd),
    (_, next) => controller._setHabitsState(next),
  );

  controller._setFocusState(ref.read(todayFocusControllerProvider(ymd)));
  ref.listen<TodayFocusState>(
    todayFocusControllerProvider(ymd),
    (_, next) => controller._setFocusState(next),
  );

  return controller;
});

class TodayController extends StateNotifier<TodayDayData> {
  TodayController({
    required Ref ref,
    required SharedPreferences prefs,
    required String ymd,
    required bool isSupabaseMode,
  })  : _ref = ref,
        _prefs = prefs,
        _ymd = ymd,
        _isSupabaseMode = isSupabaseMode,
        super(TodayDayData.empty(ymd)) {
    if (!_isSupabaseMode) {
      // Local-only mode (demo/unconfigured): preserve existing behavior.
      final raw = _prefs.getString(_keyForLocalDay(_ymd));
      if (raw != null && raw.trim().isNotEmpty) {
        state = TodayDayData.fromJsonString(raw, fallbackYmd: _ymd);
      }
    } else {
      // Supabase mode: tasks come from DB; keep lightweight local prefs for reflection + focus.
      state = state.copyWith(
        reflection: _prefs.getString(_keyForReflection(_ymd)) ?? '',
      );
    }
  }

  final Ref _ref;
  final SharedPreferences _prefs;
  final String _ymd;
  final bool _isSupabaseMode;

  static String _keyForLocalDay(String ymd) => 'today_day_$ymd';
  static String _keyForReflection(String ymd) => 'today_reflection_$ymd';

  static const int maxTaskDetailsChars = TodayTasksController.maxTaskDetailsChars;

  void _setTasksState(TodayTasksState tasksState) {
    state = TodayDayData(
      ymd: state.ymd,
      tasks: tasksState.tasks,
      habits: state.habits,
      reflection: state.reflection,
      focusModeEnabled: state.focusModeEnabled,
      focusTaskId: state.focusTaskId,
      activeTimebox: state.activeTimebox,
      updatingTaskIds: tasksState.updatingTaskIds,
      updatingHabitIds: state.updatingHabitIds,
    );
  }

  void _setHabitsState(TodayHabitsState habitsState) {
    state = TodayDayData(
      ymd: state.ymd,
      tasks: state.tasks,
      habits: habitsState.habits,
      reflection: state.reflection,
      focusModeEnabled: state.focusModeEnabled,
      focusTaskId: state.focusTaskId,
      activeTimebox: state.activeTimebox,
      updatingTaskIds: state.updatingTaskIds,
      updatingHabitIds: habitsState.updatingHabitIds,
    );
  }

  void _setFocusState(TodayFocusState focusState) {
    state = TodayDayData(
      ymd: state.ymd,
      tasks: state.tasks,
      habits: state.habits,
      reflection: state.reflection,
      focusModeEnabled: focusState.focusModeEnabled,
      focusTaskId: focusState.focusTaskId,
      activeTimebox: focusState.activeTimebox,
      updatingTaskIds: state.updatingTaskIds,
      updatingHabitIds: state.updatingHabitIds,
    );
  }

  /// Returns yesterday recap context for the Morning Launch Wizard.
  ///
  /// Best-effort and non-throwing. If yesterday can't be loaded, returns an
  /// "empty" recap with 0% and no tasks.
  Future<YesterdayRecap> getYesterdayRecap() {
    return _ref
        .read(todayTasksControllerProvider(_ymd).notifier)
        .getYesterdayRecap();
  }

  /// Returns yesterday's incomplete tasks (best-effort, non-throwing).
  ///
  /// - Supabase mode: queries yesterday’s tasks from DB.
  /// - Local/demo mode: reads yesterday’s cached day JSON from SharedPreferences.
  Future<List<TodayTask>> getYesterdayIncompleteTasks() {
    return _ref
        .read(todayTasksControllerProvider(_ymd).notifier)
        .getYesterdayIncompleteTasks();
  }

  /// Moves a selected set of yesterday tasks onto this controller’s day.
  ///
  /// Safety: if today already has tasks (in DB or local state), this is a no-op.
  /// The provided [taskIds] should typically come from yesterday data.
  Future<int> rolloverYesterdayTasksById(Set<String> taskIds) async {
    final moved = await _ref
        .read(todayTasksControllerProvider(_ymd).notifier)
        .rolloverYesterdayTasksById(taskIds);
    return moved;
  }

  /// Moves yesterday’s incomplete tasks onto this controller’s day.
  ///
  /// Safety: if today already has tasks (in DB or local state), this is a no-op.
  Future<int> rolloverYesterdayTasks() async {
    final moved = await _ref
        .read(todayTasksControllerProvider(_ymd).notifier)
        .rolloverYesterdayTasks();
    return moved;
  }

  Future<void> setTaskGoalDate(String taskId, String? goalYmd) {
    return _ref
        .read(todayTasksControllerProvider(_ymd).notifier)
        .setTaskGoalDate(taskId, goalYmd);
  }

  Future<void> _saveLocalDay(TodayDayData next) async {
    state = next;
    await _prefs.setString(_keyForLocalDay(_ymd), next.toJsonString());
  }

  Future<void> _saveReflection(String text) async {
    await _prefs.setString(_keyForReflection(_ymd), text);
  }

  /// Refresh tasks from Supabase.
  ///
  /// Called by [taskRealtimeSyncProvider] when a task change is detected
  /// from another device. This enables cross-device sync.
  Future<void> refreshTasks() {
    return _ref.read(todayTasksControllerProvider(_ymd).notifier).refreshTasks();
  }

  Future<void> setFocusModeEnabled(bool enabled) {
    return _ref
        .read(todayFocusControllerProvider(_ymd).notifier)
        .setFocusModeEnabled(enabled);
  }

  Future<void> setFocusTaskId(String? taskId) {
    return _ref
        .read(todayFocusControllerProvider(_ymd).notifier)
        .setFocusTaskId(taskId);
  }

  /// Persist (or clear) the active timebox for this day.
  ///
  /// This is stored per-day and restored on app relaunch.
  Future<void> setActiveTimebox(ActiveTimebox? timebox) {
    return _ref
        .read(todayFocusControllerProvider(_ymd).notifier)
        .setActiveTimebox(timebox);
  }

  /// Enable Today focus mode and ensure a stable default focus task is selected.
  ///
  /// ADHD-friendly default:
  /// - Preserve an existing `focusTaskId`.
  /// - Otherwise, pick the first incomplete Must‑Win (if any) and persist it.
  Future<void> enableFocusModeAndSelectDefaultTask() {
    return _ref
        .read(todayFocusControllerProvider(_ymd).notifier)
        .enableFocusModeAndSelectDefaultTask();
  }

  Future<bool> addTask({
    required String title,
    required TodayTaskType type,
  }) async {
    return _ref
        .read(todayTasksControllerProvider(_ymd).notifier)
        .addTask(title: title, type: type);
  }

  /// Toggles task completion status with optimistic update.
  ///
  /// Returns `true` on success, `false` on failure (state is rolled back).
  /// Ignores rapid double-clicks while an update is in-flight.
  Future<bool> toggleTaskCompleted(String taskId) {
    return _ref
        .read(todayTasksControllerProvider(_ymd).notifier)
        .toggleTaskCompleted(taskId);
  }

  /// Sets task completion status with optimistic update.
  ///
  /// Returns `true` on success, `false` on failure (state is rolled back).
  /// Ignores rapid double-clicks while an update is in-flight.
  Future<bool> setTaskCompleted(String taskId, bool completed) {
    return _ref
        .read(todayTasksControllerProvider(_ymd).notifier)
        .setTaskCompleted(taskId, completed);
  }

  /// Sets task in-progress status with optimistic update.
  ///
  /// Returns `true` on success, `false` on failure (state is rolled back).
  /// Ignores rapid double-clicks while an update is in-flight.
  Future<bool> setTaskInProgress(String taskId, bool inProgress) {
    return _ref
        .read(todayTasksControllerProvider(_ymd).notifier)
        .setTaskInProgress(taskId, inProgress);
  }

  Future<void> updateTaskTitle(String taskId, String title) {
    return _ref
        .read(todayTasksControllerProvider(_ymd).notifier)
        .updateTaskTitle(taskId, title);
  }

  Future<void> updateTaskStarterStep({
    required String taskId,
    required String starterStep,
  }) {
    return _ref
        .read(todayTasksControllerProvider(_ymd).notifier)
        .updateTaskStarterStep(taskId: taskId, starterStep: starterStep);
  }

  Future<void> updateTaskEstimatedMinutes({
    required String taskId,
    required int? estimatedMinutes,
  }) {
    return _ref
        .read(todayTasksControllerProvider(_ymd).notifier)
        .updateTaskEstimatedMinutes(
            taskId: taskId, estimatedMinutes: estimatedMinutes,);
  }

  Future<void> updateTaskDetailsText({
    required String taskId,
    required String details,
  }) {
    return _ref
        .read(todayTasksControllerProvider(_ymd).notifier)
        .updateTaskDetailsText(taskId: taskId, details: details);
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
          'Task details updates are not supported here in Supabase mode.',);
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId)
          t.copyWith(
            details: notes ?? t.details,
            starterStep: nextStep ?? t.starterStep,
            estimatedMinutes: estimateMinutes ?? t.estimatedMinutes,
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
          'Subtasks are not supported here in Supabase mode.',);
    }
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final id = '${nowMs}_${DateTime.now().microsecondsSinceEpoch}';
    final subtask = TodaySubtask(
      id: id,
      title: trimmed,
      completed: false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
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
          'Subtasks are not supported here in Supabase mode.',);
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
          'Subtasks are not supported here in Supabase mode.',);
    }

    final nextTasks = [
      for (final t in state.tasks)
        if (t.id == taskId)
          t.copyWith(
              subtasks: t.subtasks.where((s) => s.id != subtaskId).toList(),)
        else
          t,
    ];
    await _saveLocalDay(state.copyWith(tasks: nextTasks));
  }

  Future<void> moveTaskType(String taskId, TodayTaskType type) {
    return _ref
        .read(todayTasksControllerProvider(_ymd).notifier)
        .moveTaskType(taskId, type);
  }

  Future<void> deleteTask(String taskId) async {
    await _ref
        .read(todayTasksControllerProvider(_ymd).notifier)
        .deleteTask(taskId);
  }

  /// Permanently removes a task (local mode only; Supabase uses hardDelete).
  Future<void> hardDeleteTask(String taskId) async {
    await _ref
        .read(todayTasksControllerProvider(_ymd).notifier)
        .hardDeleteTask(taskId);
  }

  /// Restores a soft-deleted task.
  Future<void> restoreTask(String taskId) {
    return _ref
        .read(todayTasksControllerProvider(_ymd).notifier)
        .restoreTask(taskId);
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

  Future<bool> addHabit({required String name}) {
    return _ref.read(todayHabitsControllerProvider(_ymd).notifier).addHabit(
          name: name,
        );
  }

  /// Sets habit completion status with optimistic update.
  ///
  /// Returns `true` on success, `false` on failure (state is rolled back).
  /// Ignores rapid double-clicks while an update is in-flight.
  Future<bool> setHabitCompleted({
    required String habitId,
    required bool completed,
  }) {
    return _ref
        .read(todayHabitsControllerProvider(_ymd).notifier)
        .setHabitCompleted(habitId: habitId, completed: completed);
  }
}
