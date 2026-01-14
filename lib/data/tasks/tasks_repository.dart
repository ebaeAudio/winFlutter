import 'task.dart';

class TasksRepositoryUnset {
  const TasksRepositoryUnset();
}

const tasksRepositoryUnset = TasksRepositoryUnset();

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
    Object? goalYmd = tasksRepositoryUnset,
    String? starterStep,
    Object? estimatedMinutes = tasksRepositoryUnset,
    TaskType? type,

    /// YYYY-MM-DD
    String? ymd,
    bool? completed,
    bool? inProgress,
  });

  Future<void> delete({required String id});
}
