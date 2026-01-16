import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../ui/responsive.dart';

/// Service for updating the macOS Dock badge.
///
/// On macOS, this sets the badge count on the app's Dock icon.
/// On other platforms, this is a no-op.
class DockBadgeService {
  DockBadgeService._();

  static final instance = DockBadgeService._();

  static const _channel = MethodChannel('com.wintheyear.app/dock_badge');

  /// Sets the Dock badge to [count].
  ///
  /// - If [count] is 0 or less, the badge is cleared.
  /// - On non-macOS platforms, this is a no-op.
  Future<void> setBadgeCount(int count) async {
    if (!isMacOS) return;

    try {
      await _channel.invokeMethod('setBadgeCount', {'count': count});
    } on PlatformException catch (e) {
      debugPrint('DockBadgeService: Failed to set badge: ${e.message}');
    } on MissingPluginException {
      // Method channel not registered on this platform - ignore.
      debugPrint('DockBadgeService: Method channel not available');
    }
  }

  /// Clears the Dock badge.
  Future<void> clearBadge() => setBadgeCount(0);
}
