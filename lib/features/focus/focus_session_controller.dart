import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/focus/focus_policy_repository.dart';
import '../../data/focus/focus_session_repository.dart';
import '../../domain/focus/focus_session.dart';
import '../../platform/restriction_engine/restriction_engine.dart';
import 'focus_providers.dart';

final activeFocusSessionProvider =
    AsyncNotifierProvider<ActiveFocusSessionController, FocusSession?>(
  ActiveFocusSessionController.new,
);

final focusSessionHistoryProvider =
    AsyncNotifierProvider<FocusSessionHistoryController, List<FocusSession>>(
  FocusSessionHistoryController.new,
);

class ActiveFocusSessionController extends AsyncNotifier<FocusSession?> {
  FocusSessionRepository get _sessions =>
      ref.read(focusSessionRepositoryProvider);
  FocusPolicyRepository get _policies =>
      ref.read(focusPolicyRepositoryProvider);
  RestrictionEngine get _engine => ref.read(restrictionEngineProvider);

  @override
  Future<FocusSession?> build() async {
    final active = await _sessions.getActiveSession();
    return active;
  }

  Future<void> reconcileIfExpired() async {
    final active = state.valueOrNull;
    if (active == null || !active.isActive) return;
    if (DateTime.now().isBefore(active.plannedEndAt)) return;
    await endSession(reason: FocusSessionEndReason.completed);
  }

  Future<void> startSession({
    required String policyId,
    required Duration duration,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final policy = await _policies.getPolicy(policyId);
      if (policy == null) {
        throw StateError('Policy not found');
      }

      final now = DateTime.now();
      final id = '${now.microsecondsSinceEpoch}_${Random().nextInt(1 << 20)}';
      final session = FocusSession(
        id: id,
        policyId: policy.id,
        startedAt: now,
        plannedEndAt: now.add(duration),
        status: FocusSessionStatus.active,
        emergencyUnlocksUsed: 0,
      );

      await _engine.startSession(
        endsAt: session.plannedEndAt,
        allowedApps: policy.allowedApps,
        friction: policy.friction,
      );

      await _sessions.saveActiveSession(session);
      return session;
    });
  }

  Future<void> endSession({required FocusSessionEndReason reason}) async {
    final active = state.valueOrNull;
    if (active == null) {
      // Best-effort: still clear platform restrictions.
      await _engine.endSession();
      await _sessions.clearActiveSession();
      state = const AsyncData(null);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _engine.endSession();

      final ended = FocusSession(
        id: active.id,
        policyId: active.policyId,
        startedAt: active.startedAt,
        plannedEndAt: active.plannedEndAt,
        status: FocusSessionStatus.ended,
        endedAt: DateTime.now(),
        endReason: reason,
        emergencyUnlocksUsed: active.emergencyUnlocksUsed,
      );
      await _sessions.clearActiveSession();
      await _sessions.appendToHistory(ended);

      // Refresh history controller opportunistically.
      ref.invalidate(focusSessionHistoryProvider);
      return null;
    });
  }

  Future<void> emergencyException({
    required Duration duration,
    required int maxPerSession,
  }) async {
    final active = state.valueOrNull;
    if (active == null || !active.isActive) return;
    if (active.emergencyUnlocksUsed >= maxPerSession) {
      throw StateError('No emergency exceptions remaining for this session');
    }

    await _engine.startEmergencyException(duration: duration);
    final updated = FocusSession(
      id: active.id,
      policyId: active.policyId,
      startedAt: active.startedAt,
      plannedEndAt: active.plannedEndAt,
      status: active.status,
      endedAt: active.endedAt,
      endReason: active.endReason,
      emergencyUnlocksUsed: active.emergencyUnlocksUsed + 1,
    );
    await _sessions.saveActiveSession(updated);
    state = AsyncData(updated);
  }
}

class FocusSessionHistoryController extends AsyncNotifier<List<FocusSession>> {
  FocusSessionRepository get _repo => ref.read(focusSessionRepositoryProvider);

  @override
  Future<List<FocusSession>> build() async {
    return _repo.listHistory();
  }

  Future<void> clear() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.clearHistory();
      return const <FocusSession>[];
    });
  }
}
