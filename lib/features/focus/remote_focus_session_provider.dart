import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/focus/supabase_focus_session_sync.dart';
import 'focus_providers.dart';
import 'focus_session_controller.dart';

/// Polling intervals for remote session sync.
/// - Fast: When a session is active (need responsive updates)
/// - Slow: When no session is active (just checking if one started)
///
/// TODO(future): Replace polling with Supabase Realtime for instant updates
/// and zero polling cost. Realtime subscriptions push changes instead of
/// polling, which would:
/// - Eliminate all background API calls
/// - Provide instant sync (<100ms vs 3-15s)
/// - Better battery/network efficiency
/// See: https://supabase.com/docs/guides/realtime
const _pollIntervalFast = Duration(seconds: 3);
const _pollIntervalSlow = Duration(seconds: 15);

/// Provider that polls for remote focus sessions from other devices.
///
/// On macOS (and other desktop platforms), this allows showing a countdown
/// for a session that was started on iPhone.
///
/// The polling only runs when:
/// - User is signed in (Supabase sync is available)
/// - There's no local active session (we're not the device running the session)
/// - Platform is macOS, Windows, or Linux (desktop)
final remoteFocusSessionProvider =
    StreamProvider<RemoteFocusSession?>((ref) async* {
  // Only poll on desktop platforms.
  if (!_isDesktopPlatform) {
    yield null;
    return;
  }

  final sync = ref.watch(supabaseFocusSessionSyncProvider);
  if (sync == null) {
    yield null;
    return;
  }

  // Check if there's a local session running.
  // If so, we don't need to poll remote - we're the source device.
  final localSession = ref.watch(activeFocusSessionProvider).valueOrNull;
  if (localSession != null && localSession.isActive) {
    yield null;
    return;
  }

  // Initial fetch with error handling.
  RemoteFocusSession? lastKnown;
  try {
    lastKnown = await sync.getActiveSession();
    yield lastKnown;
  } catch (e) {
    debugPrint('[remoteFocusSessionProvider] Initial fetch error: $e');
    yield null;
  }

  // Adaptive polling: fast when session active, slow when idle.
  // This saves ~80% API calls when no session is running.
  final controller = StreamController<void>();
  Timer? timer;
  var currentInterval = lastKnown != null ? _pollIntervalFast : _pollIntervalSlow;

  void schedulePoll(Duration interval) {
    timer?.cancel();
    timer = Timer(interval, () {
      if (!controller.isClosed) {
        controller.add(null);
      }
    });
  }

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  // Start first poll.
  schedulePoll(currentInterval);

  await for (final _ in controller.stream) {
    // Re-check local session in case it started.
    final currentLocal = ref.read(activeFocusSessionProvider).valueOrNull;
    if (currentLocal != null && currentLocal.isActive) {
      if (lastKnown != null) {
        lastKnown = null;
        yield null;
      }
      // Slow poll - just checking for edge cases.
      schedulePoll(_pollIntervalSlow);
      continue;
    }

    try {
      final remote = await sync.getActiveSession();
      // Only yield if the session state actually changed to avoid unnecessary rebuilds.
      final changed = _sessionChanged(lastKnown, remote);
      if (changed) {
        lastKnown = remote;
        yield remote;
      }

      // Adaptive interval: fast if session active, slow if idle.
      final nextInterval =
          (remote != null && remote.isActive) ? _pollIntervalFast : _pollIntervalSlow;
      schedulePoll(nextInterval);
    } catch (e) {
      // Log but don't crash - continue polling.
      debugPrint('[remoteFocusSessionProvider] Poll error: $e');
      // On error, if we had a session, yield null to clear stale UI.
      if (lastKnown != null) {
        lastKnown = null;
        yield null;
      }
      // Use slow interval on errors to avoid hammering a failing endpoint.
      schedulePoll(_pollIntervalSlow);
    }
  }
});

/// Check if session state changed (for deduplication).
bool _sessionChanged(RemoteFocusSession? old, RemoteFocusSession? current) {
  if (old == null && current == null) return false;
  if (old == null || current == null) return true;
  // Check if key fields changed.
  return old.sessionId != current.sessionId ||
      old.plannedEndAt != current.plannedEndAt ||
      old.emergencyUnlocksUsed != current.emergencyUnlocksUsed;
}

/// Whether we're running on a desktop platform.
bool get _isDesktopPlatform {
  try {
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  } catch (_) {
    return false;
  }
}

/// Provider that combines local and remote sessions for display.
///
/// Returns the active session (local or remote) along with metadata
/// about where it came from.
final combinedFocusSessionProvider = Provider<CombinedFocusSession?>((ref) {
  // First check local session.
  final localAsync = ref.watch(activeFocusSessionProvider);
  final local = localAsync.valueOrNull;

  if (local != null && local.isActive) {
    return CombinedFocusSession(
      session: local,
      isRemote: false,
      sourcePlatform: _currentPlatform,
    );
  }

  // Check remote session.
  final remoteAsync = ref.watch(remoteFocusSessionProvider);
  final remote = remoteAsync.valueOrNull;

  if (remote != null && remote.isActive) {
    return CombinedFocusSession(
      session: remote.toFocusSession(),
      isRemote: true,
      sourcePlatform: remote.sourcePlatform,
      platformLabel: remote.platformLabel,
    );
  }

  return null;
});

/// A focus session with metadata about its source.
class CombinedFocusSession {
  const CombinedFocusSession({
    required this.session,
    required this.isRemote,
    required this.sourcePlatform,
    this.platformLabel,
  });

  /// The focus session data.
  final dynamic session; // FocusSession

  /// Whether this session came from another device.
  final bool isRemote;

  /// Raw platform identifier (e.g., "iOS", "macOS").
  final String sourcePlatform;

  /// User-friendly platform label (e.g., "iPhone", "Mac").
  final String? platformLabel;

  /// Get the planned end time.
  DateTime get plannedEndAt {
    final s = session;
    if (s is RemoteFocusSession) return s.plannedEndAt;
    // FocusSession
    return (s as dynamic).plannedEndAt as DateTime;
  }

  /// Get the start time.
  DateTime get startedAt {
    final s = session;
    if (s is RemoteFocusSession) return s.startedAt;
    return (s as dynamic).startedAt as DateTime;
  }

  /// Get remaining duration.
  Duration get remaining {
    final now = DateTime.now();
    final rem = plannedEndAt.difference(now);
    return rem.isNegative ? Duration.zero : rem;
  }

  /// Whether the session is still active.
  bool get isActive => DateTime.now().isBefore(plannedEndAt);

  /// Display label for the timer (e.g., "Focus Session" or "Focus • iPhone").
  String get displayLabel {
    if (isRemote && platformLabel != null) {
      return 'Focus • $platformLabel';
    }
    return 'Focus Session';
  }
}

String get _currentPlatform {
  try {
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isAndroid) return 'android';
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) return 'windows';
  } catch (_) {}
  return 'web';
}
