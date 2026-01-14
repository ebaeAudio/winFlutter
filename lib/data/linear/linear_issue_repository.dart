import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/linear_integration_controller.dart';
import 'linear_client.dart';
import 'linear_models.dart';

class LinearIssueRepository {
  LinearIssueRepository({required String apiKey}) : _client = LinearClient(apiKey: apiKey);

  final LinearClient _client;

  Future<LinearIssue?> getIssueByIdentifier(String identifier) =>
      _client.fetchIssueByIdentifier(identifier);

  /// Update the issue state by Linear IssueState.type, e.g. `started` or `completed`.
  ///
  /// If the team doesn't have a matching state type, this is a no-op and returns null.
  Future<LinearIssueState?> setIssueStateType({
    required LinearIssue issue,
    required String stateType,
  }) async {
    final target = issue.findTeamStateByType(stateType);
    if (target == null || target.id.trim().isEmpty) return null;
    return _client.updateIssueState(issueId: issue.id, stateId: target.id);
  }
}

final linearIssueRepositoryProvider = Provider<LinearIssueRepository?>((ref) {
  final s = ref.watch(linearIntegrationControllerProvider).valueOrNull;
  final apiKey = (s?.apiKey ?? '').trim();
  if (apiKey.isEmpty) return null;
  return LinearIssueRepository(apiKey: apiKey);
});

final linearIssueByIdentifierProvider =
    FutureProvider.family<LinearIssue?, String>((ref, identifier) async {
  final repo = ref.watch(linearIssueRepositoryProvider);
  if (repo == null) return null;
  return repo.getIssueByIdentifier(identifier);
});

