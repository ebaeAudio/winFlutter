import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../spacing.dart';

/// Animated “conversation” border that feels alive while a user is speaking.
///
/// - When [active] is false, renders [child] with no border.
/// - When [active] is true, paints a subtle rotating sweep-gradient stroke
///   around the child that pulses based on [level] (0..1).
class ConversationBorder extends StatefulWidget {
  const ConversationBorder({
    super.key,
    required this.child,
    required this.active,
    required this.level,
  });

  final Widget child;
  final bool active;

  /// Normalized activity level in the range 0..1.
  final double level;

  @override
  State<ConversationBorder> createState() => _ConversationBorderState();
}

class _ConversationBorderState extends State<ConversationBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  static const double _outerPadding = AppSpace.s4;
  static const double _minStroke = 2.25;
  static const double _maxStroke = 4.5; // _minStroke + (1.0 * 2.25)

  @override
  void initState() {
    super.initState();
    if (widget.active) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant ConversationBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.active && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: keep layout size stable across active/inactive states.
    // If we only add padding while active, the FAB will "jump" as listening toggles.
    return Padding(
      padding: const EdgeInsets.all(_outerPadding),
      child: widget.active
          ? AnimatedBuilder(
              animation: _spin,
              builder: (context, _) {
                final scheme = Theme.of(context).colorScheme;

                // On some platforms sound level callbacks can be flat/rare, so we
                // include a subtle baseline pulse to keep it feeling alive.
                final inputLevel = widget.level.clamp(0.0, 1.0);
                final wobble =
                    (math.sin(_spin.value * math.pi * 2 * 2) + 1) / 2; // 0..1
                final baseline = 0.10 + wobble * 0.22; // subtle when quiet
                final level = math.max(inputLevel, baseline);

                final thickness = _minStroke + level * (_maxStroke - _minStroke);
                final glow = 0.10 + level * 0.22;

                return CustomPaint(
                  // foregroundPainter so the ring draws ON TOP of the FAB.
                  foregroundPainter: _ConversationBorderPainter(
                    colorA: scheme.primary,
                    colorB: scheme.secondary,
                    rotationTurns: _spin.value,
                    strokeWidth: thickness,
                    glowOpacity: glow,
                    // Keep the path stable even as strokeWidth changes.
                    baseInset: _maxStroke / 2,
                  ),
                  child: widget.child,
                );
              },
            )
          : widget.child,
    );
  }
}

class _ConversationBorderPainter extends CustomPainter {
  const _ConversationBorderPainter({
    required this.colorA,
    required this.colorB,
    required this.rotationTurns,
    required this.strokeWidth,
    required this.glowOpacity,
    required this.baseInset,
  });

  final Color colorA;
  final Color colorB;
  final double rotationTurns;
  final double strokeWidth;
  final double glowOpacity;
  final double baseInset;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Approximate the extended FAB shape (stadium).
    final rect = Offset.zero & size;
    final inset = baseInset;
    final inner = rect.deflate(inset);
    final radius = inner.height / 2;
    final rrect =
        RRect.fromRectAndRadius(inner, Radius.circular(radius.clamp(0.0, radius)));

    final center = rect.center;
    final angle = rotationTurns * math.pi * 2;
    final shader = SweepGradient(
      startAngle: angle,
      endAngle: angle + math.pi * 2,
      colors: [
        colorA.withOpacity(0.10),
        colorA.withOpacity(0.95),
        colorB.withOpacity(0.90),
        colorA.withOpacity(0.20),
      ],
      stops: const [0.0, 0.38, 0.72, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: math.max(size.width, size.height)));

    // Soft outer glow.
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 3
      ..color = colorA.withOpacity(glowOpacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(rrect, glowPaint);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = shader;
    canvas.drawRRect(rrect, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ConversationBorderPainter oldDelegate) {
    return colorA != oldDelegate.colorA ||
        colorB != oldDelegate.colorB ||
        rotationTurns != oldDelegate.rotationTurns ||
        strokeWidth != oldDelegate.strokeWidth ||
        glowOpacity != oldDelegate.glowOpacity ||
        baseInset != oldDelegate.baseInset;
  }
}

