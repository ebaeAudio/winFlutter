import 'dart:async';

import 'package:flutter/material.dart';

class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    super.key,
    required this.holdDuration,
    required this.onConfirmed,
    required this.label,
    this.icon,
  });

  final Duration holdDuration;
  final Future<void> Function() onConfirmed;
  final String label;
  final IconData? icon;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton> {
  Timer? _timer;
  double _progress = 0;

  void _start() {
    _timer?.cancel();
    final start = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) async {
      final elapsed = DateTime.now().difference(start);
      final p = (elapsed.inMilliseconds / widget.holdDuration.inMilliseconds)
          .clamp(0.0, 1.0);
      if (!mounted) return;
      setState(() => _progress = p);
      if (p >= 1.0) {
        _timer?.cancel();
        await widget.onConfirmed();
        if (!mounted) return;
        setState(() => _progress = 0);
      }
    });
  }

  void _cancel() {
    _timer?.cancel();
    setState(() => _progress = 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _start(),
      onTapUp: (_) => _cancel(),
      onTapCancel: _cancel,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: null,
              icon: Icon(widget.icon ?? Icons.lock),
              label: Text(widget.label),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _progress,
                    child: Container(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.25),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
