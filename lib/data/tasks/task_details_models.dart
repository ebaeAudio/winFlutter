class TaskDetails {
  const TaskDetails({
    required this.taskId,
    this.notes,
    this.nextStep,
    this.estimateMinutes,
    this.actualMinutes,
  });

  final String taskId;
  final String? notes;
  final String? nextStep;
  final int? estimateMinutes;
  final int? actualMinutes;

  TaskDetails copyWith({
    String? notes,
    String? nextStep,
    int? estimateMinutes,
    int? actualMinutes,
  }) {
    return TaskDetails(
      taskId: taskId,
      notes: notes ?? this.notes,
      nextStep: nextStep ?? this.nextStep,
      estimateMinutes: estimateMinutes ?? this.estimateMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
    );
  }

  static TaskDetails empty(String taskId) => TaskDetails(taskId: taskId);

  static TaskDetails fromDbJson(String taskId, Map<String, Object?> json) {
    return TaskDetails(
      taskId: taskId,
      notes: (json['notes'] as String?) ?? '',
      nextStep: (json['next_step'] as String?) ?? '',
      estimateMinutes: (json['estimate_minutes'] as num?)?.toInt(),
      actualMinutes: (json['actual_minutes'] as num?)?.toInt(),
    );
  }
}

class TaskSubtask {
  const TaskSubtask({
    required this.id,
    required this.taskId,
    required this.title,
    required this.completed,
    this.sortOrder,
    this.localId,
  });

  /// In Supabase mode, this is the DB UUID.
  /// In local mode, this is a stable synthetic id.
  final String id;
  final String taskId;
  final String title;
  final bool completed;
  final int? sortOrder;

  /// Local-mode convenience: underlying local subtask id.
  /// (In Supabase mode this is null.)
  final String? localId;

  String get _fallbackLocalId => localId ?? id;

  static TaskSubtask fromDbJson(Map<String, Object?> json) {
    return TaskSubtask(
      id: (json['id'] as String?) ?? '',
      taskId: (json['task_id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      completed: (json['completed'] as bool?) ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt(),
    );
  }

  String get localIdOrId => _fallbackLocalId;
}
