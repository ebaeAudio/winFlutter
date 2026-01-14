import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win_flutter/app/theme.dart';
import 'package:win_flutter/data/focus/focus_session_repository.dart';
import 'package:win_flutter/domain/focus/app_identifier.dart';
import 'package:win_flutter/domain/focus/focus_friction.dart';
import 'package:win_flutter/domain/focus/focus_session.dart';
import 'package:win_flutter/features/focus/dumb_phone_session_gate_controller.dart';
import 'package:win_flutter/features/focus/focus_providers.dart';
import 'package:win_flutter/platform/restriction_engine/restriction_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DumbPhoneSessionGateController', () {
    late Map<String, String> secureStore;
    late _FakeEngine engine;

    setUp(() async {
      secureStore = <String, String>{};
      FlutterSecureStoragePlatform.instance =
          TestFlutterSecureStoragePlatform(secureStore);

      engine = _FakeEngine();
      SharedPreferences.setMockInitialValues({});
    });

    test('build defaults requireCardToEndEarly=false when no paired card exists',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          restrictionEngineProvider.overrideWithValue(engine),
          focusSessionRepositoryProvider.overrideWithValue(_MemSessionRepo()),
        ],
      );
      addTearDown(container.dispose);

      final state = await container
          .read(dumbPhoneSessionGateControllerProvider.future);

      expect(state.hasPairedCard, false);
      expect(state.requireCardToEndEarly, false);
      expect(state.requireCardToStart, false);
      expect(engine.lastCardRequired, false);
    });

    test('build defaults requireCardToEndEarly=false when a paired card exists',
        () async {
      secureStore['dumb_phone_paired_card_key_hash_v1'] = 'hash1';

      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          restrictionEngineProvider.overrideWithValue(engine),
          focusSessionRepositoryProvider.overrideWithValue(_MemSessionRepo()),
        ],
      );
      addTearDown(container.dispose);

      final state = await container
          .read(dumbPhoneSessionGateControllerProvider.future);

      expect(state.hasPairedCard, true);
      expect(state.pairedCardKeyHash, 'hash1');
      expect(state.requireCardToEndEarly, false);
      expect(state.requireCardToStart, false);
      expect(
        prefs.getBool('settings_dumb_phone_require_card_to_end_early_v1'),
        false,
      );
      expect(engine.lastCardRequired, false);
    });

    test(
        'build enforces safety: if paired card missing, requireCardToEndEarly cannot remain ON',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        'settings_dumb_phone_require_card_to_end_early_v1',
        true,
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          restrictionEngineProvider.overrideWithValue(engine),
          focusSessionRepositoryProvider.overrideWithValue(_MemSessionRepo()),
        ],
      );
      addTearDown(container.dispose);

      final state = await container
          .read(dumbPhoneSessionGateControllerProvider.future);

      expect(state.hasPairedCard, false);
      expect(state.requireCardToEndEarly, false);
      expect(
        prefs.getBool('settings_dumb_phone_require_card_to_end_early_v1'),
        false,
      );
      expect(engine.lastCardRequired, false);
    });

    test('migrates legacy cardRequired=true -> requireCardToEndEarly=true',
        () async {
      secureStore['dumb_phone_paired_card_key_hash_v1'] = 'hash1';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('settings_dumb_phone_card_required_v1', true);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          restrictionEngineProvider.overrideWithValue(engine),
          focusSessionRepositoryProvider.overrideWithValue(_MemSessionRepo()),
        ],
      );
      addTearDown(container.dispose);

      final state = await container
          .read(dumbPhoneSessionGateControllerProvider.future);

      expect(state.hasPairedCard, true);
      expect(state.requireCardToEndEarly, true);
      expect(state.requireCardToStart, false);
      expect(
        prefs.getBool('settings_dumb_phone_require_card_to_end_early_v1'),
        true,
      );
      expect(engine.lastCardRequired, true);
    });

    test('savePairedCardHash persists hash and does not auto-enable setting',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          restrictionEngineProvider.overrideWithValue(engine),
          focusSessionRepositoryProvider.overrideWithValue(_MemSessionRepo()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(dumbPhoneSessionGateControllerProvider.future);

      await container
          .read(dumbPhoneSessionGateControllerProvider.notifier)
          .savePairedCardHash('hash1');

      final next = container
          .read(dumbPhoneSessionGateControllerProvider)
          .valueOrNull;
      expect(next?.hasPairedCard, true);
      expect(next?.pairedCardKeyHash, 'hash1');
      expect(next?.requireCardToEndEarly, false);
      expect(next?.requireCardToStart, false);
      expect(secureStore['dumb_phone_paired_card_key_hash_v1'], 'hash1');
      expect(
        prefs.getBool('settings_dumb_phone_require_card_to_end_early_v1'),
        false,
      );
      expect(engine.lastCardRequired, false);
    });

    test('unpairCard removes hash and forces requireCardToEndEarly OFF',
        () async {
      secureStore['dumb_phone_paired_card_key_hash_v1'] = 'hash1';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        'settings_dumb_phone_require_card_to_end_early_v1',
        true,
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          restrictionEngineProvider.overrideWithValue(engine),
          focusSessionRepositoryProvider.overrideWithValue(_MemSessionRepo()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(dumbPhoneSessionGateControllerProvider.future);

      await container
          .read(dumbPhoneSessionGateControllerProvider.notifier)
          .unpairCard();

      final next = container
          .read(dumbPhoneSessionGateControllerProvider)
          .valueOrNull;
      expect(next?.hasPairedCard, false);
      expect(next?.pairedCardKeyHash, isNull);
      expect(next?.requireCardToEndEarly, false);
      expect(next?.requireCardToStart, false);
      expect(secureStore.containsKey('dumb_phone_paired_card_key_hash_v1'), false);
      expect(
        prefs.getBool('settings_dumb_phone_require_card_to_end_early_v1'),
        false,
      );
      expect(engine.lastCardRequired, false);
    });

    testWidgets(
        'setRequireCardToEndEarly(true) without a paired card shows snackbar and keeps it OFF',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          restrictionEngineProvider.overrideWithValue(engine),
          focusSessionRepositoryProvider.overrideWithValue(_MemSessionRepo()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: SizedBox.shrink()),
          ),
        ),
      );

      final ctx = tester.element(find.byType(Scaffold));
      await container
          .read(dumbPhoneSessionGateControllerProvider.notifier)
          .setRequireCardToEndEarly(ctx, true);
      // Avoid pumpAndSettle here; SnackBar duration timers can make it flaky.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Pair a card to enable this setting.'), findsOneWidget);
      expect(
        prefs.getBool('settings_dumb_phone_require_card_to_end_early_v1'),
        false,
      );
      expect(engine.lastCardRequired, false);
    });
  });
}

class _MemSessionRepo implements FocusSessionRepository {
  @override
  Future<void> appendToHistory(FocusSession session) async {}

  @override
  Future<void> clearActiveSession() async {}

  @override
  Future<void> clearHistory() async {}

  @override
  Future<FocusSession?> getActiveSession() async => null;

  @override
  Future<List<FocusSession>> listHistory() async => const [];

  @override
  Future<void> saveActiveSession(FocusSession session) async {}
}

class _FakeEngine implements RestrictionEngine {
  bool? lastCardRequired;

  @override
  Future<void> setCardRequired({required bool required}) async {
    lastCardRequired = required;
  }

  @override
  Future<void> configureApps() async {}

  @override
  Future<void> endSession() async {}

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
  Future<void> startEmergencyException({required Duration duration}) async {}

  @override
  Future<void> startSession({
    required DateTime endsAt,
    required List<AppIdentifier> allowedApps,
    required FocusFrictionSettings friction,
  }) async {}
}

