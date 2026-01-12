import 'package:supabase_flutter/supabase_flutter.dart';

import 'task.dart';
import 'tasks_repository.dart';

class SupabaseTasksRepository implements TasksRepository {
  SupabaseTasksRepository(this._client);

  final SupabaseClient _client;

  static const _selectBase = 'id,user_id,title,type,date,completed,created_at,updated_at';
  static const _selectWithDetails = 'id,user_id,title,details,type,date,completed,created_at,updated_at';
  static const _selectWithFocusV2 =
      'id,user_id,title,details,starter_step,estimated_minutes,type,date,completed,created_at,updated_at';

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

    dynamic rows;
    try {
      rows = await _client
          .from('tasks')
          .select(_selectWithFocusV2)
          .eq('user_id', uid)
          .eq('date', ymd)
          .order('created_at', ascending: true);
    } catch (_) {
      try {
        // Back-compat for older schemas where Focus v2 fields aren't migrated yet.
        rows = await _client
            .from('tasks')
            .select(_selectWithDetails)
            .eq('user_id', uid)
            .eq('date', ymd)
            .order('created_at', ascending: true);
      } catch (_) {
        // Back-compat for older schemas where `details` isn't migrated yet.
        rows = await _client
            .from('tasks')
            .select(_selectBase)
            .eq('user_id', uid)
            .eq('date', ymd)
            .order('created_at', ascending: true);
      }
    }
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

    dynamic row;
    try {
      row = await _client
          .from('tasks')
          .insert({
            'user_id': uid,
            'title': title,
            'type': type.dbValue,
            'date': ymd,
            'completed': false,
          })
          .select(_selectWithFocusV2)
          .single();
    } catch (_) {
      try {
        // Back-compat for older schemas where Focus v2 fields aren't migrated yet.
        row = await _client
            .from('tasks')
            .insert({
              'user_id': uid,
              'title': title,
              'type': type.dbValue,
              'date': ymd,
              'completed': false,
            })
            .select(_selectWithDetails)
            .single();
      } catch (_) {
        // Back-compat for older schemas where `details` isn't migrated yet.
        row = await _client
            .from('tasks')
            .insert({
              'user_id': uid,
              'title': title,
              'type': type.dbValue,
              'date': ymd,
              'completed': false,
            })
            .select(_selectBase)
            .single();
      }
    }

    return Task.fromDbJson(Map<String, Object?>.from(row));
  }

  @override
  Future<Task> update({
    required String id,
    String? title,
    String? details,
    String? starterStep,
    Object? estimatedMinutes = tasksRepositoryUnset,
    TaskType? type,
    String? ymd,
    bool? completed,
  }) async {
    final _ = _requireUserId();

    final patch = <String, Object?>{};
    if (title != null) patch['title'] = title;
    if (details != null) {
      final trimmed = details.trim();
      patch['details'] = trimmed.isEmpty ? null : trimmed;
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

    dynamic row;
    try {
      row = await _client
          .from('tasks')
          .update(patch)
          .eq('id', id)
          .select(_selectWithFocusV2)
          .single();
    } catch (_) {
      try {
        // Back-compat for older schemas where Focus v2 fields aren't migrated yet.
        row = await _client
            .from('tasks')
            .update(patch..remove('starter_step')..remove('estimated_minutes'))
            .eq('id', id)
            .select(_selectWithDetails)
            .single();
      } catch (_) {
        // Back-compat for older schemas where `details` isn't migrated yet.
        row = await _client
            .from('tasks')
            .update(patch..remove('details')..remove('starter_step')..remove('estimated_minutes'))
            .eq('id', id)
            .select(_selectBase)
            .single();
      }
    }

    return Task.fromDbJson(Map<String, Object?>.from(row));
  }

  @override
  Future<void> delete({required String id}) async {
    final _ = _requireUserId();
    await _client.from('tasks').delete().eq('id', id);
  }
}
