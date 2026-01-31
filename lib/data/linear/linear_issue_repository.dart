import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/linear_integration_controller.dart';
import 'linear_client.dart';
import 'linear_issue_meta.dart';
import 'linear_models.dart';

class LinearIssueRepository {
  LinearIssueRepository({required String apiKey})
      : _client = LinearClient(apiKey: apiKey);

  final LinearClient _client;

  Future<LinearIssue?> getIssueByIdentifier(String identifier) =>
      _client.fetchIssueByIdentifier(identifier);

  /// Fetch a Linear issue and convert to rich metadata model.
  ///
  /// Returns [LinearIssueMeta] with sync status indicating success/failure.
  /// On error, returns metadata with [LinearSyncState.failed] and error message.
  Future<LinearIssueMetaResult> getIssueMetaByIdentifier(
      String identifier) async {
    try {
      final issue = await _client.fetchIssueByIdentifier(identifier);
      if (issue == null) {
        return LinearIssueMetaResult.notFound(identifier);
      }
      return LinearIssueMetaResult.success(issue.toMeta());
    } catch (e) {
      return LinearIssueMetaResult.error(_friendlyError(e));
    }
  }

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

  /// Update issue state using metadata model (convenience wrapper).
  Future<LinearIssueState?> setIssueStateTypeFromMeta({
    required LinearIssueMeta meta,
    required String stateType,
  }) async {
    // First fetch the full issue to get team states
    final issue = await _client.fetchIssueByIdentifier(meta.issueKey);
    if (issue == null) return null;
    return setIssueStateType(issue: issue, stateType: stateType);
  }

  static String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('ClientException')) {
      return 'Network error. Check your connection.';
    }
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'Invalid API key. Update in Settings.';
    }
    if (msg.contains('403') || msg.contains('Forbidden')) {
      return 'Access denied. Check API key permissions.';
    }
    if (msg.contains('404') || msg.contains('not found')) {
      return 'Issue not found in Linear.';
    }
    if (msg.contains('429') || msg.contains('rate limit')) {
      return 'Rate limited. Try again in a moment.';
    }
    // Fallback: truncate long error messages
    if (msg.length > 80) {
      return 'Linear sync failed. Tap to retry.';
    }
    return msg;
  }
}

/// Result wrapper for LinearIssueMeta fetch operations.
///
/// Provides typed result handling for UI to differentiate between:
/// - Success: data available
/// - Not found: issue doesn't exist in Linear
/// - Error: network/auth/other failure with user-friendly message
class LinearIssueMetaResult {
  const LinearIssueMetaResult._({
    this.meta,
    this.error,
    required this.status,
  });

  final LinearIssueMeta? meta;
  final String? error;
  final LinearIssueMetaResultStatus status;

  factory LinearIssueMetaResult.success(LinearIssueMeta meta) =>
      LinearIssueMetaResult._(
        meta: meta,
        status: LinearIssueMetaResultStatus.success,
      );

  factory LinearIssueMetaResult.notFound(String identifier) =>
      LinearIssueMetaResult._(
        error: 'Issue "$identifier" not found in Linear.',
        status: LinearIssueMetaResultStatus.notFound,
      );

  factory LinearIssueMetaResult.error(String message) =>
      LinearIssueMetaResult._(
        error: message,
        status: LinearIssueMetaResultStatus.error,
      );

  bool get isSuccess => status == LinearIssueMetaResultStatus.success;
  bool get isNotFound => status == LinearIssueMetaResultStatus.notFound;
  bool get isError => status == LinearIssueMetaResultStatus.error;
}

enum LinearIssueMetaResultStatus {
  success,
  notFound,
  error,
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final linearIssueRepositoryProvider = Provider<LinearIssueRepository?>((ref) {
  final s = ref.watch(linearIntegrationControllerProvider).valueOrNull;
  final apiKey = (s?.apiKey ?? '').trim();
  if (apiKey.isEmpty) return null;
  return LinearIssueRepository(apiKey: apiKey);
});

/// Fetches a LinearIssue by identifier (legacy provider).
///
/// @deprecated Prefer [linearIssueMetaByIdentifierProvider] for richer metadata.
final linearIssueByIdentifierProvider =
    FutureProvider.family<LinearIssue?, String>((ref, identifier) async {
  final repo = ref.watch(linearIssueRepositoryProvider);
  if (repo == null) return null;
  return repo.getIssueByIdentifier(identifier);
});

/// Fetches LinearIssueMeta by identifier with proper error handling.
///
/// Returns [LinearIssueMetaResult] which can be:
/// - Success with [LinearIssueMeta]
/// - Not found (issue doesn't exist)
/// - Error with user-friendly message
///
/// ## Usage in UI
/// ```dart
/// final result = ref.watch(linearIssueMetaByIdentifierProvider('PRT-4469'));
/// result.when(
///   data: (r) => r.isSuccess
///     ? LinearIssueHeader(meta: r.meta!)
///     : ErrorBanner(message: r.error),
///   loading: () => LoadingIndicator(),
///   error: (e, _) => ErrorBanner(message: 'Failed to load'),
/// );
/// ```
final linearIssueMetaByIdentifierProvider =
    FutureProvider.family<LinearIssueMetaResult, String>(
        (ref, identifier) async {
  final repo = ref.watch(linearIssueRepositoryProvider);
  if (repo == null) {
    return LinearIssueMetaResult.error('Linear integration not configured.');
  }
  return repo.getIssueMetaByIdentifier(identifier);
});

/// Checks if Linear integration is available.
final linearIntegrationAvailableProvider = Provider<bool>((ref) {
  final repo = ref.watch(linearIssueRepositoryProvider);
  return repo != null;
});
