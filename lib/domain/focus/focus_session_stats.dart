/// Computed statistics for dumb phone (focus) sessions.
class FocusSessionStats {
  const FocusSessionStats({
    required this.totalSessions,
    required this.completedOnTime,
    required this.endedEarly,
    required this.emergencyEnds,
    required this.totalFocusMinutes,
    required this.averageSessionMinutes,
    required this.longestSessionMinutes,
    required this.sessionsThisWeek,
    required this.sessionsThisMonth,
    required this.currentStreak,
    required this.longestStreak,
    required this.mostProductiveDayOfWeek,
    required this.totalEmergencyUnlocksUsed,
  });

  /// Total number of completed sessions (all time).
  final int totalSessions;

  /// Sessions that ran to their planned end time.
  final int completedOnTime;

  /// Sessions ended early by user choice.
  final int endedEarly;

  /// Sessions ended via emergency exception.
  final int emergencyEnds;

  /// Total minutes spent in focus mode.
  final int totalFocusMinutes;

  /// Average session duration in minutes.
  final double averageSessionMinutes;

  /// Longest single session in minutes.
  final int longestSessionMinutes;

  /// Sessions completed in the current calendar week (Mon-Sun).
  final int sessionsThisWeek;

  /// Sessions completed in the current calendar month.
  final int sessionsThisMonth;

  /// Current streak: consecutive days with at least one completed session.
  final int currentStreak;

  /// Longest streak ever achieved.
  final int longestStreak;

  /// The day of the week with the most sessions (1=Mon, 7=Sun), or null if no data.
  final int? mostProductiveDayOfWeek;

  /// Total emergency unlocks used across all sessions.
  final int totalEmergencyUnlocksUsed;

  /// Human-readable day name for the most productive day.
  String? get mostProductiveDayName {
    if (mostProductiveDayOfWeek == null) return null;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final idx = mostProductiveDayOfWeek! - 1;
    if (idx < 0 || idx >= days.length) return null;
    return days[idx];
  }

  /// Completion rate: sessions that ran to planned end vs total.
  double get completionRate =>
      totalSessions > 0 ? completedOnTime / totalSessions : 0.0;

  /// Total focus time as a Duration.
  Duration get totalFocusDuration => Duration(minutes: totalFocusMinutes);

  static const empty = FocusSessionStats(
    totalSessions: 0,
    completedOnTime: 0,
    endedEarly: 0,
    emergencyEnds: 0,
    totalFocusMinutes: 0,
    averageSessionMinutes: 0,
    longestSessionMinutes: 0,
    sessionsThisWeek: 0,
    sessionsThisMonth: 0,
    currentStreak: 0,
    longestStreak: 0,
    mostProductiveDayOfWeek: null,
    totalEmergencyUnlocksUsed: 0,
  );
}
