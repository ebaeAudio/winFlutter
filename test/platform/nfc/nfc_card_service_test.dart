import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:win_flutter/platform/nfc/nfc_card_service.dart';

void main() {
  group('NfcCardService', () {
    test('normalizeKey rejects short values and trims whitespace', () {
      const svc = NfcCardService();

      expect(svc.normalizeKey(''), isNull);
      expect(svc.normalizeKey('   '), isNull);

      // 15 bytes -> reject.
      expect(svc.normalizeKey('123456789012345'), isNull);

      // 16 bytes -> accept (trimmed).
      expect(svc.normalizeKey('  1234567890123456  '), '1234567890123456');
    });

    test('extractKeyStringFromMessage returns first non-empty record value', () {
      const svc = NfcCardService();

      final msg = NdefMessage([
        NdefRecord.createText('   '),
        NdefRecord.createUri(Uri.parse('https://example.com/paired-key')),
        NdefRecord.createText('this-should-not-be-used'),
      ]);

      expect(svc.extractKeyStringFromMessage(msg), 'https://example.com/paired-key');
    });

    test('sha256HexOfUtf8 is stable', () {
      const svc = NfcCardService();
      expect(
        svc.sha256HexOfUtf8('1234567890123456'),
        '7a51d064a1a216a692f753fcdab276e4ff201a01d8b66f56d50d4d719fd0dc87',
      );
    });

    test('constantTimeEquals compares exact strings', () {
      const svc = NfcCardService();
      expect(svc.constantTimeEquals('a', 'a'), true);
      expect(svc.constantTimeEquals('a', 'b'), false);
      expect(svc.constantTimeEquals('a', 'aa'), false);
    });
  });
}

