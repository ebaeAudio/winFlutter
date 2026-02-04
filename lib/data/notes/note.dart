import 'dart:convert';

enum NoteType {
  note,
  project,
  daily,
  inbox;

  static NoteType fromDb(String raw) {
    final normalized = raw.trim().toLowerCase();
    return switch (normalized) {
      'note' => NoteType.note,
      'project' => NoteType.project,
      'daily' => NoteType.daily,
      'inbox' => NoteType.inbox,
      _ => NoteType.note,
    };
  }

  String get dbValue => switch (this) {
        NoteType.note => 'note',
        NoteType.project => 'project',
        NoteType.daily => 'daily',
        NoteType.inbox => 'inbox',
      };
}

class ProjectData {
  const ProjectData({
    this.goal,
    this.status,
    this.nextActions = const [],
    this.resources = const [],
  });

  final String? goal;
  final String? status; // active, on-hold, completed, archived
  final List<String> nextActions;
  final List<String> resources;

  ProjectData copyWith({
    String? goal,
    String? status,
    List<String>? nextActions,
    List<String>? resources,
    bool clearGoal = false,
    bool clearStatus = false,
  }) {
    return ProjectData(
      goal: clearGoal ? null : (goal ?? this.goal),
      status: clearStatus ? null : (status ?? this.status),
      nextActions: nextActions ?? this.nextActions,
      resources: resources ?? this.resources,
    );
  }

  Map<String, Object?> toJson() => {
        'goal': goal,
        'status': status,
        'nextActions': nextActions,
        'resources': resources,
      };

  static ProjectData? fromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    final rawNextActions = json['nextActions'];
    final rawResources = json['resources'];
    return ProjectData(
      goal: json['goal'] as String?,
      status: json['status'] as String?,
      nextActions: rawNextActions is List
          ? [
              for (final item in rawNextActions)
                if (item is String) item,
            ]
          : [],
      resources: rawResources is List
          ? [
              for (final item in rawResources)
                if (item is String) item,
            ]
          : [],
    );
  }

  static ProjectData? fromDbJson(dynamic raw) {
    if (raw == null) return null;
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is Map<String, Object?>) {
        return fromJson(decoded);
      }
    } catch (_) {
      // ignore
    }
    return null;
  }
}

class Note {
  const Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.type,
    this.projectData,
    this.pinned = false,
    this.archived = false,
    this.date,
    this.templateId,
    required this.createdAt,
    required this.updatedAt,
    this.lastAccessedAt,
  });

  /// UUID
  final String id;

  /// UUID (auth.users.id)
  final String userId;

  final String title;
  final String content;
  final NoteType type;
  final ProjectData? projectData;
  final bool pinned;
  final bool archived;

  /// For daily notes: YYYY-MM-DD
  final String? date;

  /// UUID reference to note_templates table
  final String? templateId;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastAccessedAt;

  Note copyWith({
    String? title,
    String? content,
    NoteType? type,
    ProjectData? projectData,
    bool? pinned,
    bool? archived,
    String? date,
    String? templateId,
    DateTime? updatedAt,
    DateTime? lastAccessedAt,
    bool clearProjectData = false,
    bool clearDate = false,
    bool clearTemplateId = false,
  }) {
    return Note(
      id: id,
      userId: userId,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      projectData: clearProjectData ? null : (projectData ?? this.projectData),
      pinned: pinned ?? this.pinned,
      archived: archived ?? this.archived,
      date: clearDate ? null : (date ?? this.date),
      templateId: clearTemplateId ? null : (templateId ?? this.templateId),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }

  static Note fromDbJson(Map<String, Object?> json) {
    final createdAtRaw = (json['created_at'] as String?) ?? '';
    final updatedAtRaw = (json['updated_at'] as String?) ?? '';
    final lastAccessedAtRaw = json['last_accessed_at'] as String?;

    return Note(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      type: NoteType.fromDb((json['note_type'] as String?) ?? 'note'),
      projectData: ProjectData.fromDbJson(json['project_data']),
      pinned: (json['pinned'] as bool?) ?? false,
      archived: (json['archived'] as bool?) ?? false,
      date: json['date'] as String?,
      templateId: json['template_id'] as String?,
      createdAt: DateTime.tryParse(createdAtRaw) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(updatedAtRaw) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastAccessedAt: lastAccessedAtRaw != null
          ? DateTime.tryParse(lastAccessedAtRaw)
          : null,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'content': content,
        'type': type.dbValue,
        'projectData': projectData?.toJson(),
        'pinned': pinned,
        'archived': archived,
        'date': date,
        'templateId': templateId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'lastAccessedAt': lastAccessedAt?.toIso8601String(),
      };

  static Note fromJson(Map<String, Object?> json) {
    final createdAtRaw = (json['createdAt'] as String?) ?? '';
    final updatedAtRaw = (json['updatedAt'] as String?) ?? '';
    final lastAccessedAtRaw = json['lastAccessedAt'] as String?;

    return Note(
      id: (json['id'] as String?) ?? '',
      userId: (json['userId'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      type: NoteType.fromDb((json['type'] as String?) ?? 'note'),
      projectData: ProjectData.fromJson(json['projectData'] as Map<String, Object?>?),
      pinned: (json['pinned'] as bool?) ?? false,
      archived: (json['archived'] as bool?) ?? false,
      date: json['date'] as String?,
      templateId: json['templateId'] as String?,
      createdAt: DateTime.tryParse(createdAtRaw) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(updatedAtRaw) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastAccessedAt: lastAccessedAtRaw != null
          ? DateTime.tryParse(lastAccessedAtRaw)
          : null,
    );
  }
}
