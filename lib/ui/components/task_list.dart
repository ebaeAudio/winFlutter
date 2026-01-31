import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../spacing.dart';

/// A production-grade list surface for tasks.
///
/// Design system: Uses `kRadiusMedium` (12px) for container corners.
/// Uses dividers between items instead of spacing to maintain density.
class TaskListCard extends StatelessWidget {
  const TaskListCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(vertical: AppSpace.s4),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusMedium),
      child: Card(
        child: Padding(
          padding: padding,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TaskListRow extends StatelessWidget {
  const TaskListRow({
    super.key,
    required this.title,
    required this.completed,
    required this.leading,
    required this.onTap,
    this.metadata,
    this.trailing,
    this.onSecondaryTap,
  });

  final String title;
  final bool completed;
  final Widget leading;
  final VoidCallback? onTap;
  final Widget? metadata;
  final Widget? trailing;

  /// Called when the user right-clicks (or secondary taps) on the row.
  /// The [Offset] is the global position of the tap.
  final void Function(Offset globalPosition)? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
      color: completed
          ? theme.colorScheme.onSurfaceVariant.withOpacity(0.95)
          : theme.colorScheme.onSurface,
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: onSecondaryTap != null
          ? (details) => onSecondaryTap!(details.globalPosition)
          : null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return theme.colorScheme.onSurface.withOpacity(0.06);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return theme.colorScheme.onSurface.withOpacity(0.04);
          }
          return null;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s12,
            vertical: AppSpace.s8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s4),
                child: leading,
              ),
              Gap.w12,
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: completed ? 0.78 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      if (metadata != null) ...[
                        Gap.h4,
                        DefaultTextStyle(
                          style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withOpacity(0.95),
                              ) ??
                              const TextStyle(),
                          child: metadata!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (trailing != null) ...[
                Gap.w8,
                trailing!,
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}
