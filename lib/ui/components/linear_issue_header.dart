import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/linear/linear_issue_meta.dart';
import '../spacing.dart';
import 'linear_assignee_chip.dart';
import 'linear_priority_pill.dart';
import 'linear_state_pill.dart';

/// Linear issue header with key, team, title, and metadata row.
///
/// Designed for the Task Details screen to treat Linear content as primary.
/// Structure (top to bottom):
/// 1. Issue key + team (small, muted)
/// 2. Issue title (main header, max 2 lines)
/// 3. Metadata row: state pill, priority pill, assignee, deep link
class LinearIssueHeader extends StatelessWidget {
  const LinearIssueHeader({
    super.key,
    required this.meta,
  });

  final LinearIssueMeta meta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Issue key + team (muted, single line)
        _buildIdentifierRow(theme, scheme),
        Gap.h4,

        // Title (main header)
        _buildTitle(theme),
        Gap.h8,

        // Metadata row: state, priority, assignee, deep link
        _buildMetadataRow(context, theme, scheme),
      ],
    );
  }

  Widget _buildIdentifierRow(ThemeData theme, ColorScheme scheme) {
    final teamName = meta.team.name.trim();
    final teamKey = meta.team.key.trim();
    final teamDisplay =
        teamName.isNotEmpty ? teamName : (teamKey.isNotEmpty ? teamKey : null);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: meta.issueKey,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (teamDisplay != null) ...[
            TextSpan(
              text: ' · ',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
            TextSpan(
              text: teamDisplay,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    final title = meta.title.trim().isEmpty ? '—' : meta.title.trim();

    return SelectableText(
      title,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
      maxLines: 2,
    );
  }

  Widget _buildMetadataRow(
      BuildContext context, ThemeData theme, ColorScheme scheme) {
    return Wrap(
      spacing: AppSpace.s8,
      runSpacing: AppSpace.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // State pill
        LinearStatePill(state: meta.state),

        // Priority pill (renders empty if no priority)
        LinearPriorityPill(priority: meta.priority),

        // Assignee chip (renders empty if no assignee)
        LinearAssigneeChip(assignee: meta.assignee),

        // Deep link to Linear
        _buildDeepLink(context, theme, scheme),
      ],
    );
  }

  Widget _buildDeepLink(
      BuildContext context, ThemeData theme, ColorScheme scheme) {
    return InkWell(
      onTap: () => _openLinear(context),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s4,
          vertical: AppSpace.s4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.open_in_new,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            Gap.w4,
            Text(
              'Linear',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLinear(BuildContext context) async {
    final url = meta.issueUrl;
    final uri = Uri.tryParse(url);
    if (uri == null) {
      await _copyUrl(context, url);
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        await _copyUrl(context, url);
      }
    } catch (_) {
      if (context.mounted) {
        await _copyUrl(context, url);
      }
    }
  }

  static Future<void> _copyUrl(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied.')),
    );
  }
}
