import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/auth.dart';
import '../../../app/theme.dart';
import '../../../data/tasks/tasks_providers.dart';
import '../../../domain/focus/active_timebox.dart';
import '../today_models.dart';
import 'today_tasks_controller.dart';

final todayFocusControllerProvider =
    StateNotifierProvider.family<TodayFocusController, TodayFocusState, String>(
        (ref, ymd) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final tasksRepo = ref.watch(tasksRepositoryProvider);

  // Match TodayController behavior: only treat as "Supabase mode" when we have a
  // tasks repo AND a signed-in session.
  final auth = ref.watch(authStateProvider).valueOrNull;
  final isSupabaseMode = tasksRepo != null && (auth?.isSignedIn ?? false);

  final controller = TodayFocusController(
    prefs: prefs,
    ymd: ymd,
    isSupabaseMode: isSupabaseMode,
  );

  controller.onTasksChanged(ref.read(todayTasksControllerProvider(ymd)).tasks);
  ref.listen<TodayTasksState>(
    todayTasksControllerProvider(ymd),
    (_, next) => controller.onTasksChanged(next.tasks),
  );

  return controller;
});

class TodayFocusState {
  const TodayFocusState({
    required this.focusModeEnabled,
    required this.focusTaskId,
    required this.activeTimebox,
  });

  final bool focusModeEnabled;
  final String? focusTaskId;
  final ActiveTimebox? activeTimebox;

  TodayFocusState copyWith({
    bool? focusModeEnabled,
    Object? focusTaskId = _unset,
    Object? activeTimebox = _unset,
  }) {
    return TodayFocusState(
      focusModeEnabled: focusModeEnabled ?? this.focusModeEnabled,
      focusTaskId: focusTaskId == _unset ? this.focusTaskId : focusTaskId as String?,
      activeTimebox: activeTimebox == _unset ? this.activeTimebox : activeTimebox as ActiveTimebox?,
    );
  }

  static const initial = TodayFocusState(
    focusModeEnabled: false,
    focusTaskId: null,
    activeTimebox: null,
  );
}

const Object _unset = Object();

class TodayFocusController extends StateNotifier<TodayFocusState> {
  TodayFocusController({
    required SharedPreferences prefs,
    required String ymd,
    required bool isSupabaseMode,
  })  : _prefs = prefs,
        _ymd = ymd,
        _isSupabaseMode = isSupabaseMode,
        super(TodayFocusState.initial) {
    if (_isSupabaseMode) {
      state = state.copyWith(
        focusModeEnabled: _prefs.getBool(_keyForFocusEnabled(_ymd)) ?? false,
        focusTaskId: _prefs.getString(_keyForFocusTaskId(_ymd)),
        activeTimebox: ActiveTimebox.fromJsonString(
            _prefs.getString(_keyForActiveTimebox(_ymd)) ?? '',),
      );
    } else {
      final raw = _prefs.getString(_keyForLocalDay(_ymd));
      if (raw != null && raw.trim().isNotEmpty) {
        final day = TodayDayData.fromJsonString(raw, fallbackYmd: _ymd);
        state = state.copyWith(
          focusModeEnabled: day.focusModeEnabled,
          focusTaskId: day.focusTaskId,
          activeTimebox: day.activeTimebox,
        );
      }
    }
  }

  final SharedPreferences _prefs;
  final String _ymd;
  final bool _isSupabaseMode;

  static String _keyForLocalDay(String ymd) => 'today_day_$ymd';
  static String _keyForFocusEnabled(String ymd) => 'today_focus_enabled_$ymd';
  static String _keyForFocusTaskId(String ymd) => 'today_focus_task_id_$ymd';
  static String _keyForActiveTimebox(String ymd) => 'today_active_timebox_$ymd';

  List<TodayTask> _latestTasks = const [];

  void onTasksChanged(List<TodayTask> tasks) {
    _latestTasks = tasks;

    final focusId = (state.focusTaskId ?? '').trim();
    if (focusId.isNotEmpty) {
      final exists = tasks.any((t) => t.id == focusId && !t.isDeleted);
      if (!exists) {
        unawaited(setFocusTaskId(null));
        return;
      }
    }

    unawaited(_autoSelectFocusTaskIfNeeded());
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
        _keyForActiveTimebox(_ymd), ActiveTimebox.toJsonString(timebox),);
  }

  Future<void> _saveLocalFocusState(TodayFocusState next) async {
    final raw = _prefs.getString(_keyForLocalDay(_ymd));
    final day = (raw == null || raw.trim().isEmpty)
        ? TodayDayData.empty(_ymd)
        : TodayDayData.fromJsonString(raw, fallbackYmd: _ymd);

    final updated = TodayDayData(
      ymd: _ymd,
      tasks: day.tasks,
      habits: day.habits,
      reflection: day.reflection,
      focusModeEnabled: next.focusModeEnabled,
      focusTaskId: next.focusTaskId,
      activeTimebox: next.activeTimebox,
    );
    await _prefs.setString(_keyForLocalDay(_ymd), updated.toJsonString());
  }

  Future<void> setFocusModeEnabled(bool enabled) async {
    final next = state.copyWith(focusModeEnabled: enabled);
    state = next;

    if (_isSupabaseMode) {
      await _saveFocusEnabled(enabled);
    } else {
      await _saveLocalFocusState(next);
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
      await _saveLocalFocusState(next);
    }
  }

  Future<void> setActiveTimebox(ActiveTimebox? timebox) async {
    final next = state.copyWith(activeTimebox: timebox);
    state = next;

    if (_isSupabaseMode) {
      await _saveActiveTimebox(timebox);
    } else {
      await _saveLocalFocusState(next);
    }
  }

  Future<void> enableFocusModeAndSelectDefaultTask() async {
    if (!state.focusModeEnabled) {
      await setFocusModeEnabled(true);
    } else {
      await _autoSelectFocusTaskIfNeeded();
    }
  }

  Future<void> _autoSelectFocusTaskIfNeeded() async {
    if (!state.focusModeEnabled) return;
    if ((state.focusTaskId ?? '').trim().isNotEmpty) return;

    for (final t in _latestTasks) {
      if (t.type == TodayTaskType.mustWin && !t.completed && !t.isDeleted) {
        await setFocusTaskId(t.id);
        return;
      }
    }
  }
}

