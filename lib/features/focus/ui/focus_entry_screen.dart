import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/app_scaffold.dart';
import '../restriction_permissions_provider.dart';
import 'focus_onboarding_screen.dart';
import 'focus_dashboard_screen.dart';

class FocusEntryScreen extends ConsumerWidget {
  const FocusEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(restrictionPermissionsProvider);

    return perms.when(
      loading: () => const AppScaffold(
        title: 'Dumb Phone Mode',
        children: [Center(child: CircularProgressIndicator())],
      ),
      error: (e, _) => AppScaffold(
        title: 'Dumb Phone Mode',
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Failed to load restriction permissions: $e'),
            ),
          ),
        ],
      ),
      data: (p) {
        if (!p.isSupported) {
          return AppScaffold(
            title: 'Dumb Phone Mode',
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'This device does not support app restrictions.\n\n${p.platformDetails}',
                  ),
                ),
              ),
            ],
          );
        }

        if (p.needsOnboarding || !p.isAuthorized) {
          return FocusOnboardingScreen(permissions: p);
        }

        return const FocusDashboardScreen();
      },
    );
  }
}


