import 'dart:math';

import '../../domain/focus/focus_session.dart';

/// Small helper to decide whether to play the "W drop" celebration when a
/// Dumb Phone (focus) session successfully completes.
///
/// - Only celebrates when the session ended because time elapsed.
/// - Only plays once per session id (even if the UI rebuilds).
/// - Uses a probability to keep it "special".
class WCelebrationDecider {
  WCelebrationDecider({
    required double chance,
    Random? random,
  })  : _chance = chance,
        _rng = random ?? Random();

  final double _chance;
  final Random _rng;

  String? _lastCelebratedSessionId;

  bool shouldCelebrateCompletedSession({
    required FocusSession session,
    required DateTime now,
  }) {
    // Only celebrate if the user made it to the planned end time.
    if (now.isBefore(session.plannedEndAt)) return false;

    // Only celebrate once per session id.
    if (_lastCelebratedSessionId == session.id) return false;
    _lastCelebratedSessionId = session.id;

    return _rng.nextDouble() < _chance;
  }
}

