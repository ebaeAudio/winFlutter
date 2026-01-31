import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/tasks/all_tasks_models.dart';
import '../../../ui/spacing.dart';

/// Inline warning banner for zombie tasks.
///
/// Compact design with left icon, muted body copy, and tertiary Review button.
class ZombieTaskAlertCard extends ConsumerWidget {
  const ZombieTaskAlertCard({
    super.key,
    required this.zombies,
    this.onOpen,
  });

  final List<AllTask> zombies;

  /// Called when the user taps "Open" or the card itself.
  /// If null, defaults to navigating to `/tasks?scope=overdue`.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (zombies.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = zombies.length;
    final title = count == 1 ? '1 zombie task' : '$count zombie tasks';

    void openReview() {
      if (onOpen != null) {
        onOpen!();
      } else {
        context.go('/tasks/cleanup');
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: openReview,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12,
          vertical: AppSpace.s8,
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 20,
              color: scheme.onTertiaryContainer,
            ),
            Gap.w8,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                  Text(
                    'Tasks stuck 3+ days drain energy.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onTertiaryContainer.withOpacity(0.75),
                    ),
                  ),
                ],
              ),
            ),
            Gap.w8,
            TextButton(
              onPressed: openReview,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 36),
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
              ),
              child: const Text('Open'),
            ),
          ],
        ),
      ),
    );
  }
}

