import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/habits/habits_repository.dart';
import '../../data/habits/habits_providers.dart';
import '../../data/tasks/all_tasks_models.dart';
import '../../data/tasks/all_tasks_providers.dart';
import '../../data/tasks/all_tasks_repository.dart';
import '../../data/tasks/task.dart';

enum RollupRange { week, month, year }

extension RollupRangeLabel on RollupRange {
  String get label => switch (this) {
        RollupRange.week => 'Week',
        RollupRange.month => 'Month',
        RollupRange.year => 'Year',
      };
}

class RollupRangeWindow {
  const RollupRangeWindow({
    required this.start,
    required this.end,
  });

  final DateTime start; // inclusive (date-only)
  final DateTime end; // inclusive (date-only)

  String get startYmd => _formatYmd(start);
  String get endYmd => _formatYmd(end);
}

class RollupDayBreakdown {
  const RollupDayBreakdown({
    required this.ymd,
    required this.percent,
    required this.mustWinDone,
    required this.mustWinTotal,
    required this.niceToDoDone,
    required this.niceToDoTotal,
    required this.habitsDone,
    required this.habitsTotal,
  });

  final String ymd;
  final int percent; // 0..100

  final int mustWinDone;
  final int mustWinTotal;
  final int niceToDoDone;
  final int niceToDoTotal;
  final int habitsDone;
  final int habitsTotal;
}

class RollupsData {
  const RollupsData({
    required this.range,
    required this.window,
    required this.previousWindow,
    required this.averagePercent,
    required this.previousAveragePercent,
    required this.breakdown,
    required this.chartValues,
    required this.chartLabels,
  });

  final RollupRange range;
  final RollupRangeWindow window;
  final RollupRangeWindow previousWindow;

  final int averagePercent; // 0..100
  final int previousAveragePercent; // 0..100

  /// Always in ascending date order.
  final List<RollupDayBreakdown> breakdown;

  /// Week/month: daily values; year: 12 monthly averages.
  final List<int> chartValues;
  final List<String> chartLabels;

  int get deltaPercent => averagePercent - previousAveragePercent;
}

final rollupsProvider =
    FutureProvider.family<RollupsData, RollupRange>((ref, range) async {
  final AllTasksRepository? allTasksRepo = ref.watch(allTasksRepositoryProvider);
  final HabitsRepository habitsRepo = ref.watch(habitsRepositoryProvider);

  // If tasks repo is unavailable (e.g. signed out or Supabase not configured),
  // keep the screen functional but empty.
  final allTasks = <AllTask>[];
  if (allTasksRepo != null) {
    String? cursor;
    for (var page = 0; page < 100; page++) {
      final res = await allTasksRepo.listAll(limit: 250, cursor: cursor);
      allTasks.addAll(res.items);
      if (!res.hasMore || res.nextCursor == null) break;
      cursor = res.nextCursor;
      if (allTasks.length >= 10000) break; // safety cap
    }
  }

  final habits = await habitsRepo.listHabits();
  final habitIds = <String>{for (final h in habits) h.id};

  final now = _dateOnly(DateTime.now());
  final window = _windowFor(range, now);
  final prev = _previousWindowFor(range, window);

  final breakdown = await _computeDailyBreakdown(
    tasks: allTasks,
    habitsRepo: habitsRepo,
    habitIds: habitIds,
    window: window,
  );
  final prevBreakdown = await _computeDailyBreakdown(
    tasks: allTasks,
    habitsRepo: habitsRepo,
    habitIds: habitIds,
    window: prev,
  );

  final avg = _averagePercent(breakdown);
  final prevAvg = _averagePercent(prevBreakdown);

  final chart = _chartFor(range, breakdown);

  return RollupsData(
    range: range,
    window: window,
    previousWindow: prev,
    averagePercent: avg,
    previousAveragePercent: prevAvg,
    breakdown: breakdown,
    chartValues: chart.values,
    chartLabels: chart.labels,
  );
});

class _ChartData {
  const _ChartData({required this.values, required this.labels});
  final List<int> values;
  final List<String> labels;
}

