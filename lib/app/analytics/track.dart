import 'package:flutter/foundation.dart';

/// Minimal analytics hook.
///
/// This is intentionally tiny: today it logs, later it can be swapped to an
/// analytics SDK without changing call sites.
void track(String event, [Map<String, Object?> props = const {}]) {
  // Avoid noisy logs in release builds unless an analytics provider is wired.
  if (kReleaseMode) return;
  debugPrint('[track] $event ${props.isEmpty ? '' : props}');
}

