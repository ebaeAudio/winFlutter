import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/user_settings.dart';

// TEMP: hard kill-switch while we stabilize production-worthy SFX.
// When ready, flip to false (or remove) and rely on the Settings toggle.
const bool kSoundsTemporarilyDisabled = true;

/// App-wide "small dopamine" sounds.
///
/// These are intentionally short + calm, and synthesized at runtime to avoid
/// shipping binary sound assets.
enum AppSfx {
  taskComplete,
  bigWin,
  habitComplete,
  trackerUp,
  trackerDown,
  assistantDone,
  focusStart,
  focusEnd,
  pomodoroFlip,
  error,
  wDrop,
}

final soundServiceProvider = Provider<SoundService>((ref) {
  final service = SoundService();
  final settings = ref.watch(userSettingsControllerProvider);
  service.setEnabled(!kSoundsTemporarilyDisabled && settings.soundsEnabled);
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

class SoundService {
  SoundService() {
    // Avoid odd looping defaults; these are "one-shot" cues.
    unawaited(_player.setReleaseMode(ReleaseMode.stop));
    for (final p in _rapidPlayers) {
      unawaited(p.setReleaseMode(ReleaseMode.stop));
    }
  }

  final AudioPlayer _player = AudioPlayer();
  final List<AudioPlayer> _rapidPlayers =
      List<AudioPlayer>.generate(5, (_) => AudioPlayer(), growable: false);
  int _rapidIdx = 0;
  bool _enabled = true;
  final Map<AppSfx, String> _fileCache = <AppSfx, String>{};
  final Map<AppSfx, Uint8List> _wavCache = <AppSfx, Uint8List>{};

  // Very light global cooldown so we don't "machine-gun" during rapid taps.
  static const Duration _globalCooldown = Duration(milliseconds: 90);
  int _lastAnyMs = 0;

  // Per-sfx cooldowns.
  final Map<AppSfx, int> _lastSfxMs = <AppSfx, int>{};
  int _lastRapidMs = 0;

  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  Future<void> dispose() async {
    await _player.dispose();
    for (final p in _rapidPlayers) {
      await p.dispose();
    }
  }

  Duration _cooldownFor(AppSfx sfx) {
    return switch (sfx) {
      AppSfx.bigWin => const Duration(milliseconds: 400),
      AppSfx.error => const Duration(milliseconds: 250),
      AppSfx.pomodoroFlip => const Duration(milliseconds: 450),
      AppSfx.focusStart || AppSfx.focusEnd => const Duration(milliseconds: 450),
      AppSfx.wDrop => const Duration(milliseconds: 35),
      _ => const Duration(milliseconds: 160),
    };
  }

  Future<void> play(AppSfx sfx) async {
    if (kSoundsTemporarilyDisabled) return;
    if (!_enabled) return;
    if (kIsWeb) return; // Keep web quiet + avoid format issues.

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastAnyMs < _globalCooldown.inMilliseconds) return;
    final lastMs = _lastSfxMs[sfx] ?? 0;
    if (nowMs - lastMs < _cooldownFor(sfx).inMilliseconds) return;

    _lastAnyMs = nowMs;
    _lastSfxMs[sfx] = nowMs;

    try {
      // Build tone and play from memory.
      final wav = _wavCache[sfx] ??= _buildWavFor(sfx);
      await _player.stop();
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android supports bytes sources.
        await _player.play(
          BytesSource(wav),
          volume: _volumeFor(sfx),
        );
      } else {
        // iOS/macOS/windows/linux: write once to temp, then play as a file.
        final path = await _ensureTempFile(sfx: sfx, wav: wav);
        await _player.play(
          DeviceFileSource(path),
          volume: _volumeFor(sfx),
        );
      }
    } catch (e) {
      // Best-effort only; never break UX for sound failures.
      if (kDebugMode) {
        debugPrint('SoundService.play($sfx) failed: $e');
      }
    }
  }

  /// A best-effort "spammy" path for very short UI effects (like raining W's).
  ///
  /// Uses a small AudioPlayer pool so overlapping plays don't cut each other off.
  /// Still applies a tiny global rapid cooldown to avoid blowing up the audio
  /// engine on slow devices.
  Future<void> playRapid(AppSfx sfx) async {
    if (kSoundsTemporarilyDisabled) return;
    if (!_enabled) return;
    if (kIsWeb) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // Keep this extremely small; we want "per particle" ticks to still work.
    if (nowMs - _lastRapidMs < 18) return;
    _lastRapidMs = nowMs;

    try {
      final wav = _wavCache[sfx] ??= _buildWavFor(sfx);
      final p = _rapidPlayers[_rapidIdx % _rapidPlayers.length];
      _rapidIdx++;

      if (defaultTargetPlatform == TargetPlatform.android) {
        await p.play(
          BytesSource(wav),
          volume: _volumeForRapid(sfx),
        );
      } else {
        final path = await _ensureTempFile(sfx: sfx, wav: wav);
        await p.play(
          DeviceFileSource(path),
          volume: _volumeForRapid(sfx),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SoundService.playRapid($sfx) failed: $e');
      }
    }
  }

  Future<String> _ensureTempFile({
    required AppSfx sfx,
    required Uint8List wav,
  }) async {
    final cached = _fileCache[sfx];
    if (cached != null && cached.isNotEmpty) return cached;

    final dir = await getTemporaryDirectory();
    final folder = Directory('${dir.path}/win_flutter_sfx');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final filePath = '${folder.path}/sfx_${sfx.name}.wav';
    final f = File(filePath);
    if (!await f.exists()) {
      await f.writeAsBytes(wav, flush: true);
    }
    _fileCache[sfx] = filePath;
    return filePath;
  }

  double _volumeFor(AppSfx sfx) {
    // Keep overall volume low; "bigWin" can be slightly higher but still calm.
    return switch (sfx) {
      AppSfx.bigWin => 0.65,
      AppSfx.error => 0.45,
      AppSfx.wDrop => 0.28,
      _ => 0.55,
    };
  }

  double _volumeForRapid(AppSfx sfx) {
    // Rapid events should be subtle.
    return switch (sfx) {
      AppSfx.wDrop => 0.22,
      _ => 0.30,
    };
  }

  Uint8List _buildWavFor(AppSfx sfx) {
    // 16-bit PCM, mono.
    const sampleRate = 44100;
    final (freqHz, durationMs, waveform) = switch (sfx) {
      AppSfx.taskComplete => (880.0, 80, _Waveform.sine),
      AppSfx.bigWin => (660.0, 160, _Waveform.triangle),
      AppSfx.habitComplete => (740.0, 75, _Waveform.sine),
      AppSfx.trackerUp => (990.0, 45, _Waveform.sine),
      AppSfx.trackerDown => (440.0, 55, _Waveform.sine),
      AppSfx.assistantDone => (560.0, 120, _Waveform.triangle),
      AppSfx.focusStart => (520.0, 130, _Waveform.sine),
      AppSfx.focusEnd => (420.0, 150, _Waveform.triangle),
      AppSfx.pomodoroFlip => (600.0, 140, _Waveform.sine),
      AppSfx.error => (240.0, 85, _Waveform.sine),
      AppSfx.wDrop => (1040.0, 38, _Waveform.sine),
    };

    return _toneWav(
      sampleRate: sampleRate,
      durationMs: durationMs,
      freqHz: freqHz,
      waveform: waveform,
    );
  }

  static Uint8List _toneWav({
    required int sampleRate,
    required int durationMs,
    required double freqHz,
    required _Waveform waveform,
  }) {
    // Envelope: quick attack + short release to avoid harsh clicks.
    final totalSamples = (sampleRate * (durationMs / 1000)).round().clamp(1, 1 << 30);
    final pcm = Int16List(totalSamples);

    final attackSamples = max(1, (sampleRate * 0.006).round()); // ~6ms
    final releaseSamples = max(1, (sampleRate * 0.050).round()); // ~50ms
    final sustainStart = attackSamples;
    final releaseStart = max(sustainStart, totalSamples - releaseSamples);

    double sampleAt(int i) {
      final t = i / sampleRate;
      final x = 2 * pi * freqHz * t;
      return switch (waveform) {
        _Waveform.sine => sin(x),
        _Waveform.triangle => (2 / pi) * asin(sin(x)),
      };
    }

    double envAt(int i) {
      if (i < attackSamples) {
        return i / attackSamples;
      }
      if (i >= releaseStart) {
        final intoRelease = i - releaseStart;
        final denom = max(1, totalSamples - releaseStart);
        return (1.0 - (intoRelease / denom)).clamp(0.0, 1.0);
      }
      return 1.0;
    }

    // Slightly lower amplitude to avoid being intrusive.
    const amp = 0.20;
    for (var i = 0; i < totalSamples; i++) {
      final v = sampleAt(i) * envAt(i) * amp;
      pcm[i] = (v * 32767).round().clamp(-32768, 32767);
    }

    return _encodeWav16Mono(sampleRate: sampleRate, samples: pcm);
  }

  static Uint8List _encodeWav16Mono({
    required int sampleRate,
    required Int16List samples,
  }) {
    const numChannels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final blockAlign = numChannels * (bitsPerSample ~/ 8);

    final dataLen = samples.length * 2;
    final riffLen = 4 + (8 + 16) + (8 + dataLen);

    final bytes = BytesBuilder(copy: false);

    void u32(int v) {
      final b = ByteData(4)..setUint32(0, v, Endian.little);
      bytes.add(b.buffer.asUint8List());
    }

    void u16(int v) {
      final b = ByteData(2)..setUint16(0, v, Endian.little);
      bytes.add(b.buffer.asUint8List());
    }

    bytes.add(ascii.encode('RIFF'));
    u32(riffLen);
    bytes.add(ascii.encode('WAVE'));

    // fmt chunk
    bytes.add(ascii.encode('fmt '));
    u32(16); // PCM
    u16(1); // audio format = PCM
    u16(numChannels);
    u32(sampleRate);
    u32(byteRate);
    u16(blockAlign);
    u16(bitsPerSample);

    // data chunk
    bytes.add(ascii.encode('data'));
    u32(dataLen);

    final pcmBytes = samples.buffer.asUint8List();
    bytes.add(pcmBytes);

    return bytes.takeBytes();
  }
}

enum _Waveform { sine, triangle }

