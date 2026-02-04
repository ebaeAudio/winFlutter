import 'package:supabase_flutter/supabase_flutter.dart';

import 'task.dart';
import 'tasks_schema.dart';
import 'tasks_repository.dart';

class SupabaseTasksRepository implements TasksRepository {
  SupabaseTasksRepository(this._client, this._schema);

  final SupabaseClient _client;
  final TasksSchema _schema;

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
        .select(_schema.taskSelectColumns)
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
        .select(_schema.taskSelectColumns)
        .single();
    return Task.fromDbJson(Map<String, Object?>.from(row));
  }

  @override
  Future<Task> update({
    required String id,
    String? title,
    String? details,
    Object? goalYmd = tasksRepositoryUnset,
    String? starterStep,
    Object? estimatedMinutes = tasksRepositoryUnset,
    TaskType? type,
    String? ymd,
    bool? completed,
    bool? inProgress,
  }) async {
    final _ = _requireUserId();

    final patch = <String, Object?>{};
    if (title != null) patch['title'] = title;
    if (details != null) {
      final trimmed = details.trim();
      patch['details'] = trimmed.isEmpty ? null : trimmed;
    }
    if (goalYmd != tasksRepositoryUnset) {
      if (goalYmd == null) {
        patch['goal_date'] = null;
      } else if (goalYmd is String) {
        final trimmed = goalYmd.trim();
        patch['goal_date'] = trimmed.isEmpty ? null : trimmed;
      } else {
        patch['goal_date'] = goalYmd;
      }
    }
    if (starterStep != null) {
      final trimmed = starterStep.trim();
      patch['starter_step'] = trimmed.isEmpty ? null : trimmed;
    }
    if (estimatedMinutes != tasksRepositoryUnset) {
      patch['estimated_minutes'] = estimatedMinutes;
    }
    if (type != null) patch['type'] = type.dbValue;
    if (ymd != null) patch['date'] = ymd;
    if (completed != null) patch['completed'] = completed;
    if (inProgress != null) patch['in_progress'] = inProgress;

    final filteredPatch = _schema.filterUpdatePatch(
      patch,
      attemptedGoalDate: goalYmd != tasksRepositoryUnset,
      attemptedInProgress: inProgress != null,
    );

    if (filteredPatch.isEmpty) {
      final row = await _client
          .from('tasks')
          .select(_schema.taskSelectColumns)
          .eq('id', id)
          .single();
      return Task.fromDbJson(Map<String, Object?>.from(row));
    }

    final row = await _client
        .from('tasks')
        .update(filteredPatch)
        .eq('id', id)
        .select(_schema.taskSelectColumns)
        .single();

    return Task.fromDbJson(Map<String, Object?>.from(row));
  }

  @override
  Future<void> delete({required String id}) async {
    final _ = _requireUserId();
    await _client.from('tasks').delete().eq('id', id);
  }

  @override
  Future<void> hardDelete({required String id}) async {
    // Supabase doesn't support soft delete, so hardDelete is the same as delete.
    await delete(id: id);
  }

  @override
  Future<Task> restore({required String id}) async {
    // Supabase doesn't have soft delete - this shouldn't be called.
    throw UnsupportedError('Soft delete is not supported in Supabase mode.');
  }

  @override
  Future<bool> supportsSoftDelete() async {
    // Supabase backend doesn't have a deleted_at column yet.
    return false;
  }
}
