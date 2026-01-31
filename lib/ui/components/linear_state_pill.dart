import 'package:flutter/material.dart';

import '../../data/linear/linear_issue_meta.dart';
import '../spacing.dart';

/// A compact pill displaying Linear issue state.
///
/// Design system: Uses 999px radius for pill shape (fully rounded).
/// Semantic colors based on state type (backlog, started, completed, canceled).
class LinearStatePill extends StatelessWidget {
  const LinearStatePill({
    super.key,
    required this.state,
    this.compact = false,
  });

  final LinearStateMeta state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (bg, fg) = switch (state.type) {
      LinearStateType.completed => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      LinearStateType.started => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      LinearStateType.canceled => (
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
      LinearStateType.backlog || LinearStateType.unknown => (
          scheme.surfaceContainerHighest.withOpacity(0.5),
          scheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpace.s8 : AppSpace.s12,
        vertical: AppSpace.s4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        state.name.isEmpty ? _fallbackLabel(state.type) : state.name,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String _fallbackLabel(LinearStateType type) {
    return switch (type) {
      LinearStateType.backlog => 'Backlog',
      LinearStateType.started => 'In Progress',
      LinearStateType.completed => 'Done',
      LinearStateType.canceled => 'Canceled',
      LinearStateType.unknown => 'Unknown',
    };
  }
}
