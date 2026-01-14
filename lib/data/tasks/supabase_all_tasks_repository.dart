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

    dynamic rows;
    try {
      rows = await _client
          .from('tasks')
          .select(
              'id,user_id,title,goal_date,type,date,completed,in_progress,created_at,updated_at')
          .eq('user_id', uid)
          .order('date', ascending: true)
          .order('created_at', ascending: true);
    } catch (_) {
      try {
        // Back-compat: schema without `goal_date`.
        rows = await _client
            .from('tasks')
            .select(
                'id,user_id,title,type,date,completed,in_progress,created_at,updated_at')
            .eq('user_id', uid)
            .order('date', ascending: true)
            .order('created_at', ascending: true);
      } catch (_) {
        // Back-compat: schema without `in_progress` (and possibly without `goal_date`).
        rows = await _client
            .from('tasks')
            .select('id,user_id,title,type,date,completed,created_at,updated_at')
            .eq('user_id', uid)
            .order('date', ascending: true)
            .order('created_at', ascending: true);
      }
    }

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
          goalYmd: t.goalDate,
          completed: t.completed,
          inProgress: t.inProgress,
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
    await _tasksRepository.update(
      id: taskId,
      completed: completed,
      // Keep invariant: completed implies not in progress.
      inProgress: completed ? false : null,
    );
  }

  @override
  Future<void> setInProgress({
    required String ymd,
    required String taskId,
    required bool inProgress,
  }) async {
    await _tasksRepository.update(
      id: taskId,
      inProgress: inProgress,
      // Keep invariant: in progress implies not completed.
      completed: inProgress ? false : null,
    );
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
      inProgress: resetCompleted ? false : null,
    );
  }
}
