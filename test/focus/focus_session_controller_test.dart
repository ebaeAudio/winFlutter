import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:win_flutter/data/focus/focus_policy_repository.dart';
import 'package:win_flutter/data/focus/focus_session_repository.dart';
import 'package:win_flutter/domain/focus/app_identifier.dart';
import 'package:win_flutter/domain/focus/focus_friction.dart';
import 'package:win_flutter/domain/focus/focus_policy.dart';
import 'package:win_flutter/domain/focus/focus_session.dart';
import 'package:win_flutter/features/focus/focus_policy_controller.dart';
import 'package:win_flutter/features/focus/focus_providers.dart';
import 'package:win_flutter/features/focus/focus_session_controller.dart';
import 'package:win_flutter/platform/restriction_engine/restriction_engine.dart';

void main() {
  test('startSession persists active and endSession moves it to history',
      () async {
    final policies = _MemPolicyRepo();
    final sessions = _MemSessionRepo();
    final engine = _FakeEngine();

    final policy = FocusPolicy(
      id: 'p1',
      name: 'Policy',
      allowedApps: const [
        AppIdentifier(platform: AppPlatform.android, id: 'a')
      ],
      friction: FocusFrictionSettings.defaults,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await policies.upsertPolicy(policy);

    final container = ProviderContainer(
      overrides: [
        focusPolicyRepositoryProvider.overrideWithValue(policies),
        focusSessionRepositoryProvider.overrideWithValue(sessions),
        restrictionEngineProvider.overrideWithValue(engine),
      ],
    );
    addTearDown(container.dispose);

    // Seed policy list.
    await container.read(focusPolicyListProvider.future);

    await container.read(activeFocusSessionProvider.notifier).startSession(
          policyId: 'p1',
          duration: const Duration(minutes: 1),
        );

    final active = container.read(activeFocusSessionProvider).valueOrNull;
    expect(active, isNotNull);
    expect(sessions.active, isNotNull);
    expect(engine.started, true);

    await container
        .read(activeFocusSessionProvider.notifier)
        .endSession(reason: FocusSessionEndReason.userEarlyExit);

    expect(container.read(activeFocusSessionProvider).valueOrNull, isNull);
    expect(sessions.active, isNull);
    expect(sessions.history, isNotEmpty);
    expect(engine.ended, true);
  });

  test('startSession respects explicit endsAt', () async {
    final policies = _MemPolicyRepo();
    final sessions = _MemSessionRepo();
    final engine = _FakeEngine();

    final policy = FocusPolicy(
      id: 'p1',
      name: 'Policy',
      allowedApps: const [
        AppIdentifier(platform: AppPlatform.android, id: 'a')
      ],
      friction: FocusFrictionSettings.defaults,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await policies.upsertPolicy(policy);

    final container = ProviderContainer(
      overrides: [
        focusPolicyRepositoryProvider.overrideWithValue(policies),
        focusSessionRepositoryProvider.overrideWithValue(sessions),
        restrictionEngineProvider.overrideWithValue(engine),
      ],
    );
    addTearDown(container.dispose);

    // Seed policy list.
    await container.read(focusPolicyListProvider.future);

    final now = DateTime.now();
    final endsAt = now.add(const Duration(minutes: 5));

    await container.read(activeFocusSessionProvider.notifier).startSession(
          policyId: 'p1',
          endsAt: endsAt,
        );

    final active = container.read(activeFocusSessionProvider).valueOrNull;
    expect(active, isNotNull);
    expect(active?.plannedEndAt, endsAt);
    expect(engine.started, true);
  });
}

class _MemPolicyRepo implements FocusPolicyRepository {
  final Map<String, FocusPolicy> _byId = {};

  @override
  Future<void> deletePolicy(String id) async {
    _byId.remove(id);
  }

  @override
  Future<FocusPolicy?> getPolicy(String id) async => _byId[id];

  @override
  Future<List<FocusPolicy>> listPolicies() async =>
      _byId.values.toList(growable: false);

  @override
  Future<void> upsertPolicy(FocusPolicy policy) async {
    _byId[policy.id] = policy;
  }
}

class _MemSessionRepo implements FocusSessionRepository {
  FocusSession? active;
  final List<FocusSession> history = [];

  @override
  Future<void> appendToHistory(FocusSession session) async {
    history.insert(0, session);
  }

  @override
  Future<void> clearActiveSession() async {
    active = null;
  }

  @override
  Future<void> clearHistory() async {
    history.clear();
  }

  @override
  Future<FocusSession?> getActiveSession() async => active;

  @override
  Future<List<FocusSession>> listHistory() async => List.of(history);

  @override
  Future<void> saveActiveSession(FocusSession session) async {
    active = session;
  }
}

class _FakeEngine implements RestrictionEngine {
  bool started = false;
  bool ended = false;

  @override
  Future<void> endSession() async {
    ended = true;
  }

  @override
  Future<void> setCardRequired({required bool required}) async {}

  @override
  Future<RestrictionPermissions> getPermissions() async {
    return const RestrictionPermissions(
      isSupported: true,
      isAuthorized: true,
      needsOnboarding: false,
      platformDetails: 'fake',
    );
  }

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> configureApps() async {}

  @override
  Future<void> startEmergencyException({required Duration duration}) async {}

  @override
  Future<void> startSession({
    required DateTime endsAt,
    required List<AppIdentifier> allowedApps,
    required FocusFrictionSettings friction,
  }) async {
    started = true;
  }
}
