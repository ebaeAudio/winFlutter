import 'package:flutter/foundation.dart';

/// Linear-specific metadata attached to a task.
///
/// This model encapsulates all Linear issue data needed for the Task Details UI
/// without mixing Linear-specific fields into the generic Task model.
///
/// ## UI Dependencies
/// - **LinearTicketHeader**: issueKey, teamKey, state (for pill), priority (for pill)
/// - **Deep link**: issueUrl
/// - **Assignee display**: assignee.name, assignee.avatarUrl
/// - **Description rendering**: description (markdown)
/// - **Sync status banner**: syncStatus, lastSyncedAt, lastError
@immutable
class LinearIssueMeta {
  const LinearIssueMeta({
    required this.issueId,
    required this.issueKey,
    required this.issueUrl,
    required this.title,
    required this.description,
    required this.state,
    required this.priority,
    required this.team,
    required this.createdAt,
    required this.updatedAt,
    this.assignee,
    this.completedAt,
    this.dueDate,
    required this.syncStatus,
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Stable Identifiers
  // ─────────────────────────────────────────────────────────────────────────────

  /// Linear issue UUID (stable across renames).
  final String issueId;

  /// Human-readable issue key, e.g. "PRT-4469".
  /// Used in compact headers and as primary visual identifier.
  final String issueKey;

  /// Full URL for deep-linking to Linear.
  /// e.g. "https://linear.app/team/issue/PRT-4469/title-slug"
  final String issueUrl;

  // ─────────────────────────────────────────────────────────────────────────────
  // Core Display Fields
  // ─────────────────────────────────────────────────────────────────────────────

  /// Issue title (may differ from task title if edited locally).
  final String title;

  /// Full description in markdown format.
  /// Render safely with appropriate markdown widget.
  final String description;

  /// Current Linear state with display name and semantic type.
  final LinearStateMeta state;

  /// Priority information for display (numeric + label).
  final LinearPriorityMeta priority;

  /// Optional assignee info. Null if unassigned.
  final LinearAssigneeMeta? assignee;

  /// Team information for context/grouping.
  final LinearTeamMeta team;

  // ─────────────────────────────────────────────────────────────────────────────
  // Timeline Fields
  // ─────────────────────────────────────────────────────────────────────────────

  /// When the Linear issue was created.
  final DateTime createdAt;

  /// When the Linear issue was last updated.
  final DateTime updatedAt;

  /// When the issue was marked completed. Null if not completed.
  final DateTime? completedAt;

  /// Optional due date. Null if not set in Linear.
  final DateTime? dueDate;

  // ─────────────────────────────────────────────────────────────────────────────
  // Sync Status
  // ─────────────────────────────────────────────────────────────────────────────

  /// Current sync state for UI status display.
  final LinearSyncStatus syncStatus;

  /// Convenience: check if data may be outdated.
  bool get isStaleOrFailed =>
      syncStatus.status == LinearSyncState.stale ||
      syncStatus.status == LinearSyncState.failed;

  // ─────────────────────────────────────────────────────────────────────────────
  // JSON Serialization
  // ─────────────────────────────────────────────────────────────────────────────

  Map<String, Object?> toJson() => {
        'issueId': issueId,
        'issueKey': issueKey,
        'issueUrl': issueUrl,
        'title': title,
        'description': description,
        'state': state.toJson(),
        'priority': priority.toJson(),
        if (assignee != null) 'assignee': assignee!.toJson(),
        'team': team.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
        'syncStatus': syncStatus.toJson(),
      };

  static LinearIssueMeta fromJson(Map<String, Object?> json) {
    return LinearIssueMeta(
      issueId: (json['issueId'] as String?) ?? '',
      issueKey: (json['issueKey'] as String?) ?? '',
      issueUrl: (json['issueUrl'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      state: LinearStateMeta.fromJson(
        (json['state'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
      priority: LinearPriorityMeta.fromJson(
        (json['priority'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
      assignee: json['assignee'] != null
          ? LinearAssigneeMeta.fromJson(
              (json['assignee'] as Map).cast<String, Object?>(),
            )
          : null,
      team: LinearTeamMeta.fromJson(
        (json['team'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String)
          : null,
      syncStatus: LinearSyncStatus.fromJson(
        (json['syncStatus'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
    );
  }

  LinearIssueMeta copyWith({
    String? issueId,
    String? issueKey,
    String? issueUrl,
    String? title,
    String? description,
    LinearStateMeta? state,
    LinearPriorityMeta? priority,
    LinearAssigneeMeta? assignee,
    LinearTeamMeta? team,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    DateTime? dueDate,
    LinearSyncStatus? syncStatus,
    bool clearAssignee = false,
    bool clearCompletedAt = false,
    bool clearDueDate = false,
  }) {
    return LinearIssueMeta(
      issueId: issueId ?? this.issueId,
      issueKey: issueKey ?? this.issueKey,
      issueUrl: issueUrl ?? this.issueUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      state: state ?? this.state,
      priority: priority ?? this.priority,
      assignee: clearAssignee ? null : (assignee ?? this.assignee),
      team: team ?? this.team,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linear State
// ─────────────────────────────────────────────────────────────────────────────

/// Linear state type categories.
/// Maps Linear's workflow state types to semantic categories.
enum LinearStateType {
  /// Work not yet started (backlog, triage, unstarted).
  backlog,

  /// Work in active progress.
  started,

  /// Work finished successfully.
  completed,

  /// Work abandoned/won't do.
  canceled,

  /// Unknown or custom state type.
  unknown;

  static LinearStateType fromLinearType(String type) {
    final t = type.trim().toLowerCase();
    return switch (t) {
      'backlog' || 'triage' || 'unstarted' => LinearStateType.backlog,
      'started' => LinearStateType.started,
      'completed' => LinearStateType.completed,
      'canceled' || 'cancelled' => LinearStateType.canceled,
      _ => LinearStateType.unknown,
    };
  }
}

/// Linear issue state with both the raw name and semantic type.
///
/// ## UI Usage
/// - `name`: Display in state pill (e.g. "In Review", "Ready for QA")
/// - `type`: Determine pill color/styling and map to app task status
@immutable
class LinearStateMeta {
  const LinearStateMeta({
    required this.id,
    required this.name,
    required this.type,
  });

  /// Linear state UUID.
  final String id;

  /// Display name as configured in Linear (e.g. "In Progress", "Done").
  final String name;

  /// Semantic category for styling and status mapping.
  final LinearStateType type;

  /// Maps Linear state to the app's task completion/in-progress status.
  ///
  /// Returns (completed, inProgress) tuple:
  /// - backlog/unknown → (false, false)
  /// - started → (false, true)
  /// - completed → (true, false)
  /// - canceled → (true, false) — treat as "done" to hide from active lists
  (bool completed, bool inProgress) toAppStatus() {
    return switch (type) {
      LinearStateType.backlog => (false, false),
      LinearStateType.started => (false, true),
      LinearStateType.completed => (true, false),
      LinearStateType.canceled => (true, false),
      LinearStateType.unknown => (false, false),
    };
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
      };

  static LinearStateMeta fromJson(Map<String, Object?> json) {
    final typeRaw = (json['type'] as String?) ?? '';
    return LinearStateMeta(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      type: LinearStateType.values.firstWhere(
        (e) => e.name == typeRaw,
        orElse: () => LinearStateType.fromLinearType(typeRaw),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linear Priority
// ─────────────────────────────────────────────────────────────────────────────

/// Linear priority levels (0 = no priority, 1 = urgent, 4 = low).
enum LinearPriorityLevel {
  none(0),
  urgent(1),
  high(2),
  medium(3),
  low(4);

  const LinearPriorityLevel(this.value);
  final int value;

  static LinearPriorityLevel fromValue(int? value) {
    if (value == null) return LinearPriorityLevel.none;
    return LinearPriorityLevel.values.firstWhere(
      (e) => e.value == value,
      orElse: () => LinearPriorityLevel.none,
    );
  }
}

/// Linear priority with both numeric value and display label.
///
/// ## UI Usage
/// - `label`: Display in priority pill (e.g. "Urgent", "High")
/// - `level`: Determine pill color/icon
///
/// Note: We preserve Linear's label for display; do NOT map to app-side enums.
@immutable
class LinearPriorityMeta {
  const LinearPriorityMeta({
    required this.level,
    required this.label,
  });

  /// Numeric priority (0-4).
  final LinearPriorityLevel level;

  /// Human-readable label (e.g. "Urgent", "High", "No priority").
  final String label;

  /// Returns true if priority is set (not "none").
  bool get hasPriority => level != LinearPriorityLevel.none;

  Map<String, Object?> toJson() => {
        'level': level.value,
        'label': label,
      };

  static LinearPriorityMeta fromJson(Map<String, Object?> json) {
    final levelValue = (json['level'] as num?)?.toInt();
    return LinearPriorityMeta(
      level: LinearPriorityLevel.fromValue(levelValue),
      label: (json['label'] as String?) ?? '',
    );
  }

  /// Create from Linear GraphQL priority fields.
  static LinearPriorityMeta fromLinear({
    required int? priority,
    required String? priorityLabel,
  }) {
    final level = LinearPriorityLevel.fromValue(priority);
    final label = (priorityLabel ?? '').trim();
    return LinearPriorityMeta(
      level: level,
      label: label.isEmpty ? _defaultLabel(level) : label,
    );
  }

  static String _defaultLabel(LinearPriorityLevel level) {
    return switch (level) {
      LinearPriorityLevel.none => 'No priority',
      LinearPriorityLevel.urgent => 'Urgent',
      LinearPriorityLevel.high => 'High',
      LinearPriorityLevel.medium => 'Medium',
      LinearPriorityLevel.low => 'Low',
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linear Assignee
// ─────────────────────────────────────────────────────────────────────────────

/// Linear user assigned to an issue.
///
/// ## UI Usage
/// - `name`: Display name next to avatar
/// - `avatarUrl`: Load avatar image (may be null)
@immutable
class LinearAssigneeMeta {
  const LinearAssigneeMeta({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  /// Linear user UUID.
  final String id;

  /// Display name (prefers displayName, falls back to name).
  final String name;

  /// Avatar image URL. Null if user has no avatar.
  final String? avatarUrl;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      };

  static LinearAssigneeMeta fromJson(Map<String, Object?> json) {
    return LinearAssigneeMeta(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linear Team
// ─────────────────────────────────────────────────────────────────────────────

/// Linear team information.
///
/// ## UI Usage
/// - `key`: Short team prefix shown in headers (e.g. "PRT")
/// - `name`: Full team name for tooltips/details
@immutable
class LinearTeamMeta {
  const LinearTeamMeta({
    required this.id,
    required this.key,
    required this.name,
  });

  /// Linear team UUID.
  final String id;

  /// Short team key/prefix (e.g. "ENG", "PRT").
  final String key;

  /// Full team name (e.g. "Engineering", "Product").
  final String name;

  Map<String, Object?> toJson() => {
        'id': id,
        'key': key,
        'name': name,
      };

  static LinearTeamMeta fromJson(Map<String, Object?> json) {
    return LinearTeamMeta(
      id: (json['id'] as String?) ?? '',
      key: (json['key'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sync Status
// ─────────────────────────────────────────────────────────────────────────────

/// Sync state for Linear metadata.
enum LinearSyncState {
  /// Data is fresh and synced successfully.
  ok,

  /// Last sync attempt failed.
  failed,

  /// Data exists but may be outdated (e.g. hasn't synced in > 24h).
  stale,
}

/// Sync status metadata for UI display.
///
/// ## UI Usage
/// - Show non-blocking inline banner when `status != ok`
/// - Display `lastError` message when `status == failed`
/// - Allow manual refresh trigger
@immutable
class LinearSyncStatus {
  const LinearSyncStatus({
    required this.status,
    required this.lastSyncedAt,
    this.lastError,
  });

  /// Current sync state.
  final LinearSyncState status;

  /// When data was last successfully fetched from Linear.
  final DateTime lastSyncedAt;

  /// User-displayable error message when status is failed.
  /// Should be friendly (not raw HTTP errors).
  final String? lastError;

  /// Factory for successful sync.
  factory LinearSyncStatus.ok() => LinearSyncStatus(
        status: LinearSyncState.ok,
        lastSyncedAt: DateTime.now(),
      );

  /// Factory for failed sync.
  factory LinearSyncStatus.failed(String error) => LinearSyncStatus(
        status: LinearSyncState.failed,
        lastSyncedAt: DateTime.now(),
        lastError: error,
      );

  /// Factory for stale data.
  factory LinearSyncStatus.stale(DateTime lastSyncedAt) => LinearSyncStatus(
        status: LinearSyncState.stale,
        lastSyncedAt: lastSyncedAt,
      );

  Map<String, Object?> toJson() => {
        'status': status.name,
        'lastSyncedAt': lastSyncedAt.toIso8601String(),
        if (lastError != null) 'lastError': lastError,
      };

  static LinearSyncStatus fromJson(Map<String, Object?> json) {
    final statusRaw = (json['status'] as String?) ?? '';
    return LinearSyncStatus(
      status: LinearSyncState.values.firstWhere(
        (e) => e.name == statusRaw,
        orElse: () => LinearSyncState.ok,
      ),
      lastSyncedAt:
          DateTime.tryParse((json['lastSyncedAt'] as String?) ?? '') ??
              DateTime.now(),
      lastError: json['lastError'] as String?,
    );
  }
}
