import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/restriction_engine/restriction_engine.dart';
import '../../../ui/app_scaffold.dart';
import '../focus_providers.dart';
import '../restriction_permissions_provider.dart';

class FocusOnboardingScreen extends ConsumerWidget {
  const FocusOnboardingScreen({super.key, required this.permissions});

  final RestrictionPermissions permissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.read(restrictionEngineProvider);
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return AppScaffold(
      title: 'Enable Dumb Phone Mode',
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              isIOS
                  ? 'On iOS, we request Screen Time authorization so we can support app blocking during a Focus Session. (Note: enforcement may be limited or unavailable in this build.)'
                  : 'On Android, we use an Accessibility Service to detect the foreground app and block non‑allowed apps.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text('Supported: ${permissions.isSupported}'),
                Text('Authorized: ${permissions.isAuthorized}'),
                Text('Needs onboarding: ${permissions.needsOnboarding}'),
                if (permissions.platformDetails.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    permissions.platformDetails,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            await engine.requestPermissions();
            if (!context.mounted) return;
            ref.invalidate(restrictionPermissionsProvider);
          },
          icon: const Icon(Icons.lock_open),
          label: const Text('Grant required permissions'),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              isIOS
                  ? 'You may be prompted to authorize Screen Time access. If you deny it, Dumb Phone Mode cannot use Screen Time-based restrictions.'
                  : 'You’ll be taken to Accessibility settings. Turn on “Win the Year Focus Service”.',
            ),
          ),
        ),
      ],
    );
  }
}


