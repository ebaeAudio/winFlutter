import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/linear/linear_models.dart';
import '../spacing.dart';

class LinearIssueCard extends StatelessWidget {
  const LinearIssueCard({
    super.key,
    required this.issue,
    this.compact = false,
    this.onRefresh,
  });

  final LinearIssue issue;
  final bool compact;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stateLabel = _stateLabel(issue.state.type);
    final assignee = (issue.assigneeName ?? '').trim();
    final title = issue.title.trim().isEmpty ? '—' : issue.title.trim();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpace.s12 : AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    issue.identifier,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                _StatePill(type: issue.state.type, label: stateLabel),
              ],
            ),
            Gap.h4,
            Text(
              title,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: compact ? FontWeight.w600 : FontWeight.w700),
            ),
            if (!compact && assignee.isNotEmpty) ...[
              Gap.h4,
              Text(
                'Assignee: $assignee',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            Gap.h12,
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                FilledButton.icon(
                  onPressed: () => _open(context, issue.url),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _copy(context, issue.url),
                  icon: const Icon(Icons.link),
                  label: const Text('Copy link'),
                ),
                if (onRefresh != null)
                  TextButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _stateLabel(String type) {
    final t = type.trim().toLowerCase();
    if (t.isEmpty) return 'State';
    return switch (t) {
      'started' => 'Started',
      'completed' => 'Done',
      'unstarted' => 'Todo',
      'backlog' => 'Backlog',
      'triage' => 'Triage',
      'canceled' => 'Canceled',
      _ => type,
    };
  }

  static Future<void> _copy(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied.')),
    );
  }

  static Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      await _copy(context, url);
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        if (!context.mounted) return;
        await _copy(context, url);
      }
    } catch (_) {
      if (!context.mounted) return;
      await _copy(context, url);
    }
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.type, required this.label});

  final String type;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = type.trim().toLowerCase();
    final (bg, fg) = switch (t) {
      'completed' => (theme.colorScheme.primaryContainer, theme.colorScheme.onPrimaryContainer),
      'started' => (theme.colorScheme.secondaryContainer, theme.colorScheme.onSecondaryContainer),
      'canceled' => (theme.colorScheme.errorContainer, theme.colorScheme.onErrorContainer),
      _ => (
          theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
          theme.colorScheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s8,
        vertical: AppSpace.s4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

