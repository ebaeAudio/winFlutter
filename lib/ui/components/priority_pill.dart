import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../spacing.dart';

/// A pill-shaped tag displaying task priority.
///
/// Uses semantic colors to convey importance level.
///
/// Design system: Uses `kRadiusSmall` (8px) for pill shape.
/// Meets 44px minimum tap target when interactive.
class PriorityPill extends StatelessWidget {
  const PriorityPill({
    super.key,
    required this.priority,
    this.onTap,
  });

  final TaskPriorityValue priority;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (bg, fg) = switch (priority) {
      TaskPriorityValue.mustWin => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      TaskPriorityValue.niceToDo => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
    };

    final child = Container(
      // 44px minimum tap target for accessibility
      constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s8,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(kRadiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (priority == TaskPriorityValue.mustWin) ...[
            Icon(Icons.star, size: 16, color: fg),
            Gap.w4,
          ],
          Text(
            priority.label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
          if (onTap != null) ...[
            Gap.w4,
            Icon(Icons.unfold_more, size: 16, color: fg),
          ],
        ],
      ),
    );

    if (onTap == null) return child;

    return Semantics(
      button: true,
      label: 'Priority: ${priority.label}. Tap to change.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusSmall),
        child: child,
      ),
    );
  }
}

/// Priority values for a task.
enum TaskPriorityValue {
  mustWin,
  niceToDo;

  String get label => switch (this) {
        TaskPriorityValue.mustWin => 'Must-Win',
        TaskPriorityValue.niceToDo => 'Nice-to-Do',
      };
}
