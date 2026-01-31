import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/focus/focus_session.dart';
import '../../../domain/focus/focus_session_stats.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/spacing.dart';
import '../focus_session_controller.dart';
import '../focus_session_stats_controller.dart';

class FocusHistoryScreen extends ConsumerWidget {
  const FocusHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(focusSessionHistoryProvider);
    final stats = ref.watch(focusSessionStatsProvider);

    return AppScaffold(
      title: 'Session history',
      actions: [
        IconButton(
          tooltip: 'Clear',
          onPressed: () async {
            final controller = ref.read(focusSessionHistoryProvider.notifier);
            final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear history?'),
                    content:
                        const Text('This removes all recorded Focus Sessions.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ) ??
                false;
            if (!ok) return;
            await controller.clear();
          },
          icon: const Icon(Icons.delete_sweep),
        ),
      ],
      children: [
        // Stats card at the top
        _SessionStatsCard(stats: stats),
        Gap.h16,
        // Session history list
        history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s12),
              child: Text('Failed to load history: $e'),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpace.s12),
                  child: Text('No sessions yet.'),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent sessions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Gap.h8,
                for (final s in items) ...[
                  Card(
                    child: ListTile(
                      title: Text(
                        '${DateFormat.yMMMd().add_jm().format(s.startedAt)} → ${DateFormat.jm().format(s.plannedEndAt)}',
                      ),
                      subtitle: Text(
                        'Reason: ${_endReasonLabel(s.endReason)} • Emergency unlocks: ${s.emergencyUnlocksUsed}',
                      ),
                      leading: _endReasonIcon(s.endReason),
                    ),
                  ),
                  Gap.h8,
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  static String _endReasonLabel(FocusSessionEndReason? reason) {
    return switch (reason) {
      FocusSessionEndReason.completed => 'Completed',
      FocusSessionEndReason.userEarlyExit => 'Ended early',
      FocusSessionEndReason.emergencyException => 'Emergency',
      FocusSessionEndReason.engineFailure => 'Engine failure',
      null => '—',
    };
  }

  static Widget _endReasonIcon(FocusSessionEndReason? reason) {
    final (icon, color) = switch (reason) {
      FocusSessionEndReason.completed => (Icons.check_circle, Colors.green),
      FocusSessionEndReason.userEarlyExit => (Icons.exit_to_app, Colors.orange),
      FocusSessionEndReason.emergencyException => (Icons.warning, Colors.red),
      FocusSessionEndReason.engineFailure => (Icons.error, Colors.red),
      null => (Icons.help_outline, Colors.grey),
    };
    return Icon(icon, color: color);
  }
}

class _SessionStatsCard extends StatelessWidget {
  const _SessionStatsCard({required this.stats});

  final FocusSessionStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (stats.totalSessions == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s16),
          child: Column(
            children: [
              Icon(
                Icons.insights,
                size: 48,
                color: scheme.onSurfaceVariant,
              ),
              Gap.h12,
              Text(
                'Complete your first session to see stats',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: scheme.primary),
                Gap.w8,
                Text('Session stats', style: textTheme.titleMedium),
              ],
            ),
            Gap.h16,
            // Main stats row
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Total',
                    value: '${stats.totalSessions}',
                    icon: Icons.timer,
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Focus time',
                    value: _formatDuration(stats.totalFocusDuration),
                    icon: Icons.schedule,
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Streak',
                    value: '${stats.currentStreak} days',
                    icon: Icons.local_fire_department,
                    highlight: stats.currentStreak > 0,
                  ),
                ),
              ],
            ),
            Gap.h16,
            // Completion breakdown
            _CompletionBar(stats: stats),
            Gap.h16,
            // Secondary stats
            Wrap(
              spacing: AppSpace.s16,
              runSpacing: AppSpace.s8,
              children: [
                _MiniStat(
                  label: 'This week',
                  value: '${stats.sessionsThisWeek}',
                ),
                _MiniStat(
                  label: 'This month',
                  value: '${stats.sessionsThisMonth}',
                ),
                _MiniStat(
                  label: 'Avg session',
                  value: '${stats.averageSessionMinutes.toStringAsFixed(0)} min',
                ),
                _MiniStat(
                  label: 'Longest',
                  value: '${stats.longestSessionMinutes} min',
                ),
                if (stats.longestStreak > 0)
                  _MiniStat(
                    label: 'Best streak',
                    value: '${stats.longestStreak} days',
                  ),
                if (stats.mostProductiveDayName != null)
                  _MiniStat(
                    label: 'Best day',
                    value: stats.mostProductiveDayName!,
                  ),
                if (stats.totalEmergencyUnlocksUsed > 0)
                  _MiniStat(
                    label: 'Emergency unlocks',
                    value: '${stats.totalEmergencyUnlocksUsed}',
                    warning: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Icon(
          icon,
          color: highlight ? Colors.orange : scheme.primary,
          size: 28,
        ),
        Gap.h4,
        Text(
          value,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: highlight ? Colors.orange : null,
          ),
        ),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CompletionBar extends StatelessWidget {
  const _CompletionBar({required this.stats});

  final FocusSessionStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final total = stats.totalSessions;
    if (total == 0) return const SizedBox.shrink();

    final completedFrac = stats.completedOnTime / total;
    final earlyFrac = stats.endedEarly / total;
    final emergencyFrac = stats.emergencyEnds / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Completion breakdown',
          style: textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        Gap.h8,
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                if (completedFrac > 0)
                  Expanded(
                    flex: (completedFrac * 100).round(),
                    child: Container(color: Colors.green),
                  ),
                if (earlyFrac > 0)
                  Expanded(
                    flex: (earlyFrac * 100).round(),
                    child: Container(color: Colors.orange),
                  ),
                if (emergencyFrac > 0)
                  Expanded(
                    flex: (emergencyFrac * 100).round(),
                    child: Container(color: Colors.red),
                  ),
              ],
            ),
          ),
        ),
        Gap.h8,
        Wrap(
          spacing: AppSpace.s16,
          runSpacing: AppSpace.s4,
          children: [
            _LegendItem(
              color: Colors.green,
              label: 'Completed (${stats.completedOnTime})',
            ),
            _LegendItem(
              color: Colors.orange,
              label: 'Ended early (${stats.endedEarly})',
            ),
            if (stats.emergencyEnds > 0)
              _LegendItem(
                color: Colors.red,
                label: 'Emergency (${stats.emergencyEnds})',
              ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Gap.w8,
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s8,
      ),
      decoration: BoxDecoration(
        color: warning
            ? scheme.errorContainer.withOpacity(0.3)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: warning ? scheme.error : null,
            ),
          ),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: warning ? scheme.error : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}