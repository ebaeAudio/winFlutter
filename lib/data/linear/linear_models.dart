import 'package:flutter/foundation.dart';

@immutable
class LinearIssueRef {
  const LinearIssueRef({required this.identifier});

  /// Human-readable issue id like `ABC-123`.
  final String identifier;

  static final _identifierRegex = RegExp(r'\b[A-Z][A-Z0-9]+-\d+\b');
  static final _linearUrlRegex = RegExp(r'https?://linear\.app/\S+');

  /// Best-effort: find a Linear issue identifier in a blob of text.
  ///
  /// We prefer identifiers near a `linear.app/...` URL, but we’ll fall back to
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
}

@immutable
class LinearIssue {
  const LinearIssue({
    required this.id,
    required this.identifier,
    required this.title,
    required this.url,
    required this.state,
    required this.teamId,
    required this.teamStates,
    this.assigneeName,
  });

  final String id;
  final String identifier;
  final String title;
  final String url;
  final LinearIssueState state;
  final String teamId;
  final List<LinearIssueState> teamStates;
  final String? assigneeName;

  LinearIssueState? findTeamStateByType(String desiredType) {
    final want = desiredType.toLowerCase().trim();
    for (final s in teamStates) {
      if (s.type.toLowerCase() == want) return s;
    }
    return null;
  }
}

