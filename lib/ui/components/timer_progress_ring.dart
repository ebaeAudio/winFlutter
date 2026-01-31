import 'package:flutter/material.dart';

class TimerProgressRing extends StatelessWidget {
  const TimerProgressRing({
    super.key,
    required this.progress,
    required this.color,
    required this.child,
    this.size = 84,
    this.strokeWidth = 6,
    this.trackColor,
  });

  final double progress;
  final Color color;
  final Widget child;
  final double size;
  final double strokeWidth;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = progress.clamp(0.0, 1.0);
    final track =
        trackColor ?? theme.colorScheme.outlineVariant.withOpacity(0.35);
    final duration = _animationDuration(context);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<Color?>(
            duration: duration,
            tween: ColorTween(end: color),
            builder: (context, animatedColor, _) {
              return CircularProgressIndicator(
                value: clamped,
                strokeWidth: strokeWidth,
                strokeCap: StrokeCap.round,
                backgroundColor: track,
                valueColor:
                    AlwaysStoppedAnimation<Color>(animatedColor ?? color),
              );
            },
          ),
          Padding(
            padding: EdgeInsets.all(strokeWidth + 8),
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}

class TimerRemainingBar extends StatelessWidget {
  const TimerRemainingBar({
    super.key,
    required this.remainingFraction,
    required this.color,
    this.height = 8,
    this.trackColor,
  });

  final double remainingFraction;
  final Color color;
  final double height;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = remainingFraction.clamp(0.0, 1.0);
    final track =
        trackColor ?? theme.colorScheme.outlineVariant.withOpacity(0.35);
    final duration = _animationDuration(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: TweenAnimationBuilder<Color?>(
        duration: duration,
        tween: ColorTween(end: color),
        builder: (context, animatedColor, _) {
          return LinearProgressIndicator(
            value: clamped,
            minHeight: height,
            backgroundColor: track,
            valueColor: AlwaysStoppedAnimation<Color>(animatedColor ?? color),
          );
        },
      ),
    );
  }
}

Duration _animationDuration(BuildContext context) {
  final media = MediaQuery.maybeOf(context);
  if (media != null && media.disableAnimations) {
    return Duration.zero;
  }
  return const Duration(milliseconds: 240);
}
