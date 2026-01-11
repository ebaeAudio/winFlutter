enum TaskType {
  mustWin,
  niceToDo;

  static TaskType fromDb(String raw) {
    final normalized = raw.trim().toLowerCase();
    return switch (normalized) {
      'must-win' => TaskType.mustWin,
      'nice-to-do' => TaskType.niceToDo,
      _ => TaskType.mustWin,
    };
  }

  String get dbValue => switch (this) {
        TaskType.mustWin => 'must-win',
        TaskType.niceToDo => 'nice-to-do',
      };
}

class Task {
  const Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.details,
    required this.type,
    required this.date,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
  });

  /// UUID
  final String id;

  /// UUID (auth.users.id)
  final String userId;

  final String title;
  final String? details;
  final TaskType type;

  /// YYYY-MM-DD
  final String date;

  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;

  static Task fromDbJson(Map<String, Object?> json) {
    final createdAtRaw = (json['created_at'] as String?) ?? '';
    final updatedAtRaw = (json['updated_at'] as String?) ?? '';
    return Task(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      details: (json['details'] as String?),
      type: TaskType.fromDb((json['type'] as String?) ?? ''),
      date: (json['date'] as String?) ?? '',
      completed: (json['completed'] as bool?) ?? false,
      createdAt: DateTime.tryParse(createdAtRaw) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(updatedAtRaw) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
