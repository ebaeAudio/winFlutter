import 'package:flutter/material.dart';

import '../spacing.dart';

/// A dropdown for selecting task status.
///
/// Shows current status with a dropdown arrow; opens a menu on tap.
class StatusDropdown extends StatelessWidget {
  const StatusDropdown({
    super.key,
    required this.status,
    required this.onStatusChanged,
    this.enabled = true,
  });

  final TaskStatusValue status;
  final ValueChanged<TaskStatusValue> onStatusChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PopupMenuButton<TaskStatusValue>(
      enabled: enabled,
      onSelected: onStatusChanged,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        for (final s in TaskStatusValue.values)
          PopupMenuItem(
            value: s,
            height: 48,
            child: Row(
              children: [
                Icon(
                  s.icon,
                  size: 20,
                  color: s == status ? scheme.primary : scheme.onSurfaceVariant,
                ),
                Gap.w12,
                Text(
                  s.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: s == status ? FontWeight.w600 : FontWeight.w400,
                    color: s == status ? scheme.primary : null,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12,
          vertical: AppSpace.s8,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: 18, color: scheme.onSurfaceVariant),
            Gap.w8,
            Text(
              status.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Gap.w4,
            Icon(Icons.arrow_drop_down, size: 20, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Status values for a task.
enum TaskStatusValue {
  notStarted,
  inProgress,
  completed;

  String get label => switch (this) {
        TaskStatusValue.notStarted => 'Not Started',
        TaskStatusValue.inProgress => 'In Progress',
        TaskStatusValue.completed => 'Completed',
      };

  IconData get icon => switch (this) {
        TaskStatusValue.notStarted => Icons.radio_button_unchecked,
        TaskStatusValue.inProgress => Icons.play_circle_outline,
        TaskStatusValue.completed => Icons.check_circle_outline,
      };
}
