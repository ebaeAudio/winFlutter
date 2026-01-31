import 'package:flutter/material.dart';

/// A simple countdown indicator with a linear progress bar above the number.
class CountdownIndicator extends StatelessWidget {
  const CountdownIndicator({
    super.key,
    required this.value,
    required this.progress,
    this.label = 'seconds',
    this.color,
  });

  /// The countdown value to display (e.g., remaining seconds).
  final int value;

  /// Progress from 0.0 (start) to 1.0 (complete).
  final double progress;

  /// Label shown below the number (e.g., "seconds").
  final String label;

  /// Accent color for the progress bar. Defaults to primary.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final barColor = color ?? cs.primary;
    final trackColor = cs.outlineVariant.withOpacity(0.35);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Linear progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: trackColor,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        const SizedBox(height: 24),
        // Countdown number
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Text(
            '$value',
            key: ValueKey<int>(value),
            style: theme.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1,
              color: cs.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
