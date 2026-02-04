import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/focus/pomodoro_timer.dart';
import '../../features/focus/focus_ticker_provider.dart';
import '../../features/focus/pomodoro_timer_controller.dart';
import '../../features/focus/remote_focus_session_provider.dart';
import '../../features/today/today_timebox_controller.dart';
import '../spacing.dart';

/// Displays active timers in the sidebar with a modern, simple UI.
///
/// Shows:
/// - Pomodoro timer (if running)
/// - Focus session (if active)
/// - Today timer (if running)
class ActiveTimersDisplay extends ConsumerWidget {
  const ActiveTimersDisplay({
    super.key,
    required this.isExpanded,
  });

  final bool isExpanded;

  static String _formatYmd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Watch all timer sources
    final pomodoroTimer = ref.watch(pomodoroTimerControllerProvider);
    final todayYmd = _formatYmd(now);
    final todayTimer = ref.watch(todayTimeboxControllerProvider(todayYmd));

    // Collect active timers
    final activeTimers = <_TimerInfo>[];

    // Pomodoro timer
    if (pomodoroTimer.status == PomodoroStatus.running ||
        pomodoroTimer.status == PomodoroStatus.paused) {
      final remaining = pomodoroTimer.remainingAt(now);
      final isPaused = pomodoroTimer.status == PomodoroStatus.paused;
      final phaseLabel = pomodoroTimer.phase == PomodoroPhase.focus
          ? 'Focus'
          : 'Break';
      activeTimers.add(_TimerInfo(
        label: 'Pomodoro • $phaseLabel',
        remaining: remaining,
        isPaused: isPaused,
        icon: pomodoroTimer.phase == PomodoroPhase.focus
            ? Icons.timer
            : Icons.coffee,
        color: pomodoroTimer.phase == PomodoroPhase.focus
            ? scheme.primary
            : scheme.secondary,
      ),);
    }

    // Focus session (local or remote from another device)
    final combinedSession = ref.watch(combinedFocusSessionProvider);
    if (combinedSession != null && combinedSession.isActive) {
      final remaining = combinedSession.remaining;
      if (remaining > Duration.zero) {
        activeTimers.add(_TimerInfo(
          label: combinedSession.displayLabel,
          remaining: remaining,
          isPaused: false,
          icon: combinedSession.isRemote ? Icons.phone_iphone : Icons.lock,
          color: scheme.primary,
          isRemote: combinedSession.isRemote,
        ),);
      }
    }

    // Today timer
    if (todayTimer != null) {
      final controller = ref.read(todayTimeboxControllerProvider(todayYmd).notifier);
      final remaining = controller.remainingAt(now);
      if (remaining > Duration.zero) {
        final kindLabel = todayTimer.kind == TodayTimerKind.focus
            ? 'Focus'
            : 'Break';
        activeTimers.add(_TimerInfo(
          label: 'Today • $kindLabel',
          remaining: remaining,
          isPaused: false,
          icon: todayTimer.kind == TodayTimerKind.focus
              ? Icons.timer_outlined
              : Icons.coffee_outlined,
          color: todayTimer.kind == TodayTimerKind.focus
              ? scheme.primary
              : scheme.secondary,
        ),);
      }
    }

    // Don't render anything if no active timers
    if (activeTimers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isExpanded ? AppSpace.s12 : AppSpace.s8,
        vertical: AppSpace.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isExpanded) ...[
            Text(
              'Active Timers',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant.withOpacity(0.7),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            Gap.h8,
          ],
          ...activeTimers.map((timer) => _TimerItem(
                timer: timer,
                isExpanded: isExpanded,
              ),),
        ],
      ),
    );
  }
}

class _TimerInfo {
  const _TimerInfo({
    required this.label,
    required this.remaining,
    required this.isPaused,
    required this.icon,
    required this.color,
    this.isRemote = false,
  });

  final String label;
  final Duration remaining;
  final bool isPaused;
  final IconData icon;
  final Color color;

  /// Whether this timer is from a remote device (e.g., iPhone session on Mac).
  final bool isRemote;
}

class _TimerItem extends StatelessWidget {
  const _TimerItem({
    required this.timer,
    required this.isExpanded,
  });

  final _TimerInfo timer;
  final bool isExpanded;

  static String _formatDuration(Duration d) {
    final total = d.inSeconds.clamp(0, 24 * 60 * 60);
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final timeText = _formatDuration(timer.remaining);

    if (!isExpanded) {
      // Collapsed: just show icon with time badge
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s4),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.s8),
          decoration: BoxDecoration(
            color: timer.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: timer.color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                timer.icon,
                size: 20,
                color: timer.color,
              ),
              Gap.h4,
              Text(
                timeText,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: timer.color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              if (timer.isPaused) ...[
                Gap.h4,
                Icon(
                  Icons.pause,
                  size: 10,
                  color: timer.color.withOpacity(0.7),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Expanded: show full timer info
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s12),
        decoration: BoxDecoration(
          color: timer.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: timer.color.withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: timer.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                timer.icon,
                size: 16,
                color: timer.color,
              ),
            ),
            Gap.w8,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timer.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap.h(AppSpace.s4),
                  Row(
                    children: [
                      Text(
                        timeText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: timer.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (timer.isPaused) ...[
                        Gap.w8,
                        Icon(
                          Icons.pause,
                          size: 12,
                          color: timer.color.withOpacity(0.7),
                        ),
                        Gap.w8,
                        Text(
                          'Paused',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: timer.color.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
