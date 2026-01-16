import 'dart:async';

import 'package:flutter/material.dart';

class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    super.key,
    required this.holdDuration,
    required this.onConfirmed,
    required this.label,
    this.icon,
    this.enabled = true,
    this.busyLabel,
  });

  final Duration holdDuration;
  final Future<void> Function() onConfirmed;
  final String label;
  final IconData? icon;
  final bool enabled;
  final String? busyLabel;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton> {
  Timer? _timer;
  double _progress = 0;
  bool _busy = false;

  void _start() {
    if (!widget.enabled || _busy) return;
    _timer?.cancel();
    final start = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) async {
      if (_busy || !widget.enabled) return;
      final elapsed = DateTime.now().difference(start);
      final p = (elapsed.inMilliseconds / widget.holdDuration.inMilliseconds)
          .clamp(0.0, 1.0);
      if (!mounted) return;
      setState(() => _progress = p);
      if (p >= 1.0) {
        _timer?.cancel();
        // Immediately reset the hold UI and switch to a "busy" state so users
        // don't feel like the button is stuck at 100% while async work runs.
        setState(() {
          _progress = 0;
          _busy = true;
        });
        unawaited(() async {
          try {
            await widget.onConfirmed();
          } finally {
            if (mounted) {
              setState(() => _busy = false);
            }
          }
        }());
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
    final icon = _busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          )
        : Icon(widget.icon ?? Icons.lock);

    final label = Text(_busy ? (widget.busyLabel ?? widget.label) : widget.label);

    // Use Listener instead of GestureDetector with tap callbacks.
    // Tap gestures have a ~500ms timeout after which onTapCancel fires,
    // which breaks hold-to-confirm for durations longer than that.
    // Pointer events don't have this timeout issue.
    return Listener(
      onPointerDown: (_) => _start(),
      onPointerUp: (_) => _cancel(),
      onPointerCancel: (_) => _cancel(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: null,
              icon: icon,
              label: label,
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
