enum NfcScanPurpose {
  pair,
  validateStart,
  validateEnd,
  validateUnpair,
}

String nfcStartAlertMessage(NfcScanPurpose p) {
  return switch (p) {
    NfcScanPurpose.pair =>
      'Ready to scan. Hold your NFC card/tag near the top of your phone.',
    NfcScanPurpose.validateStart =>
      'Ready to scan. Hold your paired NFC card/tag near the top of your phone.',
    NfcScanPurpose.validateEnd =>
      'Ready to scan. Hold your paired NFC card/tag near the top of your phone.',
    NfcScanPurpose.validateUnpair =>
      'Ready to scan. Hold your paired NFC card/tag near the top of your phone.',
  };
}

String nfcSuccessAlertMessage(NfcScanPurpose p) {
  return switch (p) {
    NfcScanPurpose.pair => 'Card paired.',
    NfcScanPurpose.validateStart => 'Card verified.',
    NfcScanPurpose.validateEnd => 'Card verified.',
    NfcScanPurpose.validateUnpair => 'Card verified.',
  };
}

