import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/focus/pomodoro_timer.dart';
import '../../../../ui/spacing.dart';
import '../../focus_ticker_provider.dart';
import '../../pomodoro_timer_controller.dart';

class PomodoroTimerCard extends ConsumerStatefulWidget {
  const PomodoroTimerCard({super.key, this.compact = false});

  /// If true, uses slightly tighter copy for dense screens.
  final bool compact;

  @override
  ConsumerState<PomodoroTimerCard> createState() => _PomodoroTimerCardState();
}

class _PomodoroTimerCardState extends ConsumerState<PomodoroTimerCard> {
  int? _didScheduleReconcileForStartedAtMs;

  @override
  void didUpdateWidget(covariant PomodoroTimerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.compact != widget.compact) {
      // no-op; keep state
    }
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(pomodoroTimerControllerProvider);
    final controller = ref.read(pomodoroTimerControllerProvider.notifier);

    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();
    final remaining = timer.remainingAt(now);
    final progress = timer.progressAt(now);

    // If we hit 0, reconcile once per run (avoid provider writes during build).
    if (timer.status == PomodoroStatus.running &&
        remaining == Duration.zero &&
        timer.startedAtMs != null &&
        _didScheduleReconcileForStartedAtMs != timer.startedAtMs) {
      _didScheduleReconcileForStartedAtMs = timer.startedAtMs;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.reconcileExpiredNow();
      });
    }

    final isFocus = timer.phase == PomodoroPhase.focus;
    final phaseLabel = isFocus ? 'Focus' : 'Break';
    final nextLabel = isFocus ? 'break' : 'focus';
    final mmss = _formatMmSs(remaining);

    const focusDurations = [15, 25, 45];
    const breakDurations = [5, 10, 15];
    final selectedMinutes = isFocus ? timer.focusMinutes : timer.breakMinutes;
    final allowed = isFocus ? focusDurations : breakDurations;

    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isFocus ? Icons.timer : Icons.coffee,
                    color: scheme.onSurfaceVariant,),
                Gap.w12,
                Expanded(
                  child: Text(
                    'Pomodoro timer',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (timer.completedFocusCount > 0)
                  Text(
                    '${timer.completedFocusCount} done',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            Gap.h8,
            Text(
              '$phaseLabel • $mmss',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Gap.h8,
            LinearProgressIndicator(
              value: timer.status == PomodoroStatus.idle ? 0 : progress,
            ),
            Gap.h12,
            Text(
              timer.status == PomodoroStatus.idle
                  ? 'Pick a duration, then start. When it hits 0, it flips to $nextLabel.'
                  : timer.status == PomodoroStatus.paused
                      ? 'Paused.'
                      : 'Running.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Gap.h12,
            SegmentedButton<int>(
              segments: [
                for (final m in allowed)
                  ButtonSegment<int>(value: m, label: Text('${m}m')),
              ],
              selected: {selectedMinutes},
              onSelectionChanged: (v) async {
                final next = v.isEmpty ? selectedMinutes : v.first;
                if (isFocus) {
                  await controller.setFocusMinutes(next);
                } else {
                  await controller.setBreakMinutes(next);
                }
              },
            ),
            Gap.h12,
            Row(
              children: [
                Expanded(
                  child: _PrimaryButton(
                    timer: timer,
                    onPressed: () async {
                      if (timer.status == PomodoroStatus.idle) {
                        await controller.start();
                        return;
                      }
                      if (timer.status == PomodoroStatus.running) {
                        await controller.pause();
                        return;
                      }
                      if (timer.status == PomodoroStatus.paused) {
                        await controller.resume();
                        return;
                      }
                    },
                  ),
                ),
                Gap.w12,
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: timer.status == PomodoroStatus.idle
                        ? null
                        : () async => controller.reset(),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset'),
                  ),
                ),
              ],
            ),
            if (!widget.compact) ...[
              Gap.h12,
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: timer.status == PomodoroStatus.idle
                          ? null
                          : () async => controller.addMinutes(5),
                      icon: const Icon(Icons.add),
                      label: const Text('+5 min'),
                    ),
                  ),
                  Gap.w12,
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: timer.status == PomodoroStatus.idle
                          ? null
                          : () async => controller.addMinutes(-5),
                      icon: const Icon(Icons.remove),
                      label: const Text('-5 min'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatMmSs(Duration d) {
    final total = d.inSeconds.clamp(0, 24 * 60 * 60);
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.timer, required this.onPressed});

  final PomodoroTimerState timer;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (timer.status) {
      PomodoroStatus.idle => (
          Icons.play_arrow,
          timer.phase == PomodoroPhase.focus ? 'Start focus' : 'Start break'
        ),
      PomodoroStatus.running => (Icons.pause, 'Pause'),
      PomodoroStatus.paused => (Icons.play_arrow, 'Resume'),
    };

    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
