import 'dart:convert';

import 'package:flutter/foundation.dart';

enum PomodoroPhase { focus, break_ }

enum PomodoroStatus { idle, running, paused }

@immutable
class PomodoroTimerState {
  const PomodoroTimerState({
    required this.phase,
    required this.status,
    required this.focusMinutes,
    required this.breakMinutes,
    this.startedAtMs,
    this.durationSeconds,
    this.pausedRemainingSeconds,
    this.completedFocusCount = 0,
  });

  final PomodoroPhase phase;
  final PomodoroStatus status;

  /// Preferred focus duration for the next run.
  final int focusMinutes;

  /// Preferred break duration for the next run.
  final int breakMinutes;

  /// Epoch millis. Only set when running.
  final int? startedAtMs;

  /// Only set when running (total duration for the current run).
  final int? durationSeconds;

  /// Only set when paused.
  final int? pausedRemainingSeconds;

  final int completedFocusCount;

  PomodoroTimerState copyWith({
    PomodoroPhase? phase,
    PomodoroStatus? status,
    int? focusMinutes,
    int? breakMinutes,
    int? startedAtMs,
    int? durationSeconds,
    int? pausedRemainingSeconds,
    int? completedFocusCount,
  }) {
    return PomodoroTimerState(
      phase: phase ?? this.phase,
      status: status ?? this.status,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      startedAtMs: startedAtMs,
      durationSeconds: durationSeconds,
      pausedRemainingSeconds: pausedRemainingSeconds,
      completedFocusCount: completedFocusCount ?? this.completedFocusCount,
    );
  }

  DateTime? get startedAt => startedAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(startedAtMs!, isUtc: false);

  DateTime? get endsAt {
    final s = startedAt;
    final d = durationSeconds;
    if (s == null || d == null) return null;
    return s.add(Duration(seconds: d));
  }

  Duration remainingAt(DateTime now) {
    if (status == PomodoroStatus.paused) {
      return Duration(
          seconds: (pausedRemainingSeconds ?? 0).clamp(0, 24 * 60 * 60));
    }
    if (status != PomodoroStatus.running) return Duration.zero;
    final end = endsAt;
    if (end == null) return Duration.zero;
    final rem = end.difference(now);
    if (rem.isNegative) return Duration.zero;
    return rem;
  }

  double progressAt(DateTime now) {
    final total = durationSeconds ?? 0;
    if (total <= 0) return 0;
    final rem = remainingAt(now).inSeconds.clamp(0, total);
    return (total - rem) / total;
  }

  Map<String, Object?> toJson() => {
        'phase': phase.name,
        'status': status.name,
        'focusMinutes': focusMinutes,
        'breakMinutes': breakMinutes,
        'startedAtMs': startedAtMs,
        'durationSeconds': durationSeconds,
        'pausedRemainingSeconds': pausedRemainingSeconds,
        'completedFocusCount': completedFocusCount,
      };

  static PomodoroTimerState defaults() {
    return const PomodoroTimerState(
      phase: PomodoroPhase.focus,
      status: PomodoroStatus.idle,
      focusMinutes: 25,
      breakMinutes: 5,
      completedFocusCount: 0,
    );
  }

  static PomodoroTimerState? fromJson(Map<String, Object?> json) {
    final phaseRaw = (json['phase'] as String?) ?? '';
    final statusRaw = (json['status'] as String?) ?? '';
    final phase = PomodoroPhase.values
        .where((p) => p.name == phaseRaw)
        .cast<PomodoroPhase?>()
        .firstOrNull;
    final status = PomodoroStatus.values
        .where((s) => s.name == statusRaw)
        .cast<PomodoroStatus?>()
        .firstOrNull;
    if (phase == null || status == null) return null;

    final focusMinutes = (json['focusMinutes'] as num?)?.toInt();
    final breakMinutes = (json['breakMinutes'] as num?)?.toInt();
    if (focusMinutes == null || breakMinutes == null) return null;

    return PomodoroTimerState(
      phase: phase,
      status: status,
      focusMinutes: focusMinutes.clamp(1, 24 * 60),
      breakMinutes: breakMinutes.clamp(1, 60),
      startedAtMs: (json['startedAtMs'] as num?)?.toInt(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      pausedRemainingSeconds: (json['pausedRemainingSeconds'] as num?)?.toInt(),
      completedFocusCount: ((json['completedFocusCount'] as num?)?.toInt() ?? 0)
          .clamp(0, 999999),
    );
  }

  static PomodoroTimerState? fromJsonString(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    try {
      final decoded = jsonDecode(t);
      if (decoded is! Map) return null;
      return fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  static String toJsonString(PomodoroTimerState state) =>
      jsonEncode(state.toJson());
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
