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
    required this.apiKey,
    LinearHttp? http,
  }) : _http = http ?? createLinearHttp();

  final String apiKey;
  final LinearHttp _http;

  static final Uri _endpoint = Uri.parse('https://api.linear.app/graphql');

  Map<String, String> get _headers => {
        // Linear expects the API key directly in the Authorization header.
        'Authorization': apiKey,
        'Accept': 'application/json',
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

  Future<LinearIssue?> fetchIssueByIdentifier(String identifier) async {
    final id = identifier.trim();
    if (id.isEmpty) return null;
    final res = await _postGraphql(
      query: r'''
query IssueByIdentifier($identifier: String!) {
  issues(filter: { identifier: { eq: $identifier } }) {
    nodes {
      id
      identifier
      title
      description
      url
      state { id name type }
      assignee { name displayName }
      team {
        id
        states { nodes { id name type } }
      }
    }
  }
}
''',
      variables: {'identifier': id},
    );

    final nodes =
        (((res['data'] as Map?)?['issues'] as Map?)?['nodes'] as List?) ??
            const [];
    if (nodes.isEmpty) return null;
    final first = nodes.first;
    if (first is! Map) return null;
    final m = Map<String, Object?>.from(first);

    final stateRaw = m['state'];
    final stateMap = stateRaw is Map
        ? Map<String, Object?>.from(stateRaw)
        : const <String, Object?>{};
    final state = LinearIssueState(
      id: (stateMap['id'] as String?) ?? '',
      name: (stateMap['name'] as String?) ?? '',
      type: (stateMap['type'] as String?) ?? '',
    );

    final assigneeRaw = m['assignee'];
    String? assigneeName;
    if (assigneeRaw is Map) {
      final a = Map<String, Object?>.from(assigneeRaw);
      assigneeName = (a['displayName'] as String?) ?? (a['name'] as String?);
    }

    final teamRaw = m['team'];
    final teamMap = teamRaw is Map
        ? Map<String, Object?>.from(teamRaw)
        : const <String, Object?>{};
    final teamId = (teamMap['id'] as String?) ?? '';
    final statesRaw = (teamMap['states'] as Map?)?['nodes'];
    final statesList = statesRaw is List ? statesRaw : const [];
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

    return LinearIssue(
      id: (m['id'] as String?) ?? '',
      identifier: (m['identifier'] as String?) ?? id,
      title: (m['title'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      url: (m['url'] as String?) ?? '',
      state: state,
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
      throw StateError('Linear request failed (HTTP ${resp.statusCode}).');
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
