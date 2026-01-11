import 'package:supabase_flutter/supabase_flutter.dart';

import 'all_tasks_models.dart';
import 'all_tasks_repository.dart';
import 'task.dart';
import 'tasks_repository.dart';

class SupabaseAllTasksRepository implements AllTasksRepository {
  SupabaseAllTasksRepository({
    required SupabaseClient client,
    required TasksRepository tasksRepository,
  })  : _client = client,
        _tasksRepository = tasksRepository;

  final SupabaseClient _client;
  final TasksRepository _tasksRepository;

  String _requireUserId() {
    final session = _client.auth.currentSession;
    final uid = session?.user.id;
    if (uid == null || uid.isEmpty) {
      throw const AuthException('Not signed in');
    }
    return uid;
  }

  @override
  Future<List<AllTask>> listAll() async {
    final uid = _requireUserId();

    final rows = await _client
        .from('tasks')
        .select('id,user_id,title,type,date,completed,created_at,updated_at')
        .eq('user_id', uid)
        .order('date', ascending: true)
        .order('created_at', ascending: true);

    final list = rows as List;
    final tasks = <AllTask>[];
    for (final row in list) {
      final t = Task.fromDbJson(Map<String, Object?>.from(row as Map));
      tasks.add(
        AllTask(
          id: t.id,
          title: t.title,
          type: t.type,
          ymd: t.date,
          completed: t.completed,
          createdAtMs: t.createdAt.millisecondsSinceEpoch,
        ),
      );
    }
    return tasks;
  }

  @override
  Future<void> setCompleted({
    required String ymd,
    required String taskId,
    required bool completed,
  }) async {
    await _tasksRepository.update(id: taskId, completed: completed);
  }

  @override
  Future<void> moveToDate({
    required String fromYmd,
    required String toYmd,
    required String taskId,
    required bool resetCompleted,
  }) async {
    await _tasksRepository.update(
      id: taskId,
      ymd: toYmd,
      completed: resetCompleted ? false : null,
    );
  }
}
