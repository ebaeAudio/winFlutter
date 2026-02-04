import 'package:supabase_flutter/supabase_flutter.dart';

import 'tasks_schema.dart';

abstract interface class TasksSchemaProbe {
  Future<bool> hasColumn(String columnName);
}

class SupabaseTasksSchemaProbe implements TasksSchemaProbe {
  SupabaseTasksSchemaProbe(this._client);

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

  static bool _isMissingTable(Object e) {
    if (e is! PostgrestException) return false;
    final msg = e.message.toLowerCase();
    final details = (e.details?.toString() ?? '').toLowerCase();
    final combined = '$msg $details';
    return combined.contains('relation') && combined.contains('does not exist');
  }

  @override
  Future<bool> hasColumn(String columnName) async {
    try {
      // Any LIMIT works; we just want a cheap schema-level failure if missing.
      await _client.from('tasks').select(columnName).limit(1);
      return true;
    } catch (e) {
      if (_isMissingTable(e)) {
        throw StateError(
          'Your Supabase schema is missing the `tasks` table. Apply the core migrations in `supabase/migrations/`, then restart the app.',
        );
      }
      if (_isMissingColumn(e, columnName: columnName)) return false;
      rethrow;
    }
  }
}

class TasksSchemaDetector {
  static Future<TasksSchema> detect(
    SupabaseClient client, {
    TasksSchemaProbe? probe,
  }) async {
    final p = probe ?? SupabaseTasksSchemaProbe(client);

    // We keep this probing minimal (5 queries once at startup), but still
    // robust: columns can be independently present/missing during migrations.
    final hasDetails = await p.hasColumn('details');
    final hasGoalDate = await p.hasColumn('goal_date');
    final hasInProgress = await p.hasColumn('in_progress');
    final hasStarterStep = await p.hasColumn('starter_step');
    final hasEstimatedMinutes = await p.hasColumn('estimated_minutes');

    return TasksSchema(
      hasDetails: hasDetails,
      hasGoalDate: hasGoalDate,
      hasInProgress: hasInProgress,
      hasStarterStep: hasStarterStep,
      hasEstimatedMinutes: hasEstimatedMinutes,
    );
  }
}

