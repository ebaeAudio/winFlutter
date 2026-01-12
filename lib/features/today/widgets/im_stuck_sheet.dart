import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/spacing.dart';
import '../today_controller.dart';
import '../today_models.dart';
import '../today_timebox_controller.dart';
import 'starter_step_sheet.dart';

class ImStuckSheet extends ConsumerWidget {
  const ImStuckSheet({
    super.key,
    required this.ymd,
    required this.focusTask,
    required this.incompleteMustWins,
  });

  final String ymd;
  final TodayTask focusTask;
  final List<TodayTask> incompleteMustWins;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timer = ref.watch(todayTimeboxControllerProvider(ymd));
    final isRunning = timer != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'I’m stuck',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Gap.h8,
            Text(
              'Pick one quick move. No shame, just momentum.',
              style: theme.textTheme.bodyMedium,
            ),
            Gap.h12,
            _ActionTile(
              icon: Icons.compress,
              title: 'Make it smaller',
              subtitle: 'Write a 2-minute starter step',
              onTap: () async {
                Navigator.of(context).pop();
                final saved = await _showStarterStepSheet(
                  context,
                  ref: ref,
                  ymd: ymd,
                  task: focusTask,
                );
                if (saved && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Starter step saved')),
                  );
                }
              },
            ),
            _ActionTile(
              icon: Icons.swap_horiz,
              title: 'Switch focus',
              subtitle: 'Pick a different Must‑Win',
              onTap: incompleteMustWins.isEmpty
                  ? null
                  : () async {
                      final ok = await _confirmEndTimerIfNeeded(
                        context,
                        isRunning: isRunning,
                        onEnd: () => ref
                            .read(todayTimeboxControllerProvider(ymd).notifier)
                            .endEarly(),
                      );
                      if (!ok) return;
                      if (!context.mounted) return;

                      final picked = await _pickMustWin(
                        context,
                        tasks: incompleteMustWins,
                      );
                      if (picked == null) return;
                      if (!context.mounted) return;

                      await ref
                          .read(todayControllerProvider(ymd).notifier)
                          .setFocusTaskId(picked);
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
            ),
            _ActionTile(
              icon: Icons.coffee_outlined,
              title: 'Take a 5-minute break',
              subtitle: 'Then come right back here',
              onTap: () async {
                // Keep things predictable: only one timer at a time.
                if (timer != null) {
                  await ref
                      .read(todayTimeboxControllerProvider(ymd).notifier)
                      .endEarly();
                }
                if (!context.mounted) return;

                final started = await ref
                    .read(todayTimeboxControllerProvider(ymd).notifier)
                    .startBreak(minutes: 5, returnToTaskId: focusTask.id);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                if (started) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Break started')),
                  );
                }
              },
            ),
            if (incompleteMustWins.isEmpty) ...[
              Gap.h8,
              Text(
                'No incomplete Must‑Wins to switch to.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Future<String?> _pickMustWin(
    BuildContext context, {
    required List<TodayTask> tasks,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final shown = tasks.take(8).toList(growable: false);
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.s16),
            shrinkWrap: true,
            children: [
              Text(
                'Pick a Must‑Win',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Gap.h12,
              for (final t in shown)
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(t.title),
                  onTap: () => Navigator.of(context).pop(t.id),
                ),
            ],
          ),
        );
      },
    );
  }

  static Future<bool> _confirmEndTimerIfNeeded(
    BuildContext context, {
    required bool isRunning,
    required Future<void> Function() onEnd,
  }) async {
    if (!isRunning) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End the timer first?'),
        content: const Text(
          'To keep things simple and predictable, the current timer will end before switching.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End timer'),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    await onEnd();
    return true;
  }

  static Future<bool> _showStarterStepSheet(
    BuildContext context, {
    required WidgetRef ref,
    required String ymd,
    required TodayTask task,
  }) async {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StarterStepSheet(ymd: ymd, task: task),
    ).then((v) => v == true);
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
      enabled: onTap != null,
    );
  }
}

