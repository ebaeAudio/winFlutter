import 'package:flutter/material.dart';

import '../spacing.dart';

/// A production-grade list surface for tasks:
/// - calm Material 3 surface
/// - subtle dividers (theme-driven)
/// - clipped ink ripples (good desktop/web hover/press)
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
      borderRadius: BorderRadius.circular(16),
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
  });

  final String title;
  final bool completed;
  final Widget leading;
  final VoidCallback? onTap;
  final Widget? metadata;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
      color: completed
          ? theme.colorScheme.onSurfaceVariant.withOpacity(0.95)
          : theme.colorScheme.onSurface,
    );

    return Material(
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
    );
  }
}

