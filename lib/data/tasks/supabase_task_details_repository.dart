import 'package:supabase_flutter/supabase_flutter.dart';

import 'task_details_models.dart';
import 'task_details_repository.dart';

class SupabaseTaskDetailsRepository implements TaskDetailsRepository {
  SupabaseTaskDetailsRepository(this._client);

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
  Future<TaskDetails> getDetails({required String taskId}) async {
    final uid = _requireUserId();
    try {
      final row = await _client
          .from('tasks')
          .select('id,notes,estimate_minutes,actual_minutes,next_step')
          .eq('id', taskId)
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) return TaskDetails.empty(taskId);
      return TaskDetails.fromDbJson(taskId, Map<String, Object?>.from(row));
    } catch (_) {
      // If the schema isn't migrated yet (missing columns), fall back gracefully.
      return TaskDetails.empty(taskId);
    }
  }

  @override
  Future<TaskDetails> updateDetails({
    required String taskId,
    String? notes,
    String? nextStep,
    int? estimateMinutes,
    int? actualMinutes,
  }) async {
    final uid = _requireUserId();
    final patch = <String, Object?>{};
    if (notes != null) patch['notes'] = notes;
    if (nextStep != null) patch['next_step'] = nextStep;
    if (estimateMinutes != null) patch['estimate_minutes'] = estimateMinutes;
    if (actualMinutes != null) patch['actual_minutes'] = actualMinutes;

    final row = await _client
        .from('tasks')
        .update(patch)
        .eq('id', taskId)
        .eq('user_id', uid)
        .select('id,notes,estimate_minutes,actual_minutes,next_step')
        .single();

    return TaskDetails.fromDbJson(taskId, Map<String, Object?>.from(row));
  }

  @override
  Future<List<TaskSubtask>> listSubtasks({required String taskId}) async {
    _requireUserId();
    try {
      final rows = await _client
          .from('task_subtasks')
          .select('id,task_id,title,completed,sort_order')
          .eq('task_id', taskId)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true);
      final list = rows as List;
      return [
        for (final row in list)
          TaskSubtask.fromDbJson(Map<String, Object?>.from(row as Map)),
      ];
    } catch (_) {
      // If the schema isn't migrated yet (missing table/columns), fall back.
      return const [];
    }
  }

  @override
  Future<TaskSubtask> createSubtask({
    required String taskId,
    required String title,
  }) async {
    _requireUserId();
    final row = await _client
        .from('task_subtasks')
        .insert({
          'task_id': taskId,
          'title': title,
          'completed': false,
        })
        .select('id,task_id,title,completed,sort_order')
        .single();
    return TaskSubtask.fromDbJson(Map<String, Object?>.from(row));
  }

  @override
  Future<TaskSubtask> setSubtaskCompleted({
    required String subtaskId,
    required bool completed,
  }) async {
    _requireUserId();
    final row = await _client
        .from('task_subtasks')
        .update({'completed': completed})
        .eq('id', subtaskId)
        .select('id,task_id,title,completed,sort_order')
        .single();
    return TaskSubtask.fromDbJson(Map<String, Object?>.from(row));
  }

  @override
  Future<void> deleteSubtask({required String subtaskId}) async {
    _requireUserId();
    await _client.from('task_subtasks').delete().eq('id', subtaskId);
  }
}


