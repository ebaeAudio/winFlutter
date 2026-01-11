import 'all_tasks_models.dart';

abstract interface class AllTasksRepository {
  Future<List<AllTask>> listAll();

  Future<void> setCompleted({
    required String ymd,
    required String taskId,
    required bool completed,
  });

  Future<void> moveToDate({
    required String fromYmd,
    required String toYmd,
    required String taskId,
    required bool resetCompleted,
  });
}
