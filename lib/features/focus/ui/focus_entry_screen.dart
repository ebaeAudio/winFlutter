import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/user_settings.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/spacing.dart';
import '../restriction_permissions_provider.dart';
import 'dumb_phone_onboarding_flow.dart';
import 'focus_dashboard_screen.dart';
import 'widgets/pomodoro_timer_card.dart';

class FocusEntryScreen extends ConsumerWidget {
  const FocusEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(restrictionPermissionsProvider);
    final userSettings = ref.watch(userSettingsControllerProvider);
    final onboardingComplete = userSettings.dumbPhoneOnboardingComplete;

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
                  padding: const EdgeInsets.all(AppSpace.s12),
                  child: Text(
                    'This device does not support app restrictions.\n\nUse the Pomodoro timer below as a lightweight replacement.\n\n${p.platformDetails}',
                  ),
                ),
              ),
              Gap.h12,
              const PomodoroTimerCard(),
            ],
          );
        }

        // Show the new guided onboarding flow if:
        // 1. User hasn't completed onboarding yet, OR
        // 2. Permissions need to be granted
        if (!onboardingComplete || p.needsOnboarding || !p.isAuthorized) {
          return DumbPhoneOnboardingFlow(initialPermissions: p);
        }

        return const FocusDashboardScreen();
      },
    );
  }
}
