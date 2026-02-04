/// Canonical Task domain model.
///
/// This unifies the previously duplicated `TodayTask` (local/demo mode) and
/// `Task` (Supabase) models.
///
/// - Canonical Focus-v2 field names:
///   - `starterStep` (legacy: `nextStep`)
///   - `estimatedMinutes` (legacy: `estimateMinutes`)
/// - Local JSON parsing supports legacy keys for backward compatibility.
library;

enum TaskType {
  mustWin,
  niceToDo;

  static TaskType fromString(String raw) {
    final normalized = raw.trim().toLowerCase();
    return switch (normalized) {
      // DB values
      'must-win' => TaskType.mustWin,
      'nice-to-do' => TaskType.niceToDo,
      // Enum names / UI values
      'mustwin' => TaskType.mustWin,
      'nice todo' => TaskType.niceToDo,
      'nicetodo' => TaskType.niceToDo,
      // Best-effort fallback
      _ => TaskType.mustWin,
    };
  }

  static TaskType fromDb(String raw) => fromString(raw);

  String get dbValue => switch (this) {
        TaskType.mustWin => 'must-win',
        TaskType.niceToDo => 'nice-to-do',
      };
}

class TaskSubtask {
  const TaskSubtask({
    required this.id,
    required this.title,
    required this.completed,
    required this.createdAt,
  });

  final String id;
  final String title;
  final bool completed;
  final DateTime createdAt;

  int get createdAtMs => createdAt.millisecondsSinceEpoch;

