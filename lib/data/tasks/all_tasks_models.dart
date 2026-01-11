import 'task.dart';

/// A lightweight, cross-mode task shape for the “All Tasks” overview screen.
class AllTask {
  const AllTask({
    required this.id,
    required this.title,
    required this.type,
    required this.ymd,
    required this.completed,
    required this.createdAtMs,
  });

  final String id;
  final String title;
  final TaskType type;

  /// YYYY-MM-DD
  final String ymd;

  final bool completed;

  /// Best-effort timestamp for stable sorting.
  final int createdAtMs;
}
