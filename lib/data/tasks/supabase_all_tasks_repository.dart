import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'all_tasks_models.dart';
import 'all_tasks_repository.dart';
import '../paginated_result.dart';
import 'task.dart';
import 'tasks_schema.dart';
import 'tasks_repository.dart';

class SupabaseAllTasksRepository implements AllTasksRepository {
  SupabaseAllTasksRepository({
    required SupabaseClient client,
    required TasksRepository tasksRepository,
    required TasksSchema schema,
  })  : _client = client,
        _tasksRepository = tasksRepository,
        _schema = schema;

  final SupabaseClient _client;
  final TasksRepository _tasksRepository;
  final TasksSchema _schema;

  String _requireUserId() {
    final session = _client.auth.currentSession;
    final uid = session?.user.id;
    if (uid == null || uid.isEmpty) {
      throw const AuthException('Not signed in');
    }
    return uid;
  }

  static int _decodeCursor(String? cursor) {
    final raw = (cursor ?? '').trim();
    if (raw.isEmpty) return 0;
    try {
      final decoded = utf8.decode(base64Url.decode(raw));
      return int.tryParse(decoded) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static String _encodeCursor(int offset) {
    return base64Url.encode(utf8.encode(offset.toString()));
  }

  @override
  Future<PaginatedResult<AllTask>> listAll({
    int limit = 50,
    String? cursor,
  }) async {
    final uid = _requireUserId();

    final offset = _decodeCursor(cursor);
    final safeLimit = limit < 1 ? 1 : limit;

    final rows = await _client
        .from('tasks')
        .select(_schema.allTasksSelectColumns)
        .eq('user_id', uid)
        .order('date', ascending: true)
        .order('created_at', ascending: true)
        .range(offset, offset + safeLimit - 1);
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

    final hasMore = list.length >= safeLimit;
    final nextCursor =
        hasMore ? _encodeCursor(offset + list.length) : null;
    return PaginatedResult(items: tasks, hasMore: hasMore, nextCursor: nextCursor);
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