  TaskSubtask copyWith({
    String? title,
    bool? completed,
  }) {
    return TaskSubtask(
      id: id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toLocalJson() => {
        'id': id,
        'title': title,
        'completed': completed,
        'createdAtMs': createdAtMs,
      };

  static TaskSubtask fromLocalJson(Map<String, Object?> json) {
    final createdAtMs = (json['createdAtMs'] as num?)?.toInt();
    return TaskSubtask(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      completed: (json['completed'] as bool?) ?? false,
      createdAt: createdAtMs == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(createdAtMs),
    );
  }
}

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    required this.completed,
    required this.inProgress,
    required this.createdAt,
    this.userId,
    this.details,
    this.goalDate,
    this.starterStep,
    this.estimatedMinutes,
    this.actualMinutes,
    this.subtasks = const [],
    this.deletedAt,
    this.updatedAt,
  });

  /// UUID
  final String id;

  /// UUID (auth.users.id). Null in local/demo mode.
  final String? userId;

  final String title;
  final TaskType type;

  /// Scheduled day (YYYY-MM-DD).
  final String date;

  final bool completed;
  final bool inProgress;

  /// Optional notes/details.
  final String? details;

  /// Optional goal/deadline date (YYYY-MM-DD).
  final String? goalDate;

  /// Focus v2: micro-step scaffolding for task initiation.
  final String? starterStep;

  /// Focus v2: estimate in minutes (optional).
  final int? estimatedMinutes;

  /// Optional actual minutes spent (local-only today UX).
  final int? actualMinutes;

  /// Optional subtasks (local-only today UX).
  final List<TaskSubtask> subtasks;

  /// Soft delete timestamp (local/demo mode only).
  final DateTime? deletedAt;

  final DateTime createdAt;
  final DateTime? updatedAt;

  int get createdAtMs => createdAt.millisecondsSinceEpoch;
  int? get deletedAtMs => deletedAt?.millisecondsSinceEpoch;

  /// Back-compat accessor for older code paths.
  String? get goalYmd => goalDate;

  bool get isDeleted => deletedAt != null;

  Task copyWith({
    String? title,
    TaskType? type,
    String? date,
    bool? completed,
    bool? inProgress,
    Object? details = _unset,
    Object? goalDate = _unset,
    Object? starterStep = _unset,
    Object? estimatedMinutes = _unset,
    Object? actualMinutes = _unset,
    List<TaskSubtask>? subtasks,
    Object? deletedAt = _unset,
    DateTime? createdAt,
    Object? updatedAt = _unset,
    String? userId,
  }) {
    return Task(
      id: id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      type: type ?? this.type,
      date: date ?? this.date,
      completed: completed ?? this.completed,
      inProgress: inProgress ?? this.inProgress,
      details: details == _unset ? this.details : details as String?,
      goalDate: goalDate == _unset ? this.goalDate : goalDate as String?,
      starterStep: starterStep == _unset ? this.starterStep : starterStep as String?,
      estimatedMinutes: estimatedMinutes == _unset
          ? this.estimatedMinutes
          : (estimatedMinutes as num?)?.toInt(),
      actualMinutes: actualMinutes == _unset
          ? this.actualMinutes
          : (actualMinutes as num?)?.toInt(),
      subtasks: subtasks ?? this.subtasks,
      deletedAt: deletedAt == _unset ? this.deletedAt : deletedAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt == _unset ? this.updatedAt : updatedAt as DateTime?,
    );
  }

  /// Parses a task hydrated from the Supabase `tasks` table.
  static Task fromDbJson(Map<String, Object?> json) {
    final createdAtRaw = (json['created_at'] as String?) ?? '';
    final updatedAtRaw = (json['updated_at'] as String?) ?? '';
    return Task(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      details: (json['details'] as String?),
      goalDate: (json['goal_date'] as String?),
      starterStep: (json['starter_step'] as String?),
      estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt(),
      type: TaskType.fromDb((json['type'] as String?) ?? ''),
      date: (json['date'] as String?) ?? '',
      completed: (json['completed'] as bool?) ?? false,
      inProgress: (json['in_progress'] as bool?) ?? false,
      createdAt: DateTime.tryParse(createdAtRaw) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(updatedAtRaw),
    );
  }

  /// Returns a JSON payload suitable for inserts/updates to the Supabase table.
  ///
  /// Note: timestamps are managed by Postgres; we intentionally don't include
  /// `created_at` / `updated_at` here.
  Map<String, Object?> toDbJson() {
    String? trimToNull(String? s) {
      if (s == null) return null;
      final t = s.trim();
      return t.isEmpty ? null : t;
    }

    return <String, Object?>{
      if (userId != null && userId!.trim().isNotEmpty) 'user_id': userId,
      if (id.trim().isNotEmpty) 'id': id,
      'title': title,
      'type': type.dbValue,
      'date': date,
      'completed': completed,
      'in_progress': inProgress,
      'details': trimToNull(details),
      'goal_date': trimToNull(goalDate),
      'starter_step': trimToNull(starterStep),
      'estimated_minutes': estimatedMinutes,
    };
  }

  /// Parses a task from local/demo-mode JSON.
  ///
  /// Supports legacy field names:
  /// - `nextStep` -> `starterStep`
  /// - `estimateMinutes` -> `estimatedMinutes`
  static Task fromLocalJson(
    Map<String, Object?> json, {
    required String fallbackDate,
  }) {
    final rawType = (json['type'] as String?) ?? '';

    final createdAtMs = (json['createdAtMs'] as num?)?.toInt();
    final deletedAtMs = (json['deletedAtMs'] as num?)?.toInt();

    final starterStep =
        (json['starterStep'] as String?) ?? (json['nextStep'] as String?);
    final estimatedMinutes = (json['estimatedMinutes'] as num?)?.toInt() ??
        (json['estimateMinutes'] as num?)?.toInt();

    final rawSubtasks = json['subtasks'];
    final subtasks = <TaskSubtask>[];
    if (rawSubtasks is List) {
      for (final s in rawSubtasks) {
        if (s is Map<String, Object?>) {
          subtasks.add(TaskSubtask.fromLocalJson(s));
        } else if (s is Map) {
          subtasks.add(TaskSubtask.fromLocalJson(Map<String, Object?>.from(s)));
        }
      }
    }

    return Task(
      id: (json['id'] as String?) ?? '',
      userId: null,
      title: (json['title'] as String?) ?? '',
      type: TaskType.fromString(rawType),
      date: (json['date'] as String?) ?? fallbackDate,
      completed: (json['completed'] as bool?) ?? false,
      inProgress: (json['inProgress'] as bool?) ?? (json['in_progress'] as bool?) ?? false,
      createdAt: createdAtMs == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(createdAtMs),
      details: (json['details'] as String?) ?? (json['notes'] as String?),
      goalDate: (json['goalYmd'] as String?) ?? (json['goalDate'] as String?),
      starterStep: starterStep,
      estimatedMinutes: estimatedMinutes,
      actualMinutes: (json['actualMinutes'] as num?)?.toInt(),
      subtasks: subtasks,
      deletedAt: deletedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(deletedAtMs),
    );
  }

  /// Serializes a task for local/demo-mode JSON.
  ///
  /// We intentionally write only canonical keys; older keys are supported via
  /// [fromLocalJson] for backward compatibility.
  Map<String, Object?> toLocalJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'date': date,
        'completed': completed,
        'inProgress': inProgress,
        'createdAtMs': createdAtMs,
        if (details != null) 'details': details,
        if (goalDate != null) 'goalYmd': goalDate,
        if (starterStep != null) 'starterStep': starterStep,
        if (estimatedMinutes != null) 'estimatedMinutes': estimatedMinutes,
        if (actualMinutes != null) 'actualMinutes': actualMinutes,
        if (subtasks.isNotEmpty)
          'subtasks': [for (final s in subtasks) s.toLocalJson()],
        if (deletedAtMs != null) 'deletedAtMs': deletedAtMs,
      };
}

class _Unset {
  const _Unset();
}

const _unset = _Unset();
