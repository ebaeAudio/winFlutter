import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/admin.dart';
import '../../app/auth.dart';
import '../../app/env.dart';
import '../../app/errors.dart';
import '../../app/supabase.dart';
import '../../app/theme.dart';
import '../../app/user_settings.dart';
import 'integrations/linear_integration_sheet.dart';
import '../../app/linear_integration_controller.dart';
import '../focus/dumb_phone_session_gate_controller.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/components/section_header.dart';
import '../../ui/spacing.dart';
import '../pitch/pitch_content.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static String _linearStatusText(LinearIntegrationState? linear) {
    if (linear == null || !linear.hasApiKey) {
      return 'Add API key to sync';
    }
    final lastError = (linear.lastSyncError ?? '').trim();
    if (lastError.isNotEmpty) {
      // Show abbreviated error status
      if (lastError.contains('401') || lastError.contains('Unauthorized')) {
        return 'Auth error — tap to fix';
      }
      if (lastError.contains('400') || lastError.contains('Bad Request')) {
        return 'Config error — tap to fix';
      }
      return 'Sync error — tap to fix';
    }
    // Key saved and no recent error
    if (linear.lastSyncAtMs != null) {
      return 'Connected';
    }
    return 'Key saved — tap to test';
  }

  Future<void> _openLinearSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const LinearIntegrationSheet(),
    );
  }

  Future<void> _confirmAndSignOut(
    BuildContext context, {
    required bool enabled,
    required SupabaseClient? client,
  }) async {
    if (!enabled || client == null) return;

    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll be signed out on this device."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (shouldSignOut != true) return;

    try {
      await client.auth.signOut();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out.')),
      );
      context.go('/auth');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider).valueOrNull;
    final env = ref.watch(envProvider);
    final themeSettings = ref.watch(themeControllerProvider);
    final userSettings = ref.watch(userSettingsControllerProvider);
    final linear = ref.watch(linearIntegrationControllerProvider).valueOrNull;
    final dumbPhoneGate = ref.watch(dumbPhoneSessionGateControllerProvider);
    final supabase = ref.watch(supabaseProvider);
    final client = supabase.client;
    final isAdminAsync = ref.watch(isAdminProvider);

    final gate = dumbPhoneGate.valueOrNull;
    final requireSelfieToEndEarly =
        !kIsWeb ? (gate?.requireSelfieToEndEarly == true) : false;
    final sessionActive = gate?.sessionActive == true;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppScaffold(
      title: 'Settings',
      children: [
        // -- Account Section --
        const SectionHeader(title: 'Account'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Email'),
          subtitle: Text(auth?.email ??
              (auth?.isDemo == true ? 'demo@local' : '—'),),
        ),
        if (auth?.isDemo != true && client != null) ...[
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Log out'),
            subtitle: const Text('Sign out on this device'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _confirmAndSignOut(
              context,
              enabled: auth?.isDemo != true,
              client: client,
            ),
          ),
        ],

        // -- Trackers Section --
        const SectionHeader(title: 'Trackers'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Custom trackers'),
          subtitle: const Text('Add quick tallies to Today'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/trackers'),
        ),

        // -- Projects & Notes Section --
        const SectionHeader(title: 'Projects & Notes'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder_outlined),
          title: const Text('Projects'),
          subtitle: const Text('Goal tracking and project management'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/projects'),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.sticky_note_2_outlined),
          title: const Text('Notes'),
          subtitle: const Text('Markdown notes and inbox'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/notes'),
        ),

        // -- Integrations Section --
        const SectionHeader(title: 'Integrations'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Linear'),
          subtitle: Text(
            _linearStatusText(linear),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openLinearSheet(context),
        ),

        // -- Dumb Phone Mode Section --
        const SectionHeader(title: 'Dumb Phone Mode'),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto-start 25‑minute timebox'),
          subtitle: const Text('Start timer when session begins'),
          value: userSettings.dumbPhoneAutoStart25mTimebox,
          onChanged: (v) => ref
              .read(userSettingsControllerProvider.notifier)
              .setDumbPhoneAutoStart25mTimebox(v),
        ),
        const Divider(),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Selfie check to end early'),
          subtitle: Text(
            kIsWeb
                ? 'Not supported on web'
                : sessionActive
                    ? 'Change after session ends'
                    : 'Opens camera with clown overlay',
          ),
          value: requireSelfieToEndEarly,
          onChanged: (kIsWeb || sessionActive || dumbPhoneGate.isLoading)
              ? null
              : (v) => ref
                  .read(dumbPhoneSessionGateControllerProvider.notifier)
                  .setRequireSelfieToEndEarly(context, v),
        ),

        // -- Appearance Section --
        const SectionHeader(title: 'Appearance'),
        Gap.h8,
        Text(
          'Mode',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        Gap.h8,
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.system, label: Text('System')),
            ButtonSegment(value: ThemeMode.light, label: Text('Light')),
            ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
          ],
          selected: {themeSettings.themeMode},
          onSelectionChanged: (set) => ref
              .read(themeControllerProvider.notifier)
              .setThemeMode(set.first),
        ),
        Gap.h16,
        Text(
          'Color',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        Gap.h8,
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            for (final mode in AppThemeMode.values)
              _ThemeSwatch(
                mode: mode,
                selected: themeSettings.palette == mode,
                onTap: () => ref
                    .read(themeControllerProvider.notifier)
                    .setPalette(mode),
              ),
          ],
        ),
        Gap.h16,
        const Divider(),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Full-width layout'),
          subtitle: const Text('Reduce horizontal padding'),
          value: userSettings.disableHorizontalScreenPadding,
          onChanged: (v) => ref
              .read(userSettingsControllerProvider.notifier)
              .setDisableHorizontalScreenPadding(v),
        ),
        const Divider(),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('One-hand mode'),
          subtitle: const Text('Shift content for easier reach'),
          value: userSettings.oneHandModeEnabled,
          onChanged: (v) => ref
              .read(userSettingsControllerProvider.notifier)
              .setOneHandModeEnabled(v),
        ),
        if (userSettings.oneHandModeEnabled) ...[
          Gap.h8,
          SegmentedButton<OneHandModeHand>(
            segments: const [
              ButtonSegment(value: OneHandModeHand.left, label: Text('Left hand')),
              ButtonSegment(value: OneHandModeHand.right, label: Text('Right hand')),
            ],
            selected: {userSettings.oneHandModeHand},
            onSelectionChanged: (set) => ref
                .read(userSettingsControllerProvider.notifier)
                .setOneHandModeHand(set.first),
          ),
        ],

        // -- Support Section --
        const SectionHeader(title: 'Support'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(pitchContent.navEntry.title),
          subtitle: Text(pitchContent.navEntry.subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/pitch'),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Send feedback'),
          subtitle: const Text('Report bugs or suggestions'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(
            '/settings/feedback?entryPoint=${Uri.encodeComponent('settings')}',
          ),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Feature request'),
          subtitle: const Text('Generate a PRD document'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/prd'),
        ),

        // -- Admin Section (conditional) --
        if (isAdminAsync.valueOrNull == true) ...[
          const SectionHeader(title: 'Admin'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Admin Dashboard'),
            subtitle: const Text('Manage admin features'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/admin'),
          ),
        ],

        // -- Demo Section (conditional) --
        if (env.demoMode) ...[
          const SectionHeader(title: 'Demo'),
          Text(
            'Demo controls will appear here.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        Gap.h24,
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final AppThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  String get _label => switch (mode) {
        AppThemeMode.slate => 'Slate',
        AppThemeMode.forest => 'Forest',
        AppThemeMode.sunset => 'Sunset',
        AppThemeMode.grape => 'Grape',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final seed = seedFor(mode);

    // 44px minimum height for accessibility
    return Semantics(
      button: true,
      selected: selected,
      label: 'Theme: $_label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusSmall),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s12,
            vertical: AppSpace.s8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadiusSmall),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: seed,
                ),
              ),
              Gap.w8,
              Text(
                _label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (selected) ...[
                Gap.w4,
                Icon(Icons.check, color: scheme.primary, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
