import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/tasks/task_details_providers.dart';
import '../../../data/linear/linear_issue_repository.dart';
import '../../../data/linear/linear_models.dart';
import '../../focus/focus_ticker_provider.dart';
import '../../../ui/spacing.dart';
import '../../../ui/components/linear_issue_card.dart';
import '../today_controller.dart';
import '../today_models.dart';
import '../today_timebox_controller.dart';
import 'im_stuck_sheet.dart';
import 'starter_step_sheet.dart';

class FocusActionLane extends ConsumerStatefulWidget {
  const FocusActionLane({
    super.key,
    required this.ymd,
    required this.focusModeEnabled,
    required this.focusTask,
    required this.mustWins,
    required this.onScrollToQuickAdd,
  });

  final String ymd;
  final bool focusModeEnabled;
  final TodayTask? focusTask;
  final List<TodayTask> mustWins;
  final VoidCallback onScrollToQuickAdd;

  @override
  ConsumerState<FocusActionLane> createState() => _FocusActionLaneState();
}

class _FocusActionLaneState extends ConsumerState<FocusActionLane> {
  bool _didTryConsumePendingAutoStart = false;
  bool _didScheduleExpiredReconcile = false;
  int? _didScheduleExpiredReconcileForStartedAtMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ref.read(todayControllerProvider(widget.ymd).notifier);
    final timer = ref.watch(todayTimeboxControllerProvider(widget.ymd));

    final focusTask = widget.focusTask;
    final incompleteMustWins =
        widget.mustWins.where((t) => !t.completed).toList(growable: false);

