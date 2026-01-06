import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/auth.dart';
import '../../app/env.dart';
import '../../app/theme.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/components/section_header.dart';
import '../../ui/spacing.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider).valueOrNull;
    final env = ref.watch(envProvider);
    final themeSettings = ref.watch(themeControllerProvider);

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
                  onTap: () => context.go('/home/settings/trackers'),
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
