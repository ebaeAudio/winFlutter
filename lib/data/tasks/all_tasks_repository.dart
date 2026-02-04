import 'all_tasks_models.dart';
import '../paginated_result.dart';

abstract interface class AllTasksRepository {
  Future<PaginatedResult<AllTask>> listAll({
    int limit = 50,
    String? cursor,
  });

  Future<void> setCompleted({
    required String ymd,
    required String taskId,
    required bool completed,
  });

  Future<void> setInProgress({
    required String ymd,
    required String taskId,
    required bool inProgress,
  });

  Future<void> moveToDate({
    required String fromYmd,
    required String toYmd,
    required String taskId,
    required bool resetCompleted,
  });
}
