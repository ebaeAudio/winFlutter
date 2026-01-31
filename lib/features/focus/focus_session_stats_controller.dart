import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/focus/focus_session.dart';
import '../../domain/focus/focus_session_stats.dart';
import 'focus_session_controller.dart';

/// Provider that computes stats from the focus session history.
final focusSessionStatsProvider = Provider<FocusSessionStats>((ref) {
  final historyAsync = ref.watch(focusSessionHistoryProvider);
  final history = historyAsync.valueOrNull ?? const <FocusSession>[];
  return computeStats(history);
});

/// Pure function to compute stats from a list of sessions.
///
/// This makes testing straightforward and keeps the provider simple.
FocusSessionStats computeStats(List<FocusSession> sessions) {
  if (sessions.isEmpty) return FocusSessionStats.empty;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Find start of current week (Monday)
  final weekday = today.weekday; // 1 = Monday
  final startOfWeek = today.subtract(Duration(days: weekday - 1));
  final startOfMonth = DateTime(now.year, now.month, 1);

  int totalSessions = 0;
  int completedOnTime = 0;
  int endedEarly = 0;
  int emergencyEnds = 0;
  int totalFocusMinutes = 0;
  int longestSessionMinutes = 0;
  int sessionsThisWeek = 0;
  int sessionsThisMonth = 0;
  int totalEmergencyUnlocksUsed = 0;

  // Track sessions per day for streak calculation
  final sessionDays = <DateTime>{};
  // Track sessions per weekday for most productive day
  final sessionsByWeekday = <int, int>{};

  for (final session in sessions) {
    // Only count ended sessions
    if (session.status != FocusSessionStatus.ended) continue;

    totalSessions++;

    // Categorize by end reason
    switch (session.endReason) {
      case FocusSessionEndReason.completed:
        completedOnTime++;
        break;
      case FocusSessionEndReason.userEarlyExit:
        endedEarly++;
        break;
      case FocusSessionEndReason.emergencyException:
        emergencyEnds++;
        break;
      case FocusSessionEndReason.engineFailure:
      case null:
        // Count as completed if no reason specified
        completedOnTime++;
        break;
    }

    // Calculate duration
    final endedAt = session.endedAt ?? session.plannedEndAt;
    final durationMinutes = endedAt.difference(session.startedAt).inMinutes;
    totalFocusMinutes += durationMinutes;
    if (durationMinutes > longestSessionMinutes) {
      longestSessionMinutes = durationMinutes;
    }

    // Track emergency unlocks
    totalEmergencyUnlocksUsed += session.emergencyUnlocksUsed;

    // Check if in current week/month
    final sessionDay = DateTime(
      session.startedAt.year,
      session.startedAt.month,
      session.startedAt.day,
    );

    if (!sessionDay.isBefore(startOfWeek)) {
      sessionsThisWeek++;
    }
    if (!sessionDay.isBefore(startOfMonth)) {
      sessionsThisMonth++;
    }

    // Track unique days for streaks
    sessionDays.add(sessionDay);

    // Track weekday frequency
    final weekdayNum = session.startedAt.weekday;
    sessionsByWeekday[weekdayNum] = (sessionsByWeekday[weekdayNum] ?? 0) + 1;
  }

  // Calculate average
  final averageMinutes =
      totalSessions > 0 ? totalFocusMinutes / totalSessions : 0.0;

  // Calculate streaks
  final sortedDays = sessionDays.toList()..sort((a, b) => b.compareTo(a));
  int currentStreak = 0;
  int longestStreak = 0;

  if (sortedDays.isNotEmpty) {
    // Calculate current streak (consecutive days ending at today or yesterday)
    var checkDay = today;
    // Allow starting from yesterday if no session today yet
    if (!sessionDays.contains(checkDay)) {
      checkDay = today.subtract(const Duration(days: 1));
    }

    int streak = 0;
    while (sessionDays.contains(checkDay)) {
      streak++;
      checkDay = checkDay.subtract(const Duration(days: 1));
    }
    currentStreak = streak;

    // Calculate longest streak ever
    int tempStreak = 1;
    longestStreak = 1;
    for (int i = 0; i < sortedDays.length - 1; i++) {
      final diff = sortedDays[i].difference(sortedDays[i + 1]).inDays;
      if (diff == 1) {
        tempStreak++;
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
        }
      } else {
        tempStreak = 1;
      }
    }
  }

  // Find most productive day
  int? mostProductiveDay;
  int maxSessions = 0;
  sessionsByWeekday.forEach((day, count) {
    if (count > maxSessions) {
      maxSessions = count;
      mostProductiveDay = day;
    }
  });

  return FocusSessionStats(
    totalSessions: totalSessions,
    completedOnTime: completedOnTime,
    endedEarly: endedEarly,
    emergencyEnds: emergencyEnds,
    totalFocusMinutes: totalFocusMinutes,
    averageSessionMinutes: averageMinutes,
    longestSessionMinutes: longestSessionMinutes,
    sessionsThisWeek: sessionsThisWeek,
    sessionsThisMonth: sessionsThisMonth,
    currentStreak: currentStreak,
    longestStreak: longestStreak,
    mostProductiveDayOfWeek: mostProductiveDay,
    totalEmergencyUnlocksUsed: totalEmergencyUnlocksUsed,
  );
}
