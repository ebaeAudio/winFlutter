import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/auth.dart';
import '../../app/env.dart';
import '../../app/errors.dart';
import '../../app/supabase.dart';
import '../../app/theme.dart';
import '../../app/user_settings.dart';
import 'integrations/linear_integration_sheet.dart';
import '../../app/linear_integration_controller.dart';
import '../focus/dumb_phone_session_gate_controller.dart';
import '../../platform/nfc/nfc_card_service.dart';
import '../../platform/nfc/nfc_scan_purpose.dart';
import '../../platform/nfc/nfc_scan_service.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/components/section_header.dart';
import '../../ui/spacing.dart';
import '../pitch/pitch_content.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
        content: const Text('You’ll be signed out on this device.'),
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

    final gate = dumbPhoneGate.valueOrNull;
    final hasPairedCard = gate?.hasPairedCard == true;
    final requireCardToEndEarly =
        hasPairedCard ? (gate?.requireCardToEndEarly == true) : false;
    final requireSelfieToEndEarly =
        !kIsWeb ? (gate?.requireSelfieToEndEarly == true) : false;
    final sessionActive = gate?.sessionActive == true;

    return AppScaffold(
      title: 'Settings',
      children: [
        const SectionHeader(title: 'Account'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s8),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Email'),
                  subtitle: Text(auth?.email ??
                      (auth?.isDemo == true ? 'demo@local' : '—')),
                ),
                if (auth?.isDemo != true && client != null)
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Log out'),
                    subtitle: const Text('Sign out on this device'),
                    onTap: () => _confirmAndSignOut(
                      context,
                      enabled: auth?.isDemo != true,
                      client: client,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Gap.h16,
        const SectionHeader(title: 'Trackers'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.emoji_objects_outlined),
                  title: const Text('Custom trackers'),
                  subtitle: const Text('Add quick tallies to Today'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/settings/trackers'),
                ),
              ],
            ),
          ),
        ),
        Gap.h16,
        const SectionHeader(title: 'Integrations'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Linear'),
                  subtitle: Text(
                    linear?.hasApiKey == true
                        ? 'Connected (API key saved)'
                        : 'Add a personal API key to enable sync',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openLinearSheet(context),
                ),
              ],
            ),
          ),
        ),
        Gap.h16,
        const SectionHeader(title: 'Dumb Phone Mode'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Auto-start 25‑minute timebox'),
                  subtitle: const Text(
                    'When a Dumb Phone session starts successfully, jump to Today and start a 25‑minute timer.',
                  ),
                  value: userSettings.dumbPhoneAutoStart25mTimebox,
                  onChanged: (v) => ref
                      .read(userSettingsControllerProvider.notifier)
                      .setDumbPhoneAutoStart25mTimebox(v),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: const Text('Require NFC card to end early'),
                  subtitle: Text(
                    !hasPairedCard
                        ? 'Pair a card to enable.'
                        : sessionActive
                            ? 'You can change this after the current session ends.'
                            : 'When enabled, ending early requires scanning your paired card.',
                  ),
                  value: requireCardToEndEarly,
                  onChanged: (!hasPairedCard ||
                          sessionActive ||
                          dumbPhoneGate.isLoading)
                      ? null
                      : (v) => ref
                          .read(dumbPhoneSessionGateControllerProvider.notifier)
                          .setRequireCardToEndEarly(context, v),
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  title: const Text('Require clown camera check to end early'),
                  subtitle: Text(
                    kIsWeb
                        ? 'Not supported on web.'
                        : sessionActive
                            ? 'You can change this after the current session ends.'
                            : 'When enabled, ending early opens your selfie camera with a clown overlay. No photo is taken.',
                  ),
                  value: requireSelfieToEndEarly,
                  onChanged: (kIsWeb || sessionActive || dumbPhoneGate.isLoading)
                      ? null
                      : (v) => ref
                          .read(dumbPhoneSessionGateControllerProvider.notifier)
                          .setRequireSelfieToEndEarly(context, v),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.nfc),
                  title:
                      Text(hasPairedCard ? 'NFC card paired' : 'Pair NFC card'),
                  subtitle: Text(
                    hasPairedCard
                        ? 'You can replace or unpair your card.'
                        : 'Pair a card to enable “Require NFC card to end early”.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: dumbPhoneGate.isLoading
                      ? null
                      : () async {
                          if (!hasPairedCard) {
                            final scan = await ref
                                .read(nfcScanServiceProvider)
                                .scanKeyHash(context,
                                    purpose: NfcScanPurpose.pair);
                            if (scan == null) return;

                            await ref
                                .read(dumbPhoneSessionGateControllerProvider
                                    .notifier)
                                .savePairedCardHash(scan);

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Card paired.')),
                            );
                            return;
                          }

                          final action = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('NFC card'),
                              content: const Text(
                                'You can replace your paired card or unpair it.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('Cancel'),
                                ),
                                OutlinedButton(
                                  onPressed: () =>
                                      Navigator.of(ctx).pop('unpair'),
                                  child: const Text('Unpair'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(ctx).pop('replace'),
                                  child: const Text('Replace'),
                                ),
                              ],
                            ),
                          );
                          if (action == null) return;

                          final current = ref
                              .read(dumbPhoneSessionGateControllerProvider)
                              .valueOrNull;
                          final pairedHash = current?.pairedCardKeyHash;
                          if (pairedHash == null || pairedHash.isEmpty) return;

                          final nfc = ref.read(nfcCardServiceProvider);

                          Future<bool> verifyCurrentCard() async {
                            final scan = await ref
                                .read(nfcScanServiceProvider)
                                .scanKeyHash(context,
                                    purpose: NfcScanPurpose.validateUnpair);
                            if (scan == null) return false;
                            final ok = nfc.constantTimeEquals(
                              scan,
                              pairedHash,
                            );
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('That is not the paired card.'),
                                ),
                              );
                            }
                            return ok;
                          }

                          if (action == 'unpair') {
                            if (current?.requireCardToEndEarly == true) {
                              final ok = await verifyCurrentCard();
                              if (!ok) return;
                            } else {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Unpair card?'),
                                  content: const Text(
                                    'This will remove the paired card from this device.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(true),
                                      child: const Text('Unpair'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok != true) return;
                            }

                            await ref
                                .read(dumbPhoneSessionGateControllerProvider
                                    .notifier)
                                .unpairCard();

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Card unpaired.')),
                            );
                            return;
                          }

                          if (action == 'replace') {
                            if (current?.requireCardToEndEarly == true) {
                              final ok = await verifyCurrentCard();
                              if (!ok) return;
                            }
                            final next = await ref
                                .read(nfcScanServiceProvider)
                                .scanKeyHash(context,
                                    purpose: NfcScanPurpose.pair);
                            if (next == null) return;

                            await ref
                                .read(dumbPhoneSessionGateControllerProvider
                                    .notifier)
                                .savePairedCardHash(next);

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Card replaced.')),
                            );
                            return;
                          }
                        },
                ),
              ],
            ),
          ),
        ),
        Gap.h16,
        const SectionHeader(title: 'Sound'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Enable sounds'),
                  subtitle: const Text(
                    'Temporarily disabled while we stabilize playback.',
                  ),
                  value: userSettings.soundsEnabled,
                  onChanged: null,
                ),
              ],
            ),
          ),
        ),
        Gap.h16,
        const SectionHeader(title: 'Appearance'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Gap.h12,
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode),
                    ),
                  ],
                  selected: {themeSettings.themeMode},
                  onSelectionChanged: (set) => ref
                      .read(themeControllerProvider.notifier)
                      .setThemeMode(set.first),
                ),
                Gap.h16,
                Text(
                  'Theme',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Gap.h12,
                Wrap(
                  spacing: AppSpace.s12,
                  runSpacing: AppSpace.s12,
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
                Text(
                  'Layout',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Gap.h8,
                Text(
                  'Use more of the screen by reducing the default horizontal padding.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                Gap.h12,
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Full-width layout'),
                  value: userSettings.disableHorizontalScreenPadding,
                  onChanged: (v) => ref
                      .read(userSettingsControllerProvider.notifier)
                      .setDisableHorizontalScreenPadding(v),
                ),
                Gap.h16,
                Text(
                  'One-hand mode',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Gap.h8,
                Text(
                  'Adds a thick “gutter” on the opposite side so controls are easier to reach.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                Gap.h12,
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable one-hand mode'),
                  value: userSettings.oneHandModeEnabled,
                  onChanged: (v) => ref
                      .read(userSettingsControllerProvider.notifier)
                      .setOneHandModeEnabled(v),
                ),
                Gap.h8,
                Text(
                  'Hand',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Gap.h8,
                SegmentedButton<OneHandModeHand>(
                  segments: const [
                    ButtonSegment(
                      value: OneHandModeHand.left,
                      label: Text('Left'),
                      icon: Icon(Icons.swipe_left),
                    ),
                    ButtonSegment(
                      value: OneHandModeHand.right,
                      label: Text('Right'),
                      icon: Icon(Icons.swipe_right),
                    ),
                  ],
                  selected: {userSettings.oneHandModeHand},
                  onSelectionChanged: userSettings.oneHandModeEnabled
                      ? (set) => ref
                          .read(userSettingsControllerProvider.notifier)
                          .setOneHandModeHand(set.first)
                      : null,
                ),
              ],
            ),
          ),
        ),
        Gap.h16,
        const SectionHeader(title: 'Support'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(pitchContent.navEntry.title),
                  subtitle: Text(pitchContent.navEntry.subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/settings/pitch'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.feedback_outlined),
                  title: const Text('Send feedback'),
                  subtitle:
                      const Text('Report a bug or suggest an improvement'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(
                    '/settings/feedback?entryPoint=${Uri.encodeComponent('settings')}',
                  ),
                ),
              ],
            ),
          ),
        ),
        if (env.demoMode) ...[
          Gap.h16,
          const SectionHeader(title: 'Demo'),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpace.s16),
              child: Text(
                'Demo controls will live here (ex: “Reset demo data”).',
              ),
            ),
          ),
        ],
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
    final seed = seedFor(mode);
    final fg = theme.colorScheme.onSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Theme: $_label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(AppSpace.s12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withOpacity(0.6),
              width: selected ? 2 : 1,
            ),
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.15),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: seed,
                ),
              ),
              Gap.w12,
              Expanded(
                child: Text(
                  _label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check, color: theme.colorScheme.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
