import 'package:supabase_flutter/supabase_flutter.dart';

import 'task.dart';
import 'tasks_repository.dart';

class SupabaseTasksRepository implements TasksRepository {
  SupabaseTasksRepository(this._client);

  final SupabaseClient _client;

  static bool _isMissingColumn(Object e, {required String columnName}) {
    if (e is! PostgrestException) return false;
    final msg = e.message.toLowerCase();
    final details = (e.details?.toString() ?? '').toLowerCase();
    final hint = (e.hint?.toString() ?? '').toLowerCase();
    final combined = '$msg $details $hint';
    final col = columnName.toLowerCase();
    if (!combined.contains(col)) return false;
    return combined.contains('does not exist') ||
        combined.contains('could not find the column') ||
        (combined.contains('column') && combined.contains('not found'));
  }

  static const _selectBase =
      'id,user_id,title,type,date,completed,in_progress,created_at,updated_at';
  static const _selectBaseWithGoalDate =
      'id,user_id,title,goal_date,type,date,completed,in_progress,created_at,updated_at';
  static const _selectWithDetails =
      'id,user_id,title,details,type,date,completed,in_progress,created_at,updated_at';
  static const _selectWithDetailsWithGoalDate =
      'id,user_id,title,details,goal_date,type,date,completed,in_progress,created_at,updated_at';
  static const _selectWithFocusV2 =
      'id,user_id,title,details,starter_step,estimated_minutes,type,date,completed,in_progress,created_at,updated_at';
  static const _selectWithFocusV2WithGoalDate =
      'id,user_id,title,details,starter_step,estimated_minutes,goal_date,type,date,completed,in_progress,created_at,updated_at';

