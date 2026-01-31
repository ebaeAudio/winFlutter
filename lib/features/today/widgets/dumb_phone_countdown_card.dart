import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/focus/focus_session.dart';
import '../../../ui/components/timer_progress_ring.dart';
import '../../../ui/spacing.dart';
import '../../focus/focus_ticker_provider.dart';

/// A prominent countdown card that displays when a dumb phone session is active.
///
/// Shows a large animated countdown, progress ring, and motivational messaging
/// to keep users engaged and focused during their session.
class DumbPhoneCountdownCard extends ConsumerWidget {
  const DumbPhoneCountdownCard({
    super.key,
    required this.session,
    this.isRemote = false,
    this.sourcePlatformLabel,
  });

  final FocusSession session;

  /// Whether this session is running on another device (e.g., iPhone).
  final bool isRemote;

  /// User-friendly label for the source device (e.g., "iPhone", "Mac").
  final String? sourcePlatformLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowTickerProvider).valueOrNull ?? DateTime.now();
    final remaining = session.plannedEndAt.difference(now);
    final remainingClamped = remaining.isNegative ? Duration.zero : remaining;

    final totalDuration = session.plannedEndAt.difference(session.startedAt);
    final elapsed = now.difference(session.startedAt);
    final progress = totalDuration.inSeconds > 0
        ? (elapsed.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0)
        : 0.0;
    final remainingFraction = 1.0 - progress;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Dynamic accent color based on time remaining
    final accentColor = _countdownAccentColor(scheme, remainingFraction);

    // Format time as mm:ss or hh:mm:ss for longer sessions
    final timeDisplay = _formatCountdown(remainingClamped);
    final isExpired = remainingClamped == Duration.zero;

    // Motivational message based on progress
    final motivationalMessage = _motivationalMessage(progress, isExpired);

    return GestureDetector(
      onTap: () => context.go('/focus'),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withOpacity(0.15),
              scheme.surfaceContainerHighest.withOpacity(0.4),
            ],
          ),
          border: Border.all(
            color: accentColor.withOpacity(0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s24),
          child: Column(
            children: [
              // Header row with icon and label
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpace.s8),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.phone_android,
                      color: accentColor,
                      size: 20,
                    ),
                  ),
                  Gap.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'DUMB PHONE MODE',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: accentColor,
                              ),
                            ),
                            if (isRemote && sourcePlatformLabel != null) ...[
                              Gap.w8,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.s8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  sourcePlatformLabel!,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Gap.h4,
                        Text(
                          isExpired
                              ? 'Session complete!'
                              : isRemote
                                  ? 'Running on another device'
                                  : 'Stay focused',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: scheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                ],
              ),

              const SizedBox(height: AppSpace.s24),

              // Large countdown display with progress ring
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Progress ring with time
                  Semantics(
                    label: 'Time remaining',
                    value: timeDisplay,
                    child: TimerProgressRing(
                      progress: progress,
                      color: accentColor,
                      size: 140,
                      strokeWidth: 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeDisplay,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [FontFeature.tabularFigures()],
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            'remaining',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: AppSpace.s24),

                  // Right side: motivational text and timing info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Motivational message with smooth crossfade transition
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.15),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            motivationalMessage,
                            key: ValueKey(motivationalMessage),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),

                        Gap.h12,

                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: scheme.outlineVariant.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation(accentColor),
                          ),
                        ),

                        Gap.h12,

                        // Time details row
                        Row(
                          children: [
                            _TimeChip(
                              icon: Icons.play_arrow,
                              label: DateFormat.Hm().format(session.startedAt),
                              color: scheme.onSurfaceVariant,
                            ),
                            Gap.w8,
                            Icon(
                              Icons.arrow_forward,
                              size: 12,
                              color: scheme.onSurfaceVariant.withOpacity(0.5),
                            ),
                            Gap.w8,
                            _TimeChip(
                              icon: Icons.flag,
                              label: DateFormat.Hm().format(session.plannedEndAt),
                              color: accentColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              Gap.h16,

              // Bottom hint
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s12,
                  vertical: AppSpace.s8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 14,
                      color: scheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                    Gap.w8,
                    Text(
                      'Tap for session controls',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _countdownAccentColor(ColorScheme scheme, double remainingFraction) {
    // Green when plenty of time, yellow when getting low, red when almost done
    if (remainingFraction > 0.5) {
      return scheme.primary;
    } else if (remainingFraction > 0.25) {
      return const Color(0xFFFF9800); // Amber/orange
    } else if (remainingFraction > 0.1) {
      return const Color(0xFFFF5722); // Deep orange
    } else {
      return scheme.error; // Red when < 10% remaining
    }
  }

  String _formatCountdown(Duration d) {
    if (d.isNegative) return '0:00';

    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _motivationalMessage(double progress, bool isExpired) {
    if (isExpired) {
      return 'Great work! Session complete.';
    }

    if (progress < 0.1) {
      return "You've got this. Deep work starts now.";
    } else if (progress < 0.25) {
      return 'Building momentum. Keep going!';
    } else if (progress < 0.5) {
      return "You're crushing it. Stay in the zone.";
    } else if (progress < 0.75) {
      return 'Past the halfway mark! Finish strong.';
    } else if (progress < 0.9) {
      return 'Almost there. You can do this!';
    } else {
      return "Final stretch! Don't stop now.";
    }
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: AppSpace.s4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ],
    );
  }
}
