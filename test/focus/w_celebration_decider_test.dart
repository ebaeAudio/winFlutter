import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:win_flutter/domain/focus/focus_session.dart';
import 'package:win_flutter/features/focus/w_celebration_decider.dart';

class _FixedRandom implements Random {
  _FixedRandom(this.value);
  final double value;

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => value >= 0.5;

  @override
  int nextInt(int max) => (value * max).floor().clamp(0, max - 1);
}

void main() {
  test('does not celebrate before planned end time', () {
    final decider = WCelebrationDecider(chance: 1.0, random: _FixedRandom(0.0));
    final now = DateTime(2026, 1, 1, 12, 0, 0);
    final session = FocusSession(
      id: 's1',
      policyId: 'p1',
      startedAt: now.subtract(const Duration(minutes: 10)),
      plannedEndAt: now.add(const Duration(minutes: 1)),
      status: FocusSessionStatus.active,
      emergencyUnlocksUsed: 0,
    );

    expect(
      decider.shouldCelebrateCompletedSession(session: session, now: now),
      isFalse,
    );
  });

  test('celebrates when time elapsed and RNG < chance (one-shot per session)', () {
    final decider = WCelebrationDecider(chance: 0.30, random: _FixedRandom(0.10));
    final now = DateTime(2026, 1, 1, 12, 0, 0);
    final session = FocusSession(
      id: 's1',
      policyId: 'p1',
      startedAt: now.subtract(const Duration(minutes: 26)),
      plannedEndAt: now.subtract(const Duration(seconds: 1)),
      status: FocusSessionStatus.active,
      emergencyUnlocksUsed: 0,
    );

    expect(
      decider.shouldCelebrateCompletedSession(session: session, now: now),
      isTrue,
    );

    // Same session id should never celebrate again.
    expect(
      decider.shouldCelebrateCompletedSession(session: session, now: now),
      isFalse,
    );
  });

  test('different sessions can celebrate independently', () {
    final decider = WCelebrationDecider(chance: 1.0, random: _FixedRandom(0.0));
    final now = DateTime(2026, 1, 1, 12, 0, 0);

    final s1 = FocusSession(
      id: 's1',
      policyId: 'p1',
      startedAt: now.subtract(const Duration(minutes: 26)),
      plannedEndAt: now.subtract(const Duration(seconds: 1)),
      status: FocusSessionStatus.active,
      emergencyUnlocksUsed: 0,
    );
    final s2 = FocusSession(
      id: 's2',
      policyId: 'p1',
      startedAt: now.subtract(const Duration(minutes: 26)),
      plannedEndAt: now.subtract(const Duration(seconds: 1)),
      status: FocusSessionStatus.active,
      emergencyUnlocksUsed: 0,
    );

    expect(decider.shouldCelebrateCompletedSession(session: s1, now: now), isTrue);
    expect(decider.shouldCelebrateCompletedSession(session: s2, now: now), isTrue);
  });
}