  // Legacy schema selects (pre `in_progress`).
  static const _selectBaseLegacy =
      'id,user_id,title,type,date,completed,created_at,updated_at';
  static const _selectBaseLegacyWithGoalDate =
      'id,user_id,title,goal_date,type,date,completed,created_at,updated_at';
  static const _selectWithDetailsLegacy =
      'id,user_id,title,details,type,date,completed,created_at,updated_at';
  static const _selectWithDetailsLegacyWithGoalDate =
      'id,user_id,title,details,goal_date,type,date,completed,created_at,updated_at';
  static const _selectWithFocusV2Legacy =
      'id,user_id,title,details,starter_step,estimated_minutes,type,date,completed,created_at,updated_at';
  static const _selectWithFocusV2LegacyWithGoalDate =
      'id,user_id,title,details,starter_step,estimated_minutes,goal_date,type,date,completed,created_at,updated_at';

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
          .select(_selectWithFocusV2WithGoalDate)
          .eq('user_id', uid)
          .eq('date', ymd)
          .order('created_at', ascending: true);
    } catch (_) {
      try {
        rows = await _client
            .from('tasks')
            .select(_selectWithFocusV2)
            .eq('user_id', uid)
            .eq('date', ymd)
            .order('created_at', ascending: true);
      } catch (_) {
        try {
        // Prefer a schema that still includes `in_progress` (even if Focus v2
        // fields aren't migrated yet).
        rows = await _client
            .from('tasks')
            .select(_selectWithDetailsWithGoalDate)
            .eq('user_id', uid)
            .eq('date', ymd)
            .order('created_at', ascending: true);
        } catch (_) {
          try {
            // Prefer a schema that still includes `in_progress` (even if Focus v2
            // fields aren't migrated yet).
            rows = await _client
                .from('tasks')
                .select(_selectWithDetails)
                .eq('user_id', uid)
                .eq('date', ymd)
                .order('created_at', ascending: true);
          } catch (_) {
            try {
              // Prefer a schema that still includes `in_progress` (even if `details`
              // isn't migrated yet).
              rows = await _client
                  .from('tasks')
                  .select(_selectBaseWithGoalDate)
                  .eq('user_id', uid)
                  .eq('date', ymd)
                  .order('created_at', ascending: true);
            } catch (_) {
              try {
                // Prefer a schema that still includes `in_progress` (even if `details`
                // isn't migrated yet).
                rows = await _client
                    .from('tasks')
                    .select(_selectBase)
                    .eq('user_id', uid)
                    .eq('date', ymd)
                    .order('created_at', ascending: true);
              } catch (_) {
                try {
            // Back-compat: schema exists but without `in_progress`.
            rows = await _client
                .from('tasks')
                .select(_selectWithFocusV2LegacyWithGoalDate)
                .eq('user_id', uid)
                .eq('date', ymd)
                .order('created_at', ascending: true);
                } catch (_) {
                  try {
                    // Back-compat: schema exists but without `in_progress`.
                    rows = await _client
                        .from('tasks')
                        .select(_selectWithFocusV2Legacy)
                        .eq('user_id', uid)
                        .eq('date', ymd)
                        .order('created_at', ascending: true);
                  } catch (_) {
                    try {
                      // Back-compat: no Focus v2 fields and no `in_progress`.
                      rows = await _client
                          .from('tasks')
                          .select(_selectWithDetailsLegacyWithGoalDate)
                          .eq('user_id', uid)
                          .eq('date', ymd)
                          .order('created_at', ascending: true);
                    } catch (_) {
                      try {
                        // Back-compat: no Focus v2 fields and no `in_progress`.
                        rows = await _client
                            .from('tasks')
                            .select(_selectWithDetailsLegacy)
                            .eq('user_id', uid)
                            .eq('date', ymd)
                            .order('created_at', ascending: true);
                      } catch (_) {
                        try {
                          // Oldest schema fallback.
                          rows = await _client
                              .from('tasks')
                              .select(_selectBaseLegacyWithGoalDate)
                              .eq('user_id', uid)
                              .eq('date', ymd)
                              .order('created_at', ascending: true);
                        } catch (_) {
                          // Oldest schema fallback.
                          rows = await _client
                              .from('tasks')
                              .select(_selectBaseLegacy)
                              .eq('user_id', uid)
                              .eq('date', ymd)
                              .order('created_at', ascending: true);
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
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
          .select(_selectWithFocusV2WithGoalDate)
          .single();
    } catch (_) {
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
        // Prefer a schema that still includes `in_progress` (even if Focus v2
        // fields aren't migrated yet).
        row = await _client
            .from('tasks')
            .insert({
              'user_id': uid,
              'title': title,
              'type': type.dbValue,
              'date': ymd,
              'completed': false,
            })
            .select(_selectWithDetailsWithGoalDate)
            .single();
        } catch (_) {
          try {
            // Prefer a schema that still includes `in_progress` (even if Focus v2
            // fields aren't migrated yet).
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
            try {
              // Prefer a schema that still includes `in_progress` (even if `details`
              // isn't migrated yet).
              row = await _client
                  .from('tasks')
                  .insert({
                    'user_id': uid,
                    'title': title,
                    'type': type.dbValue,
                    'date': ymd,
                    'completed': false,
                  })
                  .select(_selectBaseWithGoalDate)
                  .single();
            } catch (_) {
              try {
                // Prefer a schema that still includes `in_progress` (even if `details`
                // isn't migrated yet).
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
              } catch (_) {
                try {
            // Back-compat: schema exists but without `in_progress`.
            row = await _client
                .from('tasks')
                .insert({
                  'user_id': uid,
                  'title': title,
                  'type': type.dbValue,
                  'date': ymd,
                  'completed': false,
                })
                .select(_selectWithFocusV2LegacyWithGoalDate)
                .single();
                } catch (_) {
                  try {
                    // Back-compat: schema exists but without `in_progress`.
                    row = await _client
                        .from('tasks')
                        .insert({
                          'user_id': uid,
                          'title': title,
                          'type': type.dbValue,
                          'date': ymd,
                          'completed': false,
                        })
                        .select(_selectWithFocusV2Legacy)
                        .single();
                  } catch (_) {
                    try {
                      // Back-compat: no Focus v2 fields and no `in_progress`.
                      row = await _client
                          .from('tasks')
                          .insert({
                            'user_id': uid,
                            'title': title,
                            'type': type.dbValue,
                            'date': ymd,
                            'completed': false,
                          })
                          .select(_selectWithDetailsLegacyWithGoalDate)
                          .single();
                    } catch (_) {
                      try {
                        // Back-compat: no Focus v2 fields and no `in_progress`.
                        row = await _client
                            .from('tasks')
                            .insert({
                              'user_id': uid,
                              'title': title,
                              'type': type.dbValue,
                              'date': ymd,
                              'completed': false,
                            })
                            .select(_selectWithDetailsLegacy)
                            .single();
                      } catch (_) {
                        try {
                          // Oldest schema fallback.
                          row = await _client
                              .from('tasks')
                              .insert({
                                'user_id': uid,
                                'title': title,
                                'type': type.dbValue,
                                'date': ymd,
                                'completed': false,
                              })
                              .select(_selectBaseLegacyWithGoalDate)
                              .single();
                        } catch (_) {
                          // Oldest schema fallback.
                          row = await _client
                              .from('tasks')
                              .insert({
                                'user_id': uid,
                                'title': title,
                                'type': type.dbValue,
                                'date': ymd,
                                'completed': false,
                              })
                              .select(_selectBaseLegacy)
                              .single();
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

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

    dynamic row;
    try {
      row = await _client
          .from('tasks')
          .update(patch)
          .eq('id', id)
          .select(_selectWithFocusV2WithGoalDate)
          .single();
    } catch (e) {
      if (inProgress != null && _isMissingColumn(e, columnName: 'in_progress')) {
        throw StateError(
          'Your Supabase schema is missing `tasks.in_progress`. Apply `supabase/migrations/20260112000000_add_tasks_in_progress.sql`, then restart the app.',
        );
      }
      if (goalYmd != tasksRepositoryUnset &&
          _isMissingColumn(e, columnName: 'goal_date')) {
        throw StateError(
          'Your Supabase schema is missing `tasks.goal_date`. Apply `supabase/migrations/20260112_000002_task_goal_date.sql`, then restart the app.',
        );
      }
      try {
        row = await _client
            .from('tasks')
            .update(patch)
            .eq('id', id)
            .select(_selectWithFocusV2)
            .single();
      } catch (_) {
        try {
        // Prefer a schema that still includes `in_progress` (even if Focus v2
        // fields aren't migrated yet).
        row = await _client
            .from('tasks')
            .update(patch)
            .eq('id', id)
            .select(_selectWithDetailsWithGoalDate)
            .single();
        } catch (_) {
          try {
            row = await _client
                .from('tasks')
                .update(patch)
                .eq('id', id)
                .select(_selectWithDetails)
                .single();
          } catch (_) {
            try {
              // Prefer a schema that still includes `in_progress` (even if `details`
              // isn't migrated yet).
              row = await _client
                  .from('tasks')
                  .update(patch
                    ..remove('details')
                    ..remove('starter_step')
                    ..remove('estimated_minutes'))
                  .eq('id', id)
                  .select(_selectBaseWithGoalDate)
                  .single();
            } catch (_) {
              try {
                // Prefer a schema that still includes `in_progress` (even if `details`
                // isn't migrated yet).
                row = await _client
                    .from('tasks')
                    .update(patch
                      ..remove('details')
                      ..remove('starter_step')
                      ..remove('estimated_minutes'))
                    .eq('id', id)
                    .select(_selectBase)
                    .single();
              } catch (_) {
                try {
            // Back-compat: schema exists but without `in_progress`.
            row = await _client
                .from('tasks')
                .update(patch..remove('in_progress'))
                .eq('id', id)
                .select(_selectWithFocusV2LegacyWithGoalDate)
                .single();
                } catch (_) {
                  try {
                    // Back-compat: schema exists but without `in_progress`.
                    row = await _client
                        .from('tasks')
                        .update(patch..remove('in_progress'))
                        .eq('id', id)
                        .select(_selectWithFocusV2Legacy)
                        .single();
                  } catch (_) {
                    try {
                      // Back-compat: no Focus v2 fields and no `in_progress`.
                      row = await _client
                          .from('tasks')
                          .update(patch
                            ..remove('details')
                            ..remove('starter_step')
                            ..remove('estimated_minutes')
                            ..remove('in_progress'))
                          .eq('id', id)
                          .select(_selectWithDetailsLegacyWithGoalDate)
                          .single();
                    } catch (_) {
                      try {
                        // Back-compat: no Focus v2 fields and no `in_progress`.
                        row = await _client
                            .from('tasks')
                            .update(patch
                              ..remove('details')
                              ..remove('starter_step')
                              ..remove('estimated_minutes')
                              ..remove('in_progress'))
                            .eq('id', id)
                            .select(_selectWithDetailsLegacy)
                            .single();
                      } catch (_) {
                        try {
                          // Oldest schema fallback.
                          row = await _client
                              .from('tasks')
                              .update(patch
                                ..remove('details')
                                ..remove('starter_step')
                                ..remove('estimated_minutes')
                                ..remove('in_progress'))
                              .eq('id', id)
                              .select(_selectBaseLegacyWithGoalDate)
                              .single();
                        } catch (_) {
                          // Oldest schema fallback.
                          row = await _client
                              .from('tasks')
                              .update(patch
                                ..remove('details')
                                ..remove('starter_step')
                                ..remove('estimated_minutes')
                                ..remove('in_progress'))
                              .eq('id', id)
                              .select(_selectBaseLegacy)
                              .single();
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
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
