import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lightweight ticker for "remaining time" UI.
final nowTickerProvider = StreamProvider<DateTime>((ref) {
  return Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  );
});


