import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';

enum TodayTimerKind { focus, break_ }

@immutable
class ActiveTodayTimer {
  const ActiveTodayTimer({
    required this.kind,
    required this.startedAtMs,
    required this.durationMinutes,
    this.taskId,
    this.returnToTaskId,
  });

  final TodayTimerKind kind;

  /// Epoch millis.
  final int startedAtMs;

  final int durationMinutes;

  /// Only for focus timers.
  final String? taskId;

  /// Only for break timers: which task we should return attention to.
  final String? returnToTaskId;

  DateTime get startedAt =>
      DateTime.fromMillisecondsSinceEpoch(startedAtMs, isUtc: false);

  DateTime get endsAt => startedAt.add(Duration(minutes: durationMinutes));

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'startedAtMs': startedAtMs,
        'durationMinutes': durationMinutes,
        'taskId': taskId,
        'returnToTaskId': returnToTaskId,
      };

  static ActiveTodayTimer? fromJson(Map<String, Object?> json) {
    final kindRaw = (json['kind'] as String?) ?? '';
    final kind = TodayTimerKind.values
        .where((k) => k.name == kindRaw)
        .cast<TodayTimerKind?>()
        .firstOrNull;
    if (kind == null) return null;

    final startedAtMs = (json['startedAtMs'] as num?)?.toInt();
    final durationMinutes = (json['durationMinutes'] as num?)?.toInt();
    if (startedAtMs == null || durationMinutes == null) return null;

    return ActiveTodayTimer(
      kind: kind,
      startedAtMs: startedAtMs,
      durationMinutes: durationMinutes,
      taskId: json['taskId'] as String?,
      returnToTaskId: json['returnToTaskId'] as String?,
    );
  }
}

final todayTimeboxControllerProvider = StateNotifierProvider.family<
    TodayTimeboxController, ActiveTodayTimer?, String>((ref, ymd) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return TodayTimeboxController(prefs: prefs, ymd: ymd);
});

class TodayTimeboxController extends StateNotifier<ActiveTodayTimer?> {
  TodayTimeboxController({
    required SharedPreferences prefs,
    required String ymd,
  })  : _prefs = prefs,
        _ymd = ymd,
        super(null) {
    state = _load();
    _reconcileExpired();
  }

  final SharedPreferences _prefs;
  final String _ymd;

  static String _keyForActiveTimer(String ymd) => 'today_active_timer_$ymd';
  static String _keyForPendingAutoStart25m(String ymd) =>
      'today_pending_auto_start_25m_$ymd';

  ActiveTodayTimer? _load() {
    final raw = _prefs.getString(_keyForActiveTimer(_ymd));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return ActiveTodayTimer.fromJson(Map<String, Object?>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> _save(ActiveTodayTimer? timer) async {
    state = timer;
    if (timer == null) {
      await _prefs.remove(_keyForActiveTimer(_ymd));
      return;
    }
    await _prefs.setString(
      _keyForActiveTimer(_ymd),
      jsonEncode(timer.toJson()),
    );
  }

  Duration remainingAt(DateTime now) {
    final t = state;
    if (t == null) return Duration.zero;
    final rem = t.endsAt.difference(now);
    if (rem.isNegative) return Duration.zero;
    return rem;
  }

  bool get isRunning => state != null;

  bool get isFocusRunning => state?.kind == TodayTimerKind.focus;

  bool get isBreakRunning => state?.kind == TodayTimerKind.break_;

  void _reconcileExpired() {
    final t = state;
    if (t == null) return;
    if (!DateTime.now().isAfter(t.endsAt)) return;
    // Best-effort clear on init (and on-demand).
    unawaited(_save(null));
  }

  Future<void> reconcileExpiredNow() async {
    final t = state;
    if (t == null) return;
    if (!DateTime.now().isAfter(t.endsAt)) return;
    await _save(null);
  }

  /// Guards against double-start by returning false if a timer is already active.
  Future<bool> startFocus({
    required String taskId,
    required int minutes,
  }) async {
    if (state != null) return false;
    final now = DateTime.now();
    await _save(
      ActiveTodayTimer(
        kind: TodayTimerKind.focus,
        taskId: taskId,
        startedAtMs: now.millisecondsSinceEpoch,
        durationMinutes: minutes.clamp(1, 24 * 60),
      ),
    );
    return true;
  }

  Future<bool> startBreak({
    required int minutes,
    String? returnToTaskId,
  }) async {
    if (state != null) return false;
    final now = DateTime.now();
    await _save(
      ActiveTodayTimer(
        kind: TodayTimerKind.break_,
        startedAtMs: now.millisecondsSinceEpoch,
        durationMinutes: minutes.clamp(1, 60),
        returnToTaskId: returnToTaskId,
      ),
    );
    return true;
  }

  Future<void> addMinutes(int minutes) async {
    final t = state;
    if (t == null) return;
    final next = ActiveTodayTimer(
      kind: t.kind,
      startedAtMs: t.startedAtMs,
      durationMinutes: (t.durationMinutes + minutes).clamp(1, 24 * 60),
      taskId: t.taskId,
      returnToTaskId: t.returnToTaskId,
    );
    await _save(next);
  }

  Future<void> endEarly() async {
    await _save(null);
  }

  Future<void> queuePendingAutoStart25m() async {
    await _prefs.setBool(_keyForPendingAutoStart25m(_ymd), true);
  }

  Future<bool> maybeConsumePendingAutoStart25m({
    required String focusTaskId,
  }) async {
    // Only if nothing is running.
    if (state != null) return false;

    final pending = _prefs.getBool(_keyForPendingAutoStart25m(_ymd)) ?? false;
    if (!pending) return false;

    await _prefs.remove(_keyForPendingAutoStart25m(_ymd));
    return startFocus(taskId: focusTaskId, minutes: 25);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

