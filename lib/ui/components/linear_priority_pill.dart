import 'package:flutter/material.dart';

import '../../data/linear/linear_issue_meta.dart';
import '../spacing.dart';

/// A compact pill displaying Linear issue priority.
///
/// Returns empty if priority is not set (none).
/// Design system: Uses 999px radius for pill shape.
class LinearPriorityPill extends StatelessWidget {
  const LinearPriorityPill({
    super.key,
    required this.priority,
    this.compact = false,
  });

  final LinearPriorityMeta priority;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Don't render anything for "no priority"
    if (!priority.hasPriority) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (bg, fg, icon) = switch (priority.level) {
      LinearPriorityLevel.urgent => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.keyboard_double_arrow_up,
        ),
      LinearPriorityLevel.high => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.keyboard_arrow_up,
        ),
      LinearPriorityLevel.medium => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          Icons.remove,
        ),
      LinearPriorityLevel.low => (
          scheme.surfaceContainerHighest.withOpacity(0.5),
          scheme.onSurfaceVariant.withOpacity(0.7),
          Icons.keyboard_arrow_down,
        ),
      LinearPriorityLevel.none => (
          Colors.transparent,
          Colors.transparent,
          Icons.remove,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          Gap.w4,
          Text(
            priority.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