    // If Dumb Phone queued an auto-start, consume it once a focus task exists.
    if (!_didTryConsumePendingAutoStart &&
        widget.focusModeEnabled &&
        focusTask != null) {
      _didTryConsumePendingAutoStart = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final started = await ref
            .read(todayTimeboxControllerProvider(widget.ymd).notifier)
            .maybeConsumePendingAutoStart25m(focusTaskId: focusTask.id);
        if (!context.mounted) return;
        if (started) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('25‑minute timebox started')),
          );
        }
      });
    }

    final isRunning = timer != null;
    final isBreak = timer?.kind == TodayTimerKind.break_;
    final isFocusTimer = timer?.kind == TodayTimerKind.focus;

    String? nextStep;
    String? notesText;
    LinearIssueRef? linearRef;
    if (focusTask != null) {
      final detailsRepo = ref.watch(taskDetailsRepositoryProvider);
      if (detailsRepo == null) {
        nextStep = focusTask.nextStep;
        notesText = (focusTask.notes ?? focusTask.details ?? '').trim();
      } else {
        final detailsAsync = ref.watch(taskDetailsProvider(focusTask.id));
        final details = detailsAsync.valueOrNull;
        nextStep = details?.nextStep;
        notesText = (details?.notes ?? '').trim();
      }
    }
    if (notesText != null && notesText.isNotEmpty) {
      linearRef = LinearIssueRef.tryParseFromText(notesText);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'One thing now',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Gap.h8,
            Text(
              widget.focusModeEnabled
                  ? 'Hide the noise. Just do the next tiny step.'
                  : 'Turn this on when you’re feeling stuck or scattered.',
              style: theme.textTheme.bodyMedium,
            ),
            Gap.h12,
            if (!widget.focusModeEnabled)
              Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                children: [
                  FilledButton.icon(
                    onPressed: widget.mustWins.isEmpty
                        ? null
                        : () async {
                            await controller.setFocusModeEnabled(true);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Focus mode on')),
                            );
                          },
                    icon: const Icon(Icons.center_focus_strong),
                    label: const Text('Start focus'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onScrollToQuickAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('Add a Must‑Win'),
                  ),
                ],
              )
            else ...[
              if (focusTask == null)
                Text(
                  widget.mustWins.isEmpty
                      ? 'Add a Must‑Win, then focus on it.'
                      : 'No Must‑Wins left. Nice work.',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                )
              else ...[
                _FocusTaskHeader(title: focusTask.title),
                Gap.h12,
                if (linearRef != null) ...[
                  Builder(
                    builder: (context) {
                      final repo = ref.watch(linearIssueRepositoryProvider);
                      if (repo == null) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpace.s12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.20),
                            border: Border.all(
                                color: theme.dividerColor.withOpacity(0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Linear link detected',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Gap.h8,
                              OutlinedButton.icon(
                                onPressed: () => context.go('/settings'),
                                icon: const Icon(Icons.settings),
                                label: const Text('Set up Linear'),
                              ),
                            ],
                          ),
                        );
                      }

                      final issueAsync = ref.watch(
                        linearIssueByIdentifierProvider(linearRef!.identifier),
                      );
                      return issueAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpace.s8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              Gap.w12,
                              Text('Loading Linear…'),
                            ],
                          ),
                        ),
                        error: (_, __) => Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpace.s12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: theme.colorScheme.errorContainer
                                .withOpacity(0.20),
                            border: Border.all(
                                color: theme.dividerColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            'Could not load Linear issue.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                        data: (issue) {
                          if (issue == null) return const SizedBox.shrink();
                          return LinearIssueCard(
                            issue: issue,
                            compact: true,
                            onRefresh: () => ref.invalidate(
                              linearIssueByIdentifierProvider(
                                  linearRef!.identifier),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  Gap.h12,
                ],
                _StarterStepBlock(
                  taskId: focusTask.id,
                  nextStep: nextStep,
                  onAddStarterStep: () => _openStarterStep(context,
                      ymd: widget.ymd, task: focusTask),
                ),
                Gap.h12,
                if (isBreak)
                  _TimerPanel(
                    timer: timer!,
                    ymd: widget.ymd,
                    kind: TodayTimerKind.break_,
                    onSwitchTask: () => _switchTask(
                      context,
                      ymd: widget.ymd,
                      mustWins: widget.mustWins,
                      isTimerRunning: isRunning,
                    ),
                    onEndEarly: () => ref
                        .read(
                            todayTimeboxControllerProvider(widget.ymd).notifier)
                        .endEarly(),
                    onAddFive: () => ref
                        .read(
                            todayTimeboxControllerProvider(widget.ymd).notifier)
                        .addMinutes(5),
                    didScheduleExpiredReconcile: _didScheduleExpiredReconcile,
                    didScheduleExpiredReconcileForStartedAtMs:
                        _didScheduleExpiredReconcileForStartedAtMs,
                    onMarkExpiredReconcileScheduled: (startedAtMs) {
                      setState(() {
                        _didScheduleExpiredReconcile = true;
                        _didScheduleExpiredReconcileForStartedAtMs =
                            startedAtMs;
                      });
                    },
                  )
                else if (isFocusTimer)
                  _TimerPanel(
                    timer: timer!,
                    ymd: widget.ymd,
                    kind: TodayTimerKind.focus,
                    onSwitchTask: () => _switchTask(
                      context,
                      ymd: widget.ymd,
                      mustWins: widget.mustWins,
                      isTimerRunning: isRunning,
                    ),
                    onEndEarly: () => ref
                        .read(
                            todayTimeboxControllerProvider(widget.ymd).notifier)
                        .endEarly(),
                    onAddFive: () => ref
                        .read(
                            todayTimeboxControllerProvider(widget.ymd).notifier)
                        .addMinutes(5),
                    didScheduleExpiredReconcile: _didScheduleExpiredReconcile,
                    didScheduleExpiredReconcileForStartedAtMs:
                        _didScheduleExpiredReconcileForStartedAtMs,
                    onMarkExpiredReconcileScheduled: (startedAtMs) {
                      setState(() {
                        _didScheduleExpiredReconcile = true;
                        _didScheduleExpiredReconcileForStartedAtMs =
                            startedAtMs;
                      });
                    },
                  )
                else
                  _StartTimerBlock(
                    disabled: isRunning,
                    onStartMinutes: (m) => _startFocusTimer(
                      context,
                      ymd: widget.ymd,
                      taskId: focusTask.id,
                      minutes: m,
                    ),
                  ),
                Gap.h12,
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s8,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        await controller.toggleTaskCompleted(focusTask.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Marked done')),
                        );
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Done'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openImStuck(
                        context,
                        ymd: widget.ymd,
                        focusTask: focusTask,
                        incompleteMustWins: incompleteMustWins,
                      ),
                      icon: const Icon(Icons.help_outline),
                      label: const Text('I’m stuck'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _switchTask(
                        context,
                        ymd: widget.ymd,
                        mustWins: widget.mustWins,
                        isTimerRunning: isRunning,
                      ),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Switch task'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (isRunning) {
                          await ref
                              .read(todayTimeboxControllerProvider(widget.ymd)
                                  .notifier)
                              .endEarly();
                        }
                        await controller.setFocusTaskId(null);
                        await controller.setFocusModeEnabled(false);
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Exit'),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startFocusTimer(
    BuildContext context, {
    required String ymd,
    required String taskId,
    required int minutes,
  }) async {
    final ok = await ref
        .read(todayTimeboxControllerProvider(ymd).notifier)
        .startFocus(taskId: taskId, minutes: minutes);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timer already running')),
      );
    }
  }

  Future<void> _switchTask(
    BuildContext context, {
    required String ymd,
    required List<TodayTask> mustWins,
    required bool isTimerRunning,
  }) async {
    final incomplete =
        mustWins.where((t) => !t.completed).toList(growable: false);
    if (incomplete.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No incomplete Must‑Wins')),
      );
      return;
    }

    if (isTimerRunning) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('End the timer first?'),
          content: const Text(
            'To keep things simple, switching tasks ends the current timer.',
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
      if (ok != true) return;
      await ref.read(todayTimeboxControllerProvider(ymd).notifier).endEarly();
      if (!context.mounted) return;
    }

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final shown = incomplete.take(8).toList(growable: false);
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.s16),
            shrinkWrap: true,
            children: [
              Text(
                'Switch focus',
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
    if (picked == null) return;
    if (!context.mounted) return;
    await ref
        .read(todayControllerProvider(ymd).notifier)
        .setFocusTaskId(picked);
  }

  Future<void> _openImStuck(
    BuildContext context, {
    required String ymd,
    required TodayTask focusTask,
    required List<TodayTask> incompleteMustWins,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ImStuckSheet(
        ymd: ymd,
        focusTask: focusTask,
        incompleteMustWins: incompleteMustWins,
      ),
    );
  }
}

