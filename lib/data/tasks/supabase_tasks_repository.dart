import 'package:supabase_flutter/supabase_flutter.dart';

import 'task.dart';
import 'tasks_repository.dart';

class SupabaseTasksRepository implements TasksRepository {
  SupabaseTasksRepository(this._client);

  final SupabaseClient _client;

  String _requireUserId() {
    final session = _client.auth.currentSession;
    final uid = session?.user.id;
    if (uid == null || uid.isEmpty) {
      throw const AuthException('Not signed in');
    }
    return uid;
  }

  @override
  Future<List<Task>> listForDate({required String ymd}) async {
    final uid = _requireUserId();

    final rows = await _client
        .from('tasks')
        .select('id,user_id,title,type,date,completed,created_at,updated_at')
        .eq('user_id', uid)
        .eq('date', ymd)
        .order('created_at', ascending: true);
    final list = rows as List;
    return [
      for (final row in list)
        Task.fromDbJson(Map<String, Object?>.from(row as Map)),
    ];
  }

  @override
  Future<Task> create({
    required String title,
    required TaskType type,
    required String ymd,
  }) async {
    final uid = _requireUserId();

    final row = await _client
        .from('tasks')
        .insert({
          'user_id': uid,
          'title': title,
          'type': type.dbValue,
          'date': ymd,
          'completed': false,
        })
        .select('id,user_id,title,type,date,completed,created_at,updated_at')
        .single();

    return Task.fromDbJson(Map<String, Object?>.from(row));
  }

  @override
  Future<Task> update({
    required String id,
    String? title,
    TaskType? type,
    bool? completed,
  }) async {
    final _ = _requireUserId();

    final patch = <String, Object?>{};
    if (title != null) patch['title'] = title;
    if (type != null) patch['type'] = type.dbValue;
    if (completed != null) patch['completed'] = completed;

    final row = await _client
        .from('tasks')
        .update(patch)
        .eq('id', id)
        .select('id,user_id,title,type,date,completed,created_at,updated_at')
        .single();

    return Task.fromDbJson(Map<String, Object?>.from(row));
  }

  @override
  Future<void> delete({required String id}) async {
    final _ = _requireUserId();
    await _client.from('tasks').delete().eq('id', id);
  }
}
