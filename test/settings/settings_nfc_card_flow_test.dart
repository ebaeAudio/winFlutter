import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win_flutter/app/env.dart';
import 'package:win_flutter/app/theme.dart';
import 'package:win_flutter/data/focus/focus_session_repository.dart';
import 'package:win_flutter/domain/focus/app_identifier.dart';
import 'package:win_flutter/domain/focus/focus_friction.dart';
import 'package:win_flutter/domain/focus/focus_session.dart';
import 'package:win_flutter/features/focus/focus_providers.dart';
import 'package:win_flutter/features/settings/settings_screen.dart';
import 'package:win_flutter/platform/nfc/nfc_scan_purpose.dart';
import 'package:win_flutter/platform/nfc/nfc_scan_service.dart';
import 'package:win_flutter/platform/restriction_engine/restriction_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings NFC card flow', () {
    late Map<String, String> secureStore;
    late _FakeEngine engine;
    late _FakeNfcScanService nfcScan;

    setUp(() async {
      secureStore = <String, String>{};
      FlutterSecureStoragePlatform.instance =
          TestFlutterSecureStoragePlatform(secureStore);

      engine = _FakeEngine();
      nfcScan = _FakeNfcScanService();

      SharedPreferences.setMockInitialValues({});
    });

    Future<void> pumpSettings(WidgetTester tester, SharedPreferences prefs) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            envProvider.overrideWithValue(
              Env(supabaseUrl: '', supabaseAnonKey: '', demoMode: true),
            ),
            sharedPreferencesProvider.overrideWithValue(prefs),
            restrictionEngineProvider.overrideWithValue(engine),
            focusSessionRepositoryProvider.overrideWithValue(_MemSessionRepo()),
            nfcScanServiceProvider.overrideWithValue(nfcScan),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
        'pairing a card saves hash; “Require NFC card to end early” stays OFF by default',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      nfcScan.enqueue(NfcScanPurpose.pair, 'hash1');

      await pumpSettings(tester, prefs);

      final pairTile = find.widgetWithText(ListTile, 'Pair NFC card');
      expect(pairTile, findsOneWidget);

      final scrollable = find.byType(Scrollable).first;
      await tester.dragUntilVisible(pairTile, scrollable, const Offset(0, -300));
      await tester.tap(pairTile);
      await tester.pumpAndSettle();

      expect(find.text('Card paired.'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'NFC card paired'), findsOneWidget);

      final requireEndEarly =
          prefs.getBool('settings_dumb_phone_require_card_to_end_early_v1');
      expect(requireEndEarly, false);
      expect(secureStore['dumb_phone_paired_card_key_hash_v1'], 'hash1');
    });

    testWidgets(
        'unpair when “Require NFC card to end early”=ON requires scanning the current card',
        (tester) async {
      secureStore['dumb_phone_paired_card_key_hash_v1'] = 'hash1';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        'settings_dumb_phone_require_card_to_end_early_v1',
        true,
      );

      // Wrong card.
      nfcScan.enqueue(NfcScanPurpose.validateUnpair, 'wrong');

      await pumpSettings(tester, prefs);

      final pairedTile = find.widgetWithText(ListTile, 'NFC card paired');
      final scrollable = find.byType(Scrollable).first;
      await tester.dragUntilVisible(pairedTile, scrollable, const Offset(0, -300));
      await tester.tap(pairedTile);
      await tester.pumpAndSettle();

      // Action sheet/dialog.
      await tester.tap(find.widgetWithText(OutlinedButton, 'Unpair'));
      await tester.pumpAndSettle();

      expect(find.text('That is not the paired card.'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'NFC card paired'), findsOneWidget);
      expect(secureStore['dumb_phone_paired_card_key_hash_v1'], 'hash1');
    });

    testWidgets(
        'unpair when “Require NFC card to end early”=OFF uses confirmation dialog (no scan)',
        (tester) async {
      secureStore['dumb_phone_paired_card_key_hash_v1'] = 'hash1';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        'settings_dumb_phone_require_card_to_end_early_v1',
        false,
      );

      await pumpSettings(tester, prefs);

      final pairedTile = find.widgetWithText(ListTile, 'NFC card paired');
      final scrollable = find.byType(Scrollable).first;
      await tester.dragUntilVisible(pairedTile, scrollable, const Offset(0, -300));
      await tester.tap(pairedTile);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Unpair'));
      await tester.pumpAndSettle();

      expect(find.text('Unpair card?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Unpair'));
      await tester.pumpAndSettle();

      expect(find.text('Card unpaired.'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Pair NFC card'), findsOneWidget);
      expect(secureStore.containsKey('dumb_phone_paired_card_key_hash_v1'), false);
    });

    testWidgets(
        'replace card when “Require NFC card to end early”=ON validates current card first',
        (tester) async {
      secureStore['dumb_phone_paired_card_key_hash_v1'] = 'hash1';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        'settings_dumb_phone_require_card_to_end_early_v1',
        true,
      );

      nfcScan
        ..enqueue(NfcScanPurpose.validateUnpair, 'hash1')
        ..enqueue(NfcScanPurpose.pair, 'hash2');

      await pumpSettings(tester, prefs);

      final pairedTile = find.widgetWithText(ListTile, 'NFC card paired');
      await tester.scrollUntilVisible(pairedTile, 200);
      await tester.tap(pairedTile);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
      await tester.pumpAndSettle();

      expect(find.text('Card replaced.'), findsOneWidget);
      expect(secureStore['dumb_phone_paired_card_key_hash_v1'], 'hash2');
      expect(
        prefs.getBool('settings_dumb_phone_require_card_to_end_early_v1'),
        true,
      );
    });
  });
}

class _FakeNfcScanService implements NfcScanServiceBase {
  final Map<NfcScanPurpose, List<String?>> _queues = {};
  final List<NfcScanPurpose> calls = [];

  void enqueue(NfcScanPurpose purpose, String? result) {
    (_queues[purpose] ??= <String?>[]).add(result);
  }

  @override
  Future<String?> scanKeyHash(
    BuildContext context, {
    required NfcScanPurpose purpose,
  }) async {
    calls.add(purpose);
    final q = _queues[purpose];
    if (q == null || q.isEmpty) return null;
    return q.removeAt(0);
  }
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