class _FocusTaskHeader extends StatelessWidget {
  const _FocusTaskHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.primaryContainer.withOpacity(0.35),
        border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: SelectionArea(
        child: Text(
          title,
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _StarterStepBlock extends StatelessWidget {
  const _StarterStepBlock({
    required this.taskId,
    required this.nextStep,
    required this.onAddStarterStep,
  });

  final String taskId;
  final String? nextStep;
  final VoidCallback onAddStarterStep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = (nextStep ?? '').trim();

    if (text.isEmpty) {
      return OutlinedButton.icon(
        onPressed: onAddStarterStep,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Add a 2‑minute starter step'),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next 2 minutes',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Gap.h4,
          Text(text, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _StartTimerBlock extends StatelessWidget {
  const _StartTimerBlock({
    required this.disabled,
    required this.onStartMinutes,
  });

  final bool disabled;
  final Future<void> Function(int minutes) onStartMinutes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            FilledButton(
              onPressed: disabled ? null : () => onStartMinutes(2),
              child: const Text('Start (2 min)'),
            ),
            for (final m in const [10, 15, 25, 45])
              OutlinedButton(
                onPressed: disabled ? null : () => onStartMinutes(m),
                child: Text('$m'),
              ),
          ],
        ),
      ],
    );
  }
}

class _FocusTimerBlock extends StatelessWidget {
  const _FocusTimerBlock({
    required this.remaining,
    required this.wrapUpSoon,
    required this.onAddFive,
    required this.onEndEarly,
    required this.onSwitchTask,
  });

  final Duration remaining;
  final bool wrapUpSoon;
  final VoidCallback onAddFive;
  final VoidCallback onEndEarly;
  final VoidCallback onSwitchTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatRemaining(remaining),
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (wrapUpSoon) ...[
            Gap.h4,
            Text(
              'Wrap up soon',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
          Gap.h12,
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              FilledButton(
                onPressed: onAddFive,
                child: const Text('+5 min'),
              ),
              OutlinedButton(
                onPressed: onEndEarly,
                child: const Text('End early'),
              ),
              OutlinedButton.icon(
                onPressed: onSwitchTask,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Switch task'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakTimerBlock extends StatelessWidget {
  const _BreakTimerBlock({
    required this.remaining,
    required this.onEndEarly,
  });

  final Duration remaining;
  final VoidCallback onEndEarly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.secondaryContainer.withOpacity(0.25),
        border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Break',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Gap.h4,
          Text(
            _formatRemaining(remaining),
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          Gap.h12,
          OutlinedButton(
            onPressed: onEndEarly,
            child: const Text('End break'),
          ),
        ],
      ),
    );
  }
}

class _TimerPanel extends ConsumerWidget {
  const _TimerPanel({
    required this.timer,
    required this.ymd,
    required this.kind,
    required this.onAddFive,
    required this.onEndEarly,
    required this.onSwitchTask,
    required this.didScheduleExpiredReconcile,
    required this.didScheduleExpiredReconcileForStartedAtMs,
    required this.onMarkExpiredReconcileScheduled,
  });

  final ActiveTodayTimer timer;
  final String ymd;
  final TodayTimerKind kind;
  final VoidCallback onAddFive;
  final VoidCallback onEndEarly;
  final VoidCallback onSwitchTask;

  final bool didScheduleExpiredReconcile;
  final int? didScheduleExpiredReconcileForStartedAtMs;
  final void Function(int startedAtMs) onMarkExpiredReconcileScheduled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();
    final raw = timer.endsAt.difference(now);
    final remaining = raw.isNegative ? Duration.zero : raw;

    final showWrapUpSoon = (kind == TodayTimerKind.focus) &&
        remaining > Duration.zero &&
        remaining <= const Duration(minutes: 2);

    // Best-effort clear expired timers, but only schedule once per timer instance.
    if (remaining == Duration.zero &&
        !(didScheduleExpiredReconcile &&
            didScheduleExpiredReconcileForStartedAtMs == timer.startedAtMs)) {
      onMarkExpiredReconcileScheduled(timer.startedAtMs);
      final timeboxController =
          ref.read(todayTimeboxControllerProvider(ymd).notifier);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await timeboxController.reconcileExpiredNow();
      });
    }

    if (kind == TodayTimerKind.break_) {
      return _BreakTimerBlock(remaining: remaining, onEndEarly: onEndEarly);
    }
    return _FocusTimerBlock(
      remaining: remaining,
      wrapUpSoon: showWrapUpSoon,
      onAddFive: onAddFive,
      onEndEarly: onEndEarly,
      onSwitchTask: onSwitchTask,
    );
  }
}

String _formatRemaining(Duration d) {
  if (d.isNegative) return '0:00';
  final m = d.inMinutes;
  final s = d.inSeconds - (m * 60);
  return '$m:${s.toString().padLeft(2, '0')}';
}

Future<bool> _openStarterStep(
  BuildContext context, {
  required String ymd,
  required TodayTask task,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => StarterStepSheet(ymd: ymd, task: task),
  ).then((v) => v == true);
}
