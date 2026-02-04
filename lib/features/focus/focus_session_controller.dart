import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/focus/focus_policy_repository.dart';
import '../../data/focus/focus_session_repository.dart';
import '../../domain/focus/focus_friction.dart';
import '../../domain/focus/focus_session.dart';
import '../../platform/notifications/notification_service.dart';
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

  /// Returns true if the session started successfully.
  ///
  /// This allows UI flows (like post-start navigation) to remain predictable:
  /// no navigation on failure or cancel.
  Future<bool> startSession({
    required String policyId,
    Duration? duration,
    DateTime? endsAt,
    FocusFrictionSettings? frictionOverride,
  }) async {
    final hasDuration = duration != null;
    final hasEndsAt = endsAt != null;
    if (hasDuration == hasEndsAt) {
      // Must provide exactly one.
      throw ArgumentError(
        'Provide exactly one of duration or endsAt.',
      );
    }

    final active = state.valueOrNull;
    if (active != null && active.isActive) return false;

    state = const AsyncLoading();
    try {
      final policy = await _policies.getPolicy(policyId);
      if (policy == null) {
        throw StateError('Policy not found');
      }

      final effectiveFriction = frictionOverride ?? policy.friction;
      final now = DateTime.now();
      final plannedEndAt = endsAt ?? now.add(duration!);
      if (!plannedEndAt.isAfter(now)) {
        throw StateError('End time must be in the future.');
      }
      final id = '${now.microsecondsSinceEpoch}_${Random().nextInt(1 << 20)}';
      final session = FocusSession(
        id: id,
        policyId: policy.id,
        startedAt: now,
        plannedEndAt: plannedEndAt,
        status: FocusSessionStatus.active,
        friction: effectiveFriction,
        emergencyUnlocksUsed: 0,
      );

      await _engine.startSession(
        endsAt: session.plannedEndAt,
        allowedApps: policy.allowedApps,
        friction: effectiveFriction,
      );

      await _sessions.saveActiveSession(session);
      state = AsyncData(session);

      // Schedule a local notification when the dumb phone session ends.
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.scheduleFocusSessionComplete(
        notificationId: notificationIdForFocusSession(session.id),
        endsAt: session.plannedEndAt,
        title: 'Dumb Phone session complete',
        body: 'Your focus session has ended. Open the app to continue.',
        route: '/focus',
      );

      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
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

    // Cancel the "session complete" notification if they ended early.
    // ignore: unawaited_futures
    await ref.read(notificationServiceProvider).cancel(
          notificationIdForFocusSession(active.id),
        );

    // Preserve the previous session while we perform the slow platform cleanup,
    // so the UI can show "Ending..." instead of blank-loading the whole card.
    state = const AsyncLoading<FocusSession?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await _engine.endSession();

      final ended = FocusSession(
        id: active.id,
        policyId: active.policyId,
        startedAt: active.startedAt,
        plannedEndAt: active.plannedEndAt,
        status: FocusSessionStatus.ended,
        friction: active.friction,
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
