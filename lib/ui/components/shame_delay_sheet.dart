import 'dart:async';

import 'package:flutter/material.dart';

import '../spacing.dart';
import 'countdown_indicator.dart';

class ShameDelaySheet extends StatefulWidget {
  const ShameDelaySheet({
    super.key,
    required this.delaySeconds,
    this.messages,
  });

  static Future<void> show(
    BuildContext context, {
    required int delaySeconds,
    List<String>? messages,
  }) async {
    if (delaySeconds <= 0) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      enableDrag: true,
      isDismissible: true,
      isScrollControlled: true,
      builder: (ctx) => ShameDelaySheet(
        delaySeconds: delaySeconds,
        messages: messages,
      ),
    );
  }

  final int delaySeconds;
  final List<String>? messages;

  @override
  State<ShameDelaySheet> createState() => _ShameDelaySheetState();
}

class _ShameDelaySheetState extends State<ShameDelaySheet> {
  Timer? _countdownTimer;
  Timer? _messageTimer;

  late DateTime _endAt;
  int _remainingSeconds = 0;
  int _messageIndex = 0;

  List<String> get _messages {
    final custom = widget.messages;
    if (custom != null && custom.isNotEmpty) return custom;
    return const [
        "You're really doing this?",
        'Quitting already? Classic.',
        'This is the part where you prove you meant it.',
        'You held the button. Now sit with it.',
        'The phone wins when you rush.',
        'Don’t negotiate with your impulse.',
        'Future you is going to remember this.',
        'You wanted discipline. This is it.',
        'If it was easy, you would already have it.',
        'Stay uncomfortable for a moment.',
        'We both know what you’re trying to do.',
      ];
  }

  @override
  void initState() {
    super.initState();
    _endAt = DateTime.now().add(Duration(seconds: widget.delaySeconds));
    _tick(); // initialize UI immediately
    _startTimers();
  }

  void _startTimers() {
    _countdownTimer?.cancel();
    _countdownTimer =
        Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());

    _messageTimer?.cancel();
    if (_messages.length <= 1) return;
    _messageTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (!mounted) return;
      setState(() {
        _messageIndex = (_messageIndex + 1) % _messages.length;
      });
    });
  }

  void _tick() {
    final remaining = _endAt.difference(DateTime.now());
    final nextRemainingSeconds = remaining.inSeconds.clamp(0, widget.delaySeconds);
    if (!mounted) return;

    if (nextRemainingSeconds != _remainingSeconds) {
      setState(() => _remainingSeconds = nextRemainingSeconds);
    }

    if (remaining.inMilliseconds <= 0) {
      _countdownTimer?.cancel();
      _messageTimer?.cancel();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final total = widget.delaySeconds <= 0 ? 1 : widget.delaySeconds;
    final remainingFraction = _remainingSeconds / total;
    final progress = 1.0 - remainingFraction;

    final message = _messages.isEmpty ? 'Wait.' : _messages[_messageIndex];

    return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpace.s16,
            right: AppSpace.s16,
            top: AppSpace.s16,
            bottom: AppSpace.s16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ending early',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Gap.h8,
              Text(
                'You chose to quit. Now wait.',
                style: theme.textTheme.bodyMedium,
              ),
              Gap.h24,
              CountdownIndicator(
                value: _remainingSeconds,
                progress: progress,
                label: 'seconds',
                color: cs.primary,
              ),
              Gap.h24,
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.2),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  message,
                  key: ValueKey<String>(message),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Gap.h8,
              Text(
                'This is intentional. The pause is the point.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
  }
}

