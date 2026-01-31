import '../today_models.dart';

/// Yesterday context shown in the Morning Launch Wizard.
class YesterdayRecap {
  const YesterdayRecap({
    required this.percent,
    required this.label,
    required this.mustWinTotal,
    required this.mustWinDone,
    required this.niceToDoTotal,
    required this.niceToDoDone,
    required this.habitsTotal,
    required this.habitsDone,
    required this.incompleteMustWins,
  });

  final int percent;
  final String label;

  final int mustWinTotal;
  final int mustWinDone;
  final int niceToDoTotal;
  final int niceToDoDone;
  final int habitsTotal;
  final int habitsDone;

  /// Yesterday's incomplete Must‑Wins (for carry-forward selection).
  final List<TodayTask> incompleteMustWins;
}

int computeScorePercent({
  required int mustWinDone,
  required int mustWinTotal,
  required int niceToDoDone,
  required int niceToDoTotal,
  required int habitsDone,
  required int habitsTotal,
}) {
  // Matches `agentPrompt.md` defaults and `rollups_controller.dart`.
  const mustWinWeight = 50.0;
  const niceToDoWeight = 20.0;
  const habitsWeight = 30.0;

  double score = 0;
  double maxScore = 0;

  if (mustWinTotal > 0) {
    maxScore += mustWinWeight;
    score += mustWinWeight * (mustWinDone / mustWinTotal);
  }
  if (niceToDoTotal > 0) {
    maxScore += niceToDoWeight;
    score += niceToDoWeight * (niceToDoDone / niceToDoTotal);
  }
  if (habitsTotal > 0) {
    maxScore += habitsWeight;
    score += habitsWeight * (habitsDone / habitsTotal);
  }

  if (maxScore <= 0) return 0;
  return ((score / maxScore) * 100).round().clamp(0, 100);
}

String scoreLabelForPercent(int percent) {
  final p = percent.clamp(0, 100);
  if (p >= 90) return 'Excellent';
  if (p >= 70) return 'Good';
  if (p >= 50) return 'Fair';
  return 'Fresh start';
}

