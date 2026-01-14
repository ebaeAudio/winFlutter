import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';
import '../../domain/focus/pomodoro_timer.dart';

final pomodoroTimerControllerProvider =
    StateNotifierProvider<PomodoroTimerController, PomodoroTimerState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PomodoroTimerController(prefs: prefs);
});

class PomodoroTimerController extends StateNotifier<PomodoroTimerState> {
  PomodoroTimerController({required SharedPreferences prefs})
      : _prefs = prefs,
        super(PomodoroTimerState.defaults()) {
    state = _load() ?? PomodoroTimerState.defaults();
    _reconcileExpired();
  }

  final SharedPreferences _prefs;

  static const _key = 'focus_pomodoro_timer_v1';

  PomodoroTimerState? _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    return PomodoroTimerState.fromJsonString(raw);
  }

  Future<void> _save(PomodoroTimerState next) async {
    state = next;
    await _prefs.setString(_key, PomodoroTimerState.toJsonString(next));
  }

  Future<void> reset() async {
    final next = state.copyWith(
      status: PomodoroStatus.idle,
      startedAtMs: null,
      durationSeconds: null,
      pausedRemainingSeconds: null,
    );
    await _save(next);
  }

  Future<void> setFocusMinutes(int minutes) async {
    await _save(state.copyWith(focusMinutes: minutes.clamp(1, 24 * 60)));
  }

  Future<void> setBreakMinutes(int minutes) async {
    await _save(state.copyWith(breakMinutes: minutes.clamp(1, 60)));
  }

  Future<bool> start() async {
    if (state.status != PomodoroStatus.idle) return false;
    final minutes = state.phase == PomodoroPhase.focus
        ? state.focusMinutes
        : state.breakMinutes;
    return state.phase == PomodoroPhase.focus
        ? startFocus(minutes: minutes)
        : startBreak(minutes: minutes);
  }

  Future<bool> startFocus({required int minutes}) async {
    if (state.status != PomodoroStatus.idle) return false;
    final now = DateTime.now();
    await _save(
      state.copyWith(
        phase: PomodoroPhase.focus,
        status: PomodoroStatus.running,
        startedAtMs: now.millisecondsSinceEpoch,
        durationSeconds: (minutes.clamp(1, 24 * 60) * 60),
        pausedRemainingSeconds: null,
      ),
    );
    return true;
  }

  Future<bool> startBreak({required int minutes}) async {
    if (state.status != PomodoroStatus.idle) return false;
    final now = DateTime.now();
    await _save(
      state.copyWith(
        phase: PomodoroPhase.break_,
        status: PomodoroStatus.running,
        startedAtMs: now.millisecondsSinceEpoch,
        durationSeconds: (minutes.clamp(1, 60) * 60),
        pausedRemainingSeconds: null,
      ),
    );
    return true;
  }

  Future<void> pause() async {
    if (state.status != PomodoroStatus.running) return;
    final end = state.endsAt;
    if (end == null) return;
    final rem = end.difference(DateTime.now());
    final remainingSeconds = rem.isNegative ? 0 : rem.inSeconds;
    await _save(
      state.copyWith(
        status: PomodoroStatus.paused,
        startedAtMs: null,
        durationSeconds: state.durationSeconds,
        pausedRemainingSeconds: remainingSeconds,
      ),
    );
  }

  Future<void> resume() async {
    if (state.status != PomodoroStatus.paused) return;
    final remaining =
        (state.pausedRemainingSeconds ?? 0).clamp(0, 24 * 60 * 60);
    // If there is nothing remaining, treat this like a completion.
    if (remaining <= 0) {
      await reconcileExpiredNow();
      return;
    }
    final now = DateTime.now();
    await _save(
      state.copyWith(
        status: PomodoroStatus.running,
        startedAtMs: now.millisecondsSinceEpoch,
        durationSeconds: remaining,
        pausedRemainingSeconds: null,
      ),
    );
  }

  Future<void> addMinutes(int minutes) async {
    final m = minutes.clamp(-24 * 60, 24 * 60);
    if (m == 0) return;

    if (state.status == PomodoroStatus.paused) {
      final rem = (state.pausedRemainingSeconds ?? 0) + (m * 60);
      await _save(
          state.copyWith(pausedRemainingSeconds: rem.clamp(0, 24 * 60 * 60)));
      return;
    }

    if (state.status != PomodoroStatus.running) return;
    final end = state.endsAt;
    if (end == null) return;
    final now = DateTime.now();
    final rem = end.difference(now);
    final nextRemainingSeconds =
        (rem.isNegative ? 0 : rem.inSeconds) + (m * 60);
    // Convert into a new running timer from "now" to avoid tricky "extend endAt" math.
    await _save(
      state.copyWith(
        status: PomodoroStatus.running,
        startedAtMs: now.millisecondsSinceEpoch,
        durationSeconds: nextRemainingSeconds.clamp(0, 24 * 60 * 60),
        pausedRemainingSeconds: null,
      ),
    );
  }

  void _reconcileExpired() {
    // Best-effort reconciliation on init.
    unawaited(reconcileExpiredNow());
  }

  Future<void> reconcileExpiredNow() async {
    final s = state;
    if (s.status != PomodoroStatus.running) return;
    final end = s.endsAt;
    if (end == null) return;
    if (!DateTime.now().isAfter(end)) return;

    final completedFocus = s.phase == PomodoroPhase.focus;
    final nextPhase =
        completedFocus ? PomodoroPhase.break_ : PomodoroPhase.focus;

    await _save(
      s.copyWith(
        phase: nextPhase,
        status: PomodoroStatus.idle,
        startedAtMs: null,
        durationSeconds: null,
        pausedRemainingSeconds: null,
        completedFocusCount: completedFocus
            ? (s.completedFocusCount + 1)
            : s.completedFocusCount,
      ),
    );
  }
}
