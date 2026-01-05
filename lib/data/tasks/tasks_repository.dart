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
    TaskType? type,
    bool? completed,
  });

  Future<void> delete({required String id});
}
