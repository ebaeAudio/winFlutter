import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';
import '../platform/notifications/notification_service.dart';
import '../platform/deep_link/deep_link_handler.dart';

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeSettings = ref.watch(themeControllerProvider);

    // Consume pending deep links from notification taps once the router exists.
    ref.listen<String?>(pendingNotificationRouteProvider, (prev, next) {
      if (next == null || next.trim().isEmpty) return;
      router.go(next);
      ref.read(pendingNotificationRouteProvider.notifier).state = null;
    });

    // Consume pending deep links from wintheyear:// URL scheme (iOS shield).
    ref.listen<String?>(pendingDeepLinkRouteProvider, (prev, next) {
      if (next == null || next.trim().isEmpty) return;
      router.go(next);
      ref.read(pendingDeepLinkRouteProvider.notifier).state = null;
    });

    return MaterialApp.router(
      title: 'Win the Year',
      theme: themeFor(themeSettings.palette, Brightness.light),
      darkTheme: themeFor(themeSettings.palette, Brightness.dark),
      themeMode: themeSettings.themeMode,
      routerConfig: router,
    );
  }
}
