import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider that listens for deep links from native code.
///
/// This handles the `wintheyear://` URL scheme used by the iOS shield
/// "Open Win The Year" button.
final deepLinkHandlerProvider = Provider<DeepLinkHandler>((ref) {
  return DeepLinkHandler(ref);
});

/// Provider that holds the pending route from a deep link.
///
/// The app router can watch this and navigate when it changes.
final pendingDeepLinkRouteProvider = StateProvider<String?>((ref) => null);

class DeepLinkHandler {
  DeepLinkHandler(this._ref) {
    _setupChannel();
  }

  final Ref _ref;
  static const _channel = MethodChannel('win_flutter/deep_link');

  void _setupChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final args = call.arguments as Map?;
        final route = args?['route'] as String?;
        if (route != null && route.isNotEmpty) {
          _ref.read(pendingDeepLinkRouteProvider.notifier).state = route;
        }
      }
    });
  }
}
