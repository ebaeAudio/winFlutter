import '../../data/linear/linear_issue_repository.dart';
import '../../data/linear/linear_models.dart';
import '../../data/tasks/task_details_repository.dart';
import 'today_models.dart';

class LinearTaskResolution {
  const LinearTaskResolution({
    required this.title,
    this.notes,
  });

  final String title;
  final String? notes;
}

Future<LinearTaskResolution?> resolveLinearTaskInput({
  required String input,
  required LinearIssueRepository? linearIssueRepository,
}) async {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  final linearRef = LinearIssueRef.tryParseFromText(trimmed);
  final linearUrl = _extractLinearUrl(trimmed);
  if (linearRef == null && linearUrl == null) return null;

  var resolvedTitle = trimmed;
  String? resolvedNotes;

  if (linearRef != null && linearUrl != null) {
    final fallbackTitle = _tryBuildLinearTitleFromUrl(linearUrl);
    if (fallbackTitle != null && fallbackTitle.trim().isNotEmpty) {
      resolvedTitle = fallbackTitle;
    }
    resolvedNotes = linearUrl;
  }

  if (linearIssueRepository != null && linearRef != null) {
    try {
      final issue =
          await linearIssueRepository.getIssueByIdentifier(linearRef.identifier);
      if (issue != null) {
        final issueTitle = issue.title.trim();
        resolvedTitle =
            issueTitle.isEmpty ? issue.identifier : '${issue.identifier} — $issueTitle';
        resolvedNotes = _formatLinearNotes(issue);
      }
    } catch (_) {
      // Ignore: never block task creation on Linear.
    }
  }

  return LinearTaskResolution(title: resolvedTitle, notes: resolvedNotes);
}

Future<void> maybeSyncLinearTask({
  required String taskId,
  required bool isSupabaseMode,
  required List<TodayTask> localTasks,
  required TaskDetailsRepository? taskDetailsRepository,
  required LinearIssueRepository? linearIssueRepository,
  required Future<void> Function({required DateTime at, String? error})
      recordLinearSyncStatus,
  bool? completed,
  bool? inProgress,
}) async {
  final repo = linearIssueRepository;
  if (repo == null) return;

  String notesText = '';
  try {
    if (isSupabaseMode) {
      final detailsRepo = taskDetailsRepository;
      if (detailsRepo == null) return;
      final details = await detailsRepo.getDetails(taskId: taskId);
      notesText = (details.notes ?? '').trim();
    } else {
      final match = localTasks.where((t) => t.id == taskId).toList();
      if (match.isEmpty) return;
      final t = match.first;
      notesText = (t.details ?? '').trim();
    }

    final ref = LinearIssueRef.tryParseFromText(notesText);
    if (ref == null) return;

    final issue = await repo.getIssueByIdentifier(ref.identifier);
    if (issue == null) {
      await recordLinearSyncStatus(
        at: DateTime.now(),
        error: 'Linear issue not found: ${ref.identifier}',
      );
      return;
    }

    String? desiredType;
    if (inProgress == true) {
      desiredType = 'started';
    } else if (completed == true) {
      desiredType = 'completed';
    } else if (completed == false) {
      // Best-effort revert: move away from completed back to started/unstarted.
      desiredType = issue.findTeamStateByType('started') != null
          ? 'started'
          : (issue.findTeamStateByType('unstarted') != null
              ? 'unstarted'
              : null);
    } else if (inProgress == false) {
      // If user explicitly turns off in-progress, revert to unstarted if possible.
      desiredType = issue.findTeamStateByType('unstarted') != null
          ? 'unstarted'
          : (issue.findTeamStateByType('backlog') != null ? 'backlog' : null);
    }

    if (desiredType == null || desiredType.trim().isEmpty) return;

    final updated =
        await repo.setIssueStateType(issue: issue, stateType: desiredType);
    if (updated == null) {
      await recordLinearSyncStatus(
        at: DateTime.now(),
        error: 'No Linear state of type “$desiredType” for team.',
      );
      return;
    }

    await recordLinearSyncStatus(at: DateTime.now(), error: null);
  } catch (e) {
    // Never block the core task toggle; just record the failure.
    await recordLinearSyncStatus(at: DateTime.now(), error: e.toString());
  }
}

String _formatLinearNotes(LinearIssue issue) {
  final url = issue.url.trim();
  final description = issue.description.trim();
  if (url.isEmpty) return description;
  if (description.isEmpty) return url;
  return '$url\n\n$description';
}

final RegExp _linearUrlRegex = RegExp(r'https?://linear\.app/\S+');

String? _extractLinearUrl(String text) {
  final match = _linearUrlRegex.firstMatch(text);
  if (match == null) return null;
  return text.substring(match.start, match.end);
}

String? _tryBuildLinearTitleFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (uri.host.trim().toLowerCase() != 'linear.app') return null;

  final segments = uri.pathSegments;
  final issueIdx = segments.indexOf('issue');
  if (issueIdx < 0 || issueIdx + 1 >= segments.length) return null;

  final identifier = segments[issueIdx + 1].trim();
  if (identifier.isEmpty) return null;

  final slug =
      (issueIdx + 2 < segments.length) ? segments[issueIdx + 2].trim() : '';
  final prettySlug =
      slug.isEmpty ? '' : Uri.decodeComponent(slug).replaceAll('-', ' ').trim();

  if (prettySlug.isEmpty) return identifier;
  return '$identifier — $prettySlug';
}
