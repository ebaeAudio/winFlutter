/// Represents which columns exist in the `public.tasks` table.
///
/// This is used to avoid cascading try/catch fallbacks inside repositories by:
/// - Detecting column presence once at app startup
/// - Emitting a single SELECT clause appropriate for the detected schema
/// - Filtering update patches to only include supported columns
class TasksSchema {
  const TasksSchema({
    required this.hasDetails,
    required this.hasGoalDate,
    required this.hasInProgress,
    required this.hasStarterStep,
    required this.hasEstimatedMinutes,
  });

  /// `tasks.details`
  final bool hasDetails;

  /// `tasks.goal_date`
  final bool hasGoalDate;

  /// `tasks.in_progress`
  final bool hasInProgress;

  /// `tasks.starter_step`
  final bool hasStarterStep;

  /// `tasks.estimated_minutes`
  final bool hasEstimatedMinutes;

  static const _baseColumns =
      'id,user_id,title,type,date,completed,created_at,updated_at';

  /// Columns to hydrate `Task` objects as fully as the schema supports.
  String get taskSelectColumns {
    final cols = <String>[
      'id',
      'user_id',
      'title',
      if (hasDetails) 'details',
      if (hasStarterStep) 'starter_step',
      if (hasEstimatedMinutes) 'estimated_minutes',
      if (hasGoalDate) 'goal_date',
      'type',
      'date',
      'completed',
      if (hasInProgress) 'in_progress',
      'created_at',
      'updated_at',
    ];
    return cols.join(',');
  }

  /// Minimal columns needed for All Tasks lists.
  ///
  /// This intentionally excludes `details` and Focus-v2 fields to reduce
  /// bandwidth when listing across many dates.
  String get allTasksSelectColumns {
    if (!hasGoalDate && !hasInProgress) return _baseColumns;
    final cols = <String>[
      'id',
      'user_id',
      'title',
      if (hasGoalDate) 'goal_date',
      'type',
      'date',
      'completed',
      if (hasInProgress) 'in_progress',
      'created_at',
      'updated_at',
    ];
    return cols.join(',');
  }

  /// Applies schema constraints to a patch destined for `.update(...)`.
  ///
  /// - If the caller attempts to set a column that doesn't exist (goal_date,
  ///   in_progress), we throw a deterministic error instructing how to migrate.
  /// - Optional fields (`details`, Focus v2 fields) are silently removed if the
  ///   column doesn't exist to keep back-compat (these features are optional).
  Map<String, Object?> filterUpdatePatch(
    Map<String, Object?> patch, {
    required bool attemptedGoalDate,
    required bool attemptedInProgress,
  }) {
    final filtered = Map<String, Object?>.from(patch);

    if (!hasDetails) filtered.remove('details');
    if (!hasStarterStep) filtered.remove('starter_step');
    if (!hasEstimatedMinutes) filtered.remove('estimated_minutes');

    if (attemptedGoalDate && !hasGoalDate) {
      throw StateError(
        'Your Supabase schema is missing `tasks.goal_date`. Apply `supabase/migrations/20260118_000001_task_goal_date.sql`, then restart the app.',
      );
    }
    if (!hasGoalDate) filtered.remove('goal_date');

    if (attemptedInProgress && !hasInProgress) {
      throw StateError(
        'Your Supabase schema is missing `tasks.in_progress`. Apply `supabase/migrations/20260112000000_add_tasks_in_progress.sql`, then restart the app.',
      );
    }
    if (!hasInProgress) filtered.remove('in_progress');

    return filtered;
  }
}

