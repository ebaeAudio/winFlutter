import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../spacing.dart';

class ClownCamGateSheet extends StatefulWidget {
  const ClownCamGateSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    if (kIsWeb) return false;
    final ok = await showModalBottomSheet<bool>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (ctx) => const ClownCamGateSheet(),
        ) ??
        false;
    return ok;
  }

  @override
  State<ClownCamGateSheet> createState() => _ClownCamGateSheetState();
}

class _ClownCamGateSheetState extends State<ClownCamGateSheet> {
  CameraController? _controller;
  Object? _initError;
  bool _busy = false;

  bool get _ready =>
      _controller != null && _controller!.value.isInitialized && !_busy;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    setState(() {
      _busy = true;
      _initError = null;
    });

    try {
      final cams = await availableCameras();
      final front = cams.where((c) => c.lensDirection == CameraLensDirection.front);
      final chosen = front.isNotEmpty ? front.first : (cams.isNotEmpty ? cams.first : null);
      if (chosen == null) {
        throw StateError('No cameras available on this device.');
      }

      final controller = CameraController(
        chosen,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _initError = e;
      });
    }
  }

  Future<void> _captureAndSave(BuildContext context) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;

    setState(() {
      _busy = true;
      _initError = null;
    });

    try {
      final shot = await c.takePicture();
      final bytes = await shot.readAsBytes();
      final pngBytes = await _renderOverlayedPng(context, bytes);
      await _saveClownPhoto(pngBytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved clown cam photo on this device.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save clown cam photo: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _busy = false;
      });
    }
  }

  Future<Uint8List> _renderOverlayedPng(
    BuildContext context,
    Uint8List bytes,
  ) async {
    final base = await _decodeImage(bytes);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(base.width.toDouble(), base.height.toDouble());

    canvas.drawImage(base, Offset.zero, Paint());
    _ClownOverlayPainter(Theme.of(context)).paint(canvas, size);

    final picture = recorder.endRecording();
    final out = await picture.toImage(base.width, base.height);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('Failed to encode clown cam image.');
    }
    return data.buffer.asUint8List();
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  Future<File> _saveClownPhoto(Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/clown_cam_$stamp.png');
    return file.writeAsBytes(bytes, flush: true);
  }

  @override
  void dispose() {
    final c = _controller;
    _controller = null;
    if (c != null) {
      unawaited(c.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpace.s16,
          right: AppSpace.s16,
          top: AppSpace.s8,
          bottom: AppSpace.s16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Clown check',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Gap.h8,
            Text(
              'Ending early is allowed — but make it awkward on purpose.',
              style: theme.textTheme.bodyMedium,
            ),
            Gap.h12,
            Text(
              'Look into the camera for 2 seconds. We will save a photo with the overlay.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Gap.h12,
            _CameraFrame(
              controller: _controller,
              busy: _busy,
              error: _initError,
              onRetry: _init,
            ),
            Gap.h12,
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Nevermind'),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: _ready ? () => _captureAndSave(context) : null,
                    child: const Text('Save & end early'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraFrame extends StatelessWidget {
  const _CameraFrame({
    required this.controller,
    required this.busy,
    required this.error,
    required this.onRetry,
  });

  final CameraController? controller;
  final bool busy;
  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final c = controller;
    final hasPreview = c != null && c.value.isInitialized;

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          child: Stack(
            children: [
              if (hasPreview) Positioned.fill(child: CameraPreview(c)),
              Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ClownOverlayPainter(theme)))),
              if (busy && !hasPreview)
                const Center(child: CircularProgressIndicator()),
              if (error != null)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.s12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: theme.colorScheme.error),
                        Gap.h8,
                        Text(
                          'Camera not available.',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Gap.h8,
                        Text(
                          '$error',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Gap.h12,
                        OutlinedButton.icon(
                          onPressed: busy ? null : onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClownOverlayPainter extends CustomPainter {
  _ClownOverlayPainter(this._theme);

  final ThemeData _theme;

  @override
  void paint(Canvas canvas, Size size) {
    final cs = _theme.colorScheme;

    // Static overlay (no face tracking): position relative to center.
    final cx = size.width / 2;
    final cy = size.height / 2;

    final faceW = size.width * 0.55;
    final faceH = size.height * 0.55;

    // Slight vignette to make it feel "real" but still readable.
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          cs.surface.withOpacity(0.25),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);

    // Nose.
    final nosePaint = Paint()..color = Colors.redAccent.withOpacity(0.9);
    canvas.drawCircle(Offset(cx, cy + faceH * 0.05), faceW * 0.085, nosePaint);

    // Cheeks.
    final cheekPaint = Paint()..color = Colors.pinkAccent.withOpacity(0.35);
    canvas.drawCircle(Offset(cx - faceW * 0.22, cy + faceH * 0.08), faceW * 0.11, cheekPaint);
    canvas.drawCircle(Offset(cx + faceW * 0.22, cy + faceH * 0.08), faceW * 0.11, cheekPaint);

    // Eye triangles (blue).
    final eyePaint = Paint()..color = Colors.lightBlueAccent.withOpacity(0.55);
    Path tri(Offset tip, Offset left, Offset right) =>
        Path()..moveTo(tip.dx, tip.dy)..lineTo(left.dx, left.dy)..lineTo(right.dx, right.dy)..close();

    final leftEye = Offset(cx - faceW * 0.18, cy - faceH * 0.08);
    final rightEye = Offset(cx + faceW * 0.18, cy - faceH * 0.08);
    canvas.drawPath(
      tri(
        Offset(leftEye.dx, leftEye.dy - faceH * 0.12),
        Offset(leftEye.dx - faceW * 0.10, leftEye.dy + faceH * 0.02),
        Offset(leftEye.dx + faceW * 0.10, leftEye.dy + faceH * 0.02),
      ),
      eyePaint,
    );
    canvas.drawPath(
      tri(
        Offset(rightEye.dx, rightEye.dy - faceH * 0.12),
        Offset(rightEye.dx - faceW * 0.10, rightEye.dy + faceH * 0.02),
        Offset(rightEye.dx + faceW * 0.10, rightEye.dy + faceH * 0.02),
      ),
      eyePaint,
    );

    // Smile arc.
    final smilePaint = Paint()
      ..color = cs.onSurface.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, size.shortestSide * 0.008);

    final smileRect = Rect.fromCenter(
      center: Offset(cx, cy + faceH * 0.18),
      width: faceW * 0.55,
      height: faceH * 0.28,
    );
    canvas.drawArc(smileRect, 0.1, 3.0, false, smilePaint);

    // Caption.
    final tp = TextPainter(
      text: TextSpan(
        text: 'END EARLY MODE',
        style: _theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: cs.onSurface.withOpacity(0.85),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height - tp.height - 12));
  }

  @override
  bool shouldRepaint(covariant _ClownOverlayPainter oldDelegate) => false;
}

