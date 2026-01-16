import 'focus_session.dart';

class FocusSessionQuitStats {
  const FocusSessionQuitStats({
    required this.totalSessions,
    required this.earlyExits,
    required this.completedSessions,
    required this.earlyExitRate,
    required this.currentQuitterStreak,
    required this.longestCompletionStreak,
    required this.totalTimeWasted,
    required this.worstQuitTimeRemaining,
    required this.worstQuitDate,
  });

  final int totalSessions;
  final int earlyExits;
  final int completedSessions;

  /// 0.0 - 1.0
  final double earlyExitRate;

  /// Consecutive early exits, starting from the most recent session.
  final int currentQuitterStreak;

  /// Longest streak of completed sessions (in history order).
  final int longestCompletionStreak;

  /// Sum of (plannedEndAt - endedAt) across early exits (positive deltas only).
  final Duration totalTimeWasted;

  /// Most time remaining when the user quit (max of plannedEndAt - endedAt).
  final Duration? worstQuitTimeRemaining;
  final DateTime? worstQuitDate;

  static FocusSessionQuitStats compute(List<FocusSession> history) {
    final total = history.length;
    int early = 0;
    int completed = 0;

    int quitterStreak = 0;
    int completionStreak = 0;
    int longestCompletionStreak = 0;

    Duration wastedTotal = Duration.zero;
    Duration? worstRemaining;
    DateTime? worstDate;

    for (int i = 0; i < history.length; i++) {
      final s = history[i];
      final reason = s.endReason;

      if (reason == FocusSessionEndReason.userEarlyExit) {
        early++;
        if (i == quitterStreak) {
          // Still in the consecutive prefix.
          quitterStreak++;
        }
        completionStreak = 0;
      } else if (reason == FocusSessionEndReason.completed) {
        completed++;
        completionStreak++;
        if (completionStreak > longestCompletionStreak) {
          longestCompletionStreak = completionStreak;
        }
      } else {
        // Other end reasons break completion streak, but still count toward totals.
        completionStreak = 0;
      }

      if (reason == FocusSessionEndReason.userEarlyExit) {
        final endedAt = s.endedAt;
        if (endedAt != null) {
          final remaining = s.plannedEndAt.difference(endedAt);
          if (remaining > Duration.zero) {
            wastedTotal += remaining;
            if (worstRemaining == null || remaining > worstRemaining) {
              worstRemaining = remaining;
              worstDate = endedAt;
            }
          }
        }
      }
    }

    final earlyExitRate = total == 0 ? 0.0 : (early / total);
    return FocusSessionQuitStats(
      totalSessions: total,
      earlyExits: early,
      completedSessions: completed,
      earlyExitRate: earlyExitRate,
      currentQuitterStreak: quitterStreak,
      longestCompletionStreak: longestCompletionStreak,
      totalTimeWasted: wastedTotal,
      worstQuitTimeRemaining: worstRemaining,
      worstQuitDate: worstDate,
    );
  }
}

