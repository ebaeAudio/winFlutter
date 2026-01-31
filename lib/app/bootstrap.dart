import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'env.dart';
import 'supabase.dart';
import '../platform/notifications/notification_service.dart';
import '../platform/deep_link/deep_link_handler.dart';
import '../platform/push/push_notification_service.dart';
import '../features/focus/remote_focus_command_handler.dart';

/// App startup initialization (env loading happens before this in `main()`).
Future<void> bootstrap(ProviderContainer container) async {
  // Read env and initialize services eagerly so routing/auth has what it needs.
  final env = container.read(envProvider);
  await container.read(supabaseProvider.notifier).initIfConfigured(env);

  // Initialize local notifications early so "tapped notification -> deep link"
  // works even when the app is cold-started.
  final notificationService = container.read(notificationServiceProvider);
  await notificationService.init(
        onDeepLink: (route) {
          container.read(pendingNotificationRouteProvider.notifier).state = route;
        },
      );

  // Schedule daily 8:45 AM morning prompt (non-blocking).
  unawaited(notificationService.scheduleMorningPrompt());

  // Initialize deep link handler for wintheyear:// URL scheme (iOS shield).
  container.read(deepLinkHandlerProvider);

  // Initialize APNs bridge (iOS) so remote focus commands can wake the device.
  await container.read(pushNotificationServiceProvider).init();

  // Start listening for remote focus commands (iOS).
  container.read(remoteFocusCommandHandlerProvider);
}