_ChartData _chartFor(RollupRange range, List<RollupDayBreakdown> days) {
  switch (range) {
    case RollupRange.year:
      final byMonth = <int, List<int>>{};
      for (final d in days) {
        final dt = DateTime.tryParse(d.ymd);
        if (dt == null) continue;
        (byMonth[dt.month] ??= <int>[]).add(d.percent);
      }
      final labels = <String>[
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final values = <int>[
        for (var m = 1; m <= 12; m++)
          () {
            final list = byMonth[m] ?? const <int>[];
            if (list.isEmpty) return 0;
            final sum = list.fold<int>(0, (a, b) => a + b);
            return (sum / list.length).round().clamp(0, 100);
          }(),
      ];
      return _ChartData(values: values, labels: labels);
    case RollupRange.week:
    case RollupRange.month:
      final labels = <String>[];
      final values = <int>[];
      for (final d in days) {
        values.add(d.percent);
        final dt = DateTime.tryParse(d.ymd);
        labels.add(dt == null ? '' : DateFormat('E').format(dt));
      }
      return _ChartData(values: values, labels: labels);
  }
}

Future<List<RollupDayBreakdown>> _computeDailyBreakdown({
  required List<AllTask> tasks,
  required HabitsRepository habitsRepo,
  required Set<String> habitIds,
  required RollupRangeWindow window,
}) async {
  final tasksByYmd = <String, List<AllTask>>{};
  for (final t in tasks) {
    final ymd = t.ymd;
    if (ymd.compareTo(window.startYmd) < 0) continue;
    if (ymd.compareTo(window.endYmd) > 0) continue;
    (tasksByYmd[ymd] ??= <AllTask>[]).add(t);
  }

  final out = <RollupDayBreakdown>[];
  var day = window.start;
  while (!day.isAfter(window.end)) {
    final ymd = _formatYmd(day);
    final dayTasks = tasksByYmd[ymd] ?? const <AllTask>[];

    int mustWinTotal = 0;
    int mustWinDone = 0;
    int niceTotal = 0;
    int niceDone = 0;
    for (final t in dayTasks) {
      if (t.type == TaskType.mustWin) {
        mustWinTotal++;
        if (t.completed) mustWinDone++;
      } else {
        niceTotal++;
        if (t.completed) niceDone++;
      }
    }

    final completedHabitIds = await habitsRepo.getCompletedHabitIds(ymd: ymd);
    int habitsTotal = habitIds.length;
    int habitsDone = 0;
    if (habitsTotal > 0) {
      for (final id in habitIds) {
        if (completedHabitIds.contains(id)) habitsDone++;
      }
    }

    final percent = _computeScorePercent(
      mustWinDone: mustWinDone,
      mustWinTotal: mustWinTotal,
      niceToDoDone: niceDone,
      niceToDoTotal: niceTotal,
      habitsDone: habitsDone,
      habitsTotal: habitsTotal,
    );

    out.add(
      RollupDayBreakdown(
        ymd: ymd,
        percent: percent,
        mustWinDone: mustWinDone,
        mustWinTotal: mustWinTotal,
        niceToDoDone: niceDone,
        niceToDoTotal: niceTotal,
        habitsDone: habitsDone,
        habitsTotal: habitsTotal,
      ),
    );

    day = day.add(const Duration(days: 1));
  }

  return out;
}

int _averagePercent(List<RollupDayBreakdown> days) {
  if (days.isEmpty) return 0;
  final sum = days.fold<int>(0, (a, d) => a + d.percent);
  return (sum / days.length).round().clamp(0, 100);
}

int _computeScorePercent({
  required int mustWinDone,
  required int mustWinTotal,
  required int niceToDoDone,
  required int niceToDoTotal,
  required int habitsDone,
  required int habitsTotal,
}) {
  // Matches `agentPrompt.md` defaults.
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

RollupRangeWindow _windowFor(RollupRange range, DateTime anchor) {
  final a = _dateOnly(anchor);
  switch (range) {
    case RollupRange.week:
      // Monday-start week.
      final start = a.subtract(Duration(days: a.weekday - 1));
      final end = start.add(const Duration(days: 6));
      return RollupRangeWindow(start: start, end: end);
    case RollupRange.month:
      final start = DateTime(a.year, a.month, 1);
      final end = DateTime(a.year, a.month + 1, 0);
      return RollupRangeWindow(start: start, end: end);
    case RollupRange.year:
      final start = DateTime(a.year, 1, 1);
      final end = DateTime(a.year, 12, 31);
      return RollupRangeWindow(start: start, end: end);
  }
}

RollupRangeWindow _previousWindowFor(RollupRange range, RollupRangeWindow current) {
  switch (range) {
    case RollupRange.week:
      return RollupRangeWindow(
        start: current.start.subtract(const Duration(days: 7)),
        end: current.end.subtract(const Duration(days: 7)),
      );
    case RollupRange.month:
      final start = DateTime(current.start.year, current.start.month - 1, 1);
      final end = DateTime(current.start.year, current.start.month, 0);
      return RollupRangeWindow(start: start, end: end);
    case RollupRange.year:
      final start = DateTime(current.start.year - 1, 1, 1);
      final end = DateTime(current.start.year - 1, 12, 31);
      return RollupRangeWindow(start: start, end: end);
  }
}

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

String _formatYmd(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

