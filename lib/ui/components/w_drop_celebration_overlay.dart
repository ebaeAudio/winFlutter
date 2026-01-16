import 'dart:math';

import 'package:flutter/material.dart';

class WDropCelebrationOverlay extends StatefulWidget {
  const WDropCelebrationOverlay({
    super.key,
    required this.play,
    this.onCompleted,
    this.onSpawn,
    this.particleCount = 60,
    this.emitDuration = const Duration(seconds: 3),
    this.fallDuration = const Duration(milliseconds: 1800),
    this.random,
  });

  /// When this flips from false -> true, the animation plays once.
  final bool play;

  /// Called after the animation completes.
  final VoidCallback? onCompleted;

  /// Called once per spawned W (useful for per-particle feedback).
  final VoidCallback? onSpawn;

  /// Total particles emitted over [emitDuration].
  final int particleCount;

  /// How long we keep spawning new W's.
  final Duration emitDuration;

  /// How long each W takes to fall through the screen after it spawns.
  final Duration fallDuration;

  /// Optional RNG injection (useful for deterministic widget tests).
  final Random? random;

  @override
  State<WDropCelebrationOverlay> createState() => _WDropCelebrationOverlayState();
}

class _WDropCelebrationOverlayState extends State<WDropCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Random _rng;
  List<_WParticle> _particles = const [];
  int _nextSpawnIndex = 0;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _rng = widget.random ?? Random();
    _controller = AnimationController(
      vsync: this,
      duration: widget.emitDuration + widget.fallDuration,
    )
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          widget.onCompleted?.call();
        }
      });
    _controller.addListener(_handleSpawns);
  }

  @override
  void didUpdateWidget(covariant WDropCelebrationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.emitDuration != oldWidget.emitDuration ||
        widget.fallDuration != oldWidget.fallDuration) {
      _controller.duration = widget.emitDuration + widget.fallDuration;
    }
    if (widget.play && !oldWidget.play) {
      _start();
    }
  }

  void _start() {
    // Precompute spawn offsets so W's continuously appear over [emitDuration].
    _particles = List.generate(
      widget.particleCount,
      (_) => _WParticle.random(
        _rng,
        spawnAt: Duration(
          microseconds:
              (_rng.nextDouble() * widget.emitDuration.inMicroseconds).round(),
        ),
      ),
      growable: false,
    );
    _particles = _particles.toList(growable: false)
      ..sort((a, b) => a.spawnAt.compareTo(b.spawnAt));
    _nextSpawnIndex = 0;
    _lastElapsed = Duration.zero;
    _controller.forward(from: 0);
  }

  void _handleSpawns() {
    final duration = _controller.duration;
    if (duration == null) return;
    final elapsed = duration * _controller.value;
    if (elapsed < _lastElapsed) {
      _lastElapsed = elapsed;
      return;
    }
    _lastElapsed = elapsed;

    // Emit callbacks for every W that becomes "active" this frame.
    while (_nextSpawnIndex < _particles.length &&
        _particles[_nextSpawnIndex].spawnAt <= elapsed) {
      widget.onSpawn?.call();
      _nextSpawnIndex++;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleSpawns);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.play) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final colors = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.primaryContainer,
      scheme.tertiaryContainer,
    ];

    return IgnorePointer(
      ignoring: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final elapsed = _controller.duration! * _controller.value;
            return LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final p in _particles)
                      _WParticleView(
                        particle: p,
                        elapsed: elapsed,
                        emitDuration: widget.emitDuration,
                        fallDuration: widget.fallDuration,
                        width: w,
                        height: h,
                        color: colors[p.colorIndex % colors.length],
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _WParticle {
  const _WParticle({
    required this.x01,
    required this.size,
    required this.rotationTurns,
    required this.phase,
    required this.drift01,
    required this.startY01,
    required this.endY01,
    required this.colorIndex,
    required this.spawnAt,
  });

  /// Horizontal spawn location, normalized 0..1.
  final double x01;

  final double size;

  /// Total rotations over the full animation (in turns, not radians).
  final double rotationTurns;

  final double phase;

  /// Horizontal drift magnitude (normalized).
  final double drift01;

  /// Starting Y position above the viewport, normalized.
  final double startY01;

  /// Ending Y position below the viewport, normalized.
  final double endY01;

  final int colorIndex;

  /// When this particle begins falling (time since animation start).
  final Duration spawnAt;

  factory _WParticle.random(Random rng, {required Duration spawnAt}) {
    return _WParticle(
      x01: rng.nextDouble(),
      size: (18 + rng.nextInt(22)).toDouble(), // 18..39
      rotationTurns: 0.5 + rng.nextDouble() * 2.0,
      phase: rng.nextDouble() * pi * 2,
      drift01: 0.10 + rng.nextDouble() * 0.30,
      startY01: 0.10 + rng.nextDouble() * 0.45,
      endY01: 1.05 + rng.nextDouble() * 0.25,
      colorIndex: rng.nextInt(8),
      spawnAt: spawnAt,
    );
  }
}

class _WParticleView extends StatelessWidget {
  const _WParticleView({
    required this.particle,
    required this.elapsed,
    required this.emitDuration,
    required this.fallDuration,
    required this.width,
    required this.height,
    required this.color,
  });

  final _WParticle particle;
  final Duration elapsed;
  final Duration emitDuration;
  final Duration fallDuration;
  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dt = elapsed - particle.spawnAt;
    if (dt.isNegative) return const SizedBox.shrink();
    final rawT =
        dt.inMicroseconds / fallDuration.inMicroseconds.clamp(1, 1 << 62);
    if (rawT >= 1.0) return const SizedBox.shrink();

    final t = Curves.easeIn.transform(rawT.clamp(0.0, 1.0));
    final xBase = particle.x01 * width;
    final driftPx = particle.drift01 * width * 0.25;
    final x = xBase + sin((t * pi * 2) + particle.phase) * driftPx;

    final startY = -(particle.startY01 * height) - particle.size;
    final endY = particle.endY01 * height;
    final y = startY + (endY - startY) * t;

    final turns = particle.rotationTurns * t;

    return Positioned(
      left: x,
      top: y,
      child: Transform.rotate(
        angle: turns * pi * 2,
        child: Text(
          'W',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: particle.size,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1.0,
              ),
        ),
      ),
    );
  }
}

