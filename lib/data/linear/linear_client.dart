import 'dart:convert';

import 'linear_http.dart';
import 'linear_models.dart';

class LinearViewer {
  const LinearViewer({
    required this.id,
    required this.name,
    required this.displayName,
  });

  final String id;
  final String? name;
  final String? displayName;
}

class LinearClient {
  LinearClient({
    required String apiKey,
    LinearHttp? http,
  })  : apiKey = apiKey.trim(),
        _http = http ?? createLinearHttp();

  /// API key, already trimmed. Linear expects it verbatim in the Authorization header.
  final String apiKey;
  final LinearHttp _http;

  static final Uri _endpoint = Uri.parse('https://api.linear.app/graphql');

  Map<String, String> get _headers => {
        // Linear expects the API key directly in the Authorization header (no Bearer).
        'Authorization': apiKey,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<LinearViewer> fetchViewer() async {
    final res = await _postGraphql(
      query: r'''
query Viewer {
  viewer {
    id
    name
    displayName
  }
}
''',
      variables: const {},
    );

    final viewer = ((res['data'] as Map?)?['viewer'] as Map?) ?? const {};
    return LinearViewer(
      id: (viewer['id'] as String?) ?? '',
      name: viewer['name'] as String?,
      displayName: viewer['displayName'] as String?,
    );
  }

  /// Fetches a Linear issue by its identifier (e.g. "PRT-4469").
  ///
  /// Returns null if the issue is not found or the identifier is empty.
  ///
  /// ## Fields fetched (for UI)
  /// - Stable IDs: id, identifier, url
  /// - Display: title, description
  /// - State: state.id, state.name, state.type
  /// - Priority: priority (numeric), priorityLabel
  /// - Assignee: id, name, displayName, avatarUrl
  /// - Team: id, key, name, states
  /// - Timeline: createdAt, updatedAt, completedAt, dueDate
  Future<LinearIssue?> fetchIssueByIdentifier(String identifier) async {
    final id = identifier.trim();
    if (id.isEmpty) return null;
    final res = await _postGraphql(
      query: r'''
query IssueByIdentifier($id: String!) {
  issue(id: $id) {
    id
    identifier
    title
    description
    url
    priority
    priorityLabel
    createdAt
    updatedAt
    completedAt
    dueDate
    state { id name type }
    assignee {
      id
      name
      displayName
      avatarUrl
    }
    team {
      id
      key
      name
      states { nodes { id name type } }
    }
  }
}
''',
      variables: {'id': id},
    );

    final issueData = (res['data'] as Map?)?['issue'];
    if (issueData == null || issueData is! Map) return null;
    final m = Map<String, Object?>.from(issueData);

    // Parse state
    final stateRaw = m['state'];
    final stateMap = stateRaw is Map
        ? Map<String, Object?>.from(stateRaw)
        : const <String, Object?>{};
    final state = LinearIssueState(
      id: (stateMap['id'] as String?) ?? '',
      name: (stateMap['name'] as String?) ?? '',
      type: (stateMap['type'] as String?) ?? '',
    );

    // Parse assignee (now with full data)
    final assigneeRaw = m['assignee'];
    LinearAssignee? assignee;
    String? assigneeName; // Legacy compat
    if (assigneeRaw is Map) {
      final a = Map<String, Object?>.from(assigneeRaw);
      assignee = LinearAssignee(
        id: (a['id'] as String?) ?? '',
        name: a['name'] as String?,
        displayName: a['displayName'] as String?,
        avatarUrl: a['avatarUrl'] as String?,
      );
      assigneeName = assignee.resolvedName;
    }

    // Parse team (now with key and name)
    final teamRaw = m['team'];
    final teamMap = teamRaw is Map
        ? Map<String, Object?>.from(teamRaw)
        : const <String, Object?>{};
    final teamId = (teamMap['id'] as String?) ?? '';
    final teamKey = (teamMap['key'] as String?) ?? '';
    final teamName = (teamMap['name'] as String?) ?? '';

    // Parse team states
    final statesRaw = (teamMap['states'] as Map?)?['nodes'];
    final statesList = statesRaw is List ? statesRaw : const <Object?>[];
    final teamStates = <LinearIssueState>[];
    for (final s in statesList) {
      if (s is! Map) continue;
      final sm = Map<String, Object?>.from(s);
      teamStates.add(
        LinearIssueState(
          id: (sm['id'] as String?) ?? '',
          name: (sm['name'] as String?) ?? '',
          type: (sm['type'] as String?) ?? '',
        ),
      );
    }

    final team = LinearTeam(
      id: teamId,
      key: teamKey,
      name: teamName,
      states: teamStates,
    );

    // Parse dates
    final createdAtRaw = m['createdAt'] as String?;
    final updatedAtRaw = m['updatedAt'] as String?;
    final completedAtRaw = m['completedAt'] as String?;
    final dueDateRaw = m['dueDate'] as String?;

    return LinearIssue(
      id: (m['id'] as String?) ?? '',
      identifier: (m['identifier'] as String?) ?? id,
      title: (m['title'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      url: (m['url'] as String?) ?? '',
      state: state,
      team: team,
      assignee: assignee,
      priority: (m['priority'] as num?)?.toInt(),
      priorityLabel: m['priorityLabel'] as String?,
      createdAt: createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null,
      updatedAt: updatedAtRaw != null ? DateTime.tryParse(updatedAtRaw) : null,
      completedAt:
          completedAtRaw != null ? DateTime.tryParse(completedAtRaw) : null,
      dueDate: dueDateRaw != null ? DateTime.tryParse(dueDateRaw) : null,
      // Legacy compat
      teamId: teamId,
      teamStates: teamStates,
      assigneeName: assigneeName,
    );
  }

  Future<LinearIssueState> updateIssueState({
    required String issueId,
    required String stateId,
  }) async {
    final res = await _postGraphql(
      query: r'''
mutation IssueUpdateState($id: String!, $stateId: String!) {
  issueUpdate(id: $id, input: { stateId: $stateId }) {
    success
    issue { id state { id name type } }
  }
}
''',
      variables: {'id': issueId, 'stateId': stateId},
    );

    final issueUpdate =
        ((res['data'] as Map?)?['issueUpdate'] as Map?) ?? const {};
    final issue = (issueUpdate['issue'] as Map?) ?? const {};
    final state = (issue['state'] as Map?) ?? const {};
    return LinearIssueState(
      id: (state['id'] as String?) ?? '',
      name: (state['name'] as String?) ?? '',
      type: (state['type'] as String?) ?? '',
    );
  }

  /// Parse 4xx/5xx response body for a user-visible error snippet (no secrets).
  static String _parseErrorBody(int statusCode, String body) {
    if (body.trim().isEmpty) return '';
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return '';
      final errors = decoded['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is Map && first['message'] is String) {
          return first['message'] as String;
        }
      }
      final msg = decoded['message'];
      if (msg is String) return msg;
    } catch (_) {}
    // Avoid dumping raw body (could contain sensitive data); cap length
    if (body.length > 120) return 'Response: ${body.substring(0, 120)}…';
    return 'Response: $body';
  }

  Future<Map<String, Object?>> _postGraphql({
    required String query,
    required Map<String, Object?> variables,
  }) async {
    final body = jsonEncode({
      'query': query,
      'variables': variables,
    });
    final resp = await _http.postJson(
      url: _endpoint,
      headers: _headers,
      body: body,
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final detail = _parseErrorBody(resp.statusCode, resp.body);
      throw StateError('Linear request failed (HTTP ${resp.statusCode}). $detail');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw StateError('Linear response was not JSON object.');
    }
    final map = Map<String, Object?>.from(decoded);
    final errors = map['errors'];
    if (errors is List && errors.isNotEmpty) {
      // Keep it simple: surface the first error message.
      final first = errors.first;
      if (first is Map && first['message'] is String) {
        throw StateError(first['message'] as String);
      }
      throw StateError('Linear request failed.');
    }
    return map;
  }
}
