import 'task.dart';

abstract interface class TasksRepository {
  Future<List<Task>> listForDate({required String ymd});

  Future<Task> create({
    required String title,
    required TaskType type,
    required String ymd,
  });

  Future<Task> update({
    required String id,
    String? title,
    String? details,
    TaskType? type,

    /// YYYY-MM-DD
    String? ymd,
    bool? completed,
  });

  Future<void> delete({required String id});
}
