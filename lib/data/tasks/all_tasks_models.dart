import 'task.dart';

/// A lightweight, cross-mode task shape for the “All Tasks” overview screen.
class AllTask {
  const AllTask({
    required this.id,
    required this.title,
    required this.type,
    required this.ymd,
    required this.goalYmd,
    required this.completed,
    required this.inProgress,
    required this.createdAtMs,
    this.snoozedUntil,
  });

  final String id;
  final String title;
  final TaskType type;

  /// YYYY-MM-DD
  final String ymd;

  /// Optional goal/deadline date (YYYY-MM-DD).
  final String? goalYmd;

  final bool completed;
  final bool inProgress;

  /// Best-effort timestamp for stable sorting.
  final int createdAtMs;

  /// Optional snooze time - task is hidden from zombie alerts until this time.
  final DateTime? snoozedUntil;
}
