import 'package:flutter/foundation.dart';

import 'linear_issue_meta.dart';

@immutable
class LinearIssueRef {
  const LinearIssueRef({required this.identifier});

  /// Human-readable issue id like `ABC-123`.
  final String identifier;

  static final _identifierRegex = RegExp(r'\b[A-Z][A-Z0-9]+-\d+\b');
  static final _linearUrlRegex = RegExp(r'https?://linear\.app/\S+');

  /// Best-effort: find a Linear issue identifier in a blob of text.
  ///
  /// We prefer identifiers near a `linear.app/...` URL, but we'll fall back to
  /// any identifier-like token to keep the UX forgiving.
  static LinearIssueRef? tryParseFromText(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return null;

    // Prefer scanning only within Linear URLs first.
    final urlMatches = _linearUrlRegex.allMatches(raw);
    for (final m in urlMatches) {
      final url = raw.substring(m.start, m.end);
      final idMatch = _identifierRegex.firstMatch(url);
      if (idMatch != null) {
        return LinearIssueRef(identifier: idMatch.group(0)!);
      }
    }

    final match = _identifierRegex.firstMatch(raw);
    if (match == null) return null;
    return LinearIssueRef(identifier: match.group(0)!);
  }
}

@immutable
class LinearIssueState {
  const LinearIssueState({
    required this.id,
    required this.name,
    required this.type,
  });

  final String id;
  final String name;

  /// Linear IssueState.type (string enum), e.g. `started`, `completed`, `backlog`.
  final String type;

  bool get isStarted => type.toLowerCase() == 'started';
  bool get isCompleted => type.toLowerCase() == 'completed';

  /// Convert to the richer LinearStateMeta model.
  LinearStateMeta toMeta() => LinearStateMeta(
        id: id,
        name: name,
        type: LinearStateType.fromLinearType(type),
      );
}

/// Assignee information from Linear.
@immutable
class LinearAssignee {
  const LinearAssignee({
    required this.id,
    required this.name,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String? name;
  final String? displayName;
  final String? avatarUrl;

  /// Preferred display name (displayName if available, else name).
  String get resolvedName =>
      (displayName ?? '').trim().isNotEmpty ? displayName! : (name ?? '');

  /// Convert to LinearAssigneeMeta.
  LinearAssigneeMeta toMeta() => LinearAssigneeMeta(
        id: id,
        name: resolvedName,
        avatarUrl: avatarUrl,
      );
}

/// Team information from Linear.
@immutable
class LinearTeam {
  const LinearTeam({
    required this.id,
    required this.key,
    required this.name,
    required this.states,
  });

  final String id;
  final String key;
  final String name;
  final List<LinearIssueState> states;

  /// Convert to LinearTeamMeta.
  LinearTeamMeta toMeta() => LinearTeamMeta(
        id: id,
        key: key,
        name: name,
      );
}

@immutable
class LinearIssue {
  const LinearIssue({
    required this.id,
    required this.identifier,
    required this.title,
    required this.url,
    required this.description,
    required this.state,
    required this.team,
    this.assignee,
    this.priority,
    this.priorityLabel,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.dueDate,
    // Legacy compatibility fields
    this.teamId,
    this.teamStates,
    this.assigneeName,
  });

  final String id;
  final String identifier;
  final String title;
  final String url;
  final String description;
  final LinearIssueState state;

  /// Full team information.
  final LinearTeam? team;

  /// Full assignee information.
  final LinearAssignee? assignee;

  /// Priority value (0 = no priority, 1 = urgent, 4 = low).
  final int? priority;

  /// Priority label (e.g. "Urgent", "High").
  final String? priorityLabel;

  /// When the issue was created.
  final DateTime? createdAt;

  /// When the issue was last updated.
  final DateTime? updatedAt;

  /// When the issue was completed (null if not completed).
  final DateTime? completedAt;

  /// Optional due date.
  final DateTime? dueDate;

  // ─────────────────────────────────────────────────────────────────────────────
  // Legacy compatibility (for existing code)
  // ─────────────────────────────────────────────────────────────────────────────

  /// @deprecated Use [team.id] instead.
  final String? teamId;

  /// @deprecated Use [team.states] instead.
  final List<LinearIssueState>? teamStates;

  /// @deprecated Use [assignee.resolvedName] instead.
  final String? assigneeName;

  /// Resolved team ID (prefers new team object, falls back to legacy).
  String get resolvedTeamId => team?.id ?? teamId ?? '';

  /// Resolved team states (prefers new team object, falls back to legacy).
  List<LinearIssueState> get resolvedTeamStates =>
      team?.states ?? teamStates ?? const [];

  /// Resolved assignee name (prefers new assignee object, falls back to legacy).
  String? get resolvedAssigneeName => assignee?.resolvedName ?? assigneeName;

  LinearIssueState? findTeamStateByType(String desiredType) {
    final want = desiredType.toLowerCase().trim();
    for (final s in resolvedTeamStates) {
      if (s.type.toLowerCase() == want) return s;
    }
    return null;
  }

  /// Convert to the richer LinearIssueMeta model for UI display.
  ///
  /// This creates a complete metadata snapshot with sync status set to OK.
  LinearIssueMeta toMeta() {
    return LinearIssueMeta(
      issueId: id,
      issueKey: identifier,
      issueUrl: url,
      title: title,
      description: description,
      state: state.toMeta(),
      priority: LinearPriorityMeta.fromLinear(
        priority: priority,
        priorityLabel: priorityLabel,
      ),
      assignee: assignee?.toMeta(),
      team: team?.toMeta() ??
          LinearTeamMeta(
            id: resolvedTeamId,
            key: '', // Legacy data doesn't have team key
            name: '',
          ),
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
      completedAt: completedAt,
      dueDate: dueDate,
      syncStatus: LinearSyncStatus.ok(),
    );
  }
}
