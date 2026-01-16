import 'package:flutter/foundation.dart';

import 'nfc_scan_purpose.dart';

/// Human-friendly, in-app guidance for getting NFC scans to work.
///
/// Keep this in the platform layer so both UI (Android sheet) and error dialogs
/// (iOS system prompt path) can reuse the same copy.
String nfcHowToScanChecklist(NfcScanPurpose purpose) {
  final what = switch (purpose) {
    NfcScanPurpose.pair => 'pair a card',
    NfcScanPurpose.validateStart => 'start Dumb Phone Mode',
    NfcScanPurpose.validateEnd => 'end Dumb Phone Mode',
    NfcScanPurpose.validateUnpair => 'confirm unpair',
  };

  return [
    'Do this:',
    '- Keep the phone unlocked and the screen on.',
    '- Hold the card/tag against the top-back of the phone.',
    '- Keep it still for 1–2 seconds (don’t “tap and lift”).',
    '- If nothing happens, slide slowly around the top edge to find the antenna.',
    '',
    'You’re scanning to $what.',
  ].join('\n');
}

String nfcTroubleshootingChecklist({
  required NfcScanPurpose purpose,
  required TargetPlatform platform,
}) {
  final base = <String>[
    'If it won’t scan:',
    '- Remove wallet cases / MagSafe accessories (they often block NFC).',
    '- Try a different NFC tag/card (some tags expose no readable ID to apps).',
    '- Try again with the card held still for longer (2–3 seconds).',
    '- Keep the phone unlocked; NFC reads often fail when the screen is off.',
  ];

  final platformSpecific = switch (platform) {
    TargetPlatform.android => <String>[
        '- Android: turn NFC ON in system settings (Quick Settings tile or Settings → Connected devices).',
        '- Android: if “NFC is not available”, your device may not support NFC.',
      ],
    TargetPlatform.iOS => <String>[
        '- iOS: NFC scanning does not work on the simulator — use a real iPhone.',
        '- iOS: NFC is available only on compatible iPhones (and can be restricted by MDM/parental controls).',
        '- iOS dev build: ensure the Runner target includes the “NFC Tag Reading” capability.',
      ],
    _ => const <String>[],
  };

  final privacy = <String>[
    '',
    'Privacy note:',
    '- We store only a hash derived from the tag (not the raw tag contents).',
  ];

  return [...base, ...platformSpecific, ...privacy].join('\n');
}

