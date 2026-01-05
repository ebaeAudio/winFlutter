import '../features/today/today_models.dart';

String? matchTaskIdByTitle(List<TodayTask> tasks, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return null;

  for (final t in tasks) {
    if (t.title.trim().toLowerCase() == q) return t.id;
  }

  final matches = <TodayTask>[];
  for (final t in tasks) {
    if (t.title.trim().toLowerCase().contains(q)) matches.add(t);
  }
  if (matches.isEmpty) return null;
  matches.sort((a, b) => a.title.length.compareTo(b.title.length));
  return matches.first.id;
}

String? matchHabitIdByName(List<TodayHabit> habits, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return null;

  for (final h in habits) {
    if (h.name.trim().toLowerCase() == q) return h.id;
  }

  final matches = <TodayHabit>[];
  for (final h in habits) {
    if (h.name.trim().toLowerCase().contains(q)) matches.add(h);
  }
  if (matches.isEmpty) return null;
  matches.sort((a, b) => a.name.length.compareTo(b.name.length));
  return matches.first.id;
}


