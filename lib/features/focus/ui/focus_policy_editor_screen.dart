import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/focus/app_identifier.dart';
import '../../../domain/focus/focus_friction.dart';
import '../../../domain/focus/focus_policy.dart';
import '../../../ui/app_scaffold.dart';
import '../focus_policy_controller.dart';
import '../focus_providers.dart';

class FocusPolicyEditorScreen extends ConsumerStatefulWidget {
  const FocusPolicyEditorScreen({
    super.key,
    required this.policyId,
    this.closeOnSave = false,
  });

  final String policyId;
  final bool closeOnSave;

  @override
  ConsumerState<FocusPolicyEditorScreen> createState() =>
      _FocusPolicyEditorScreenState();
}

class _FocusPolicyEditorScreenState extends ConsumerState<FocusPolicyEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  FocusPolicy? _policy;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final engine = ref.read(restrictionEngineProvider);
    final policies = ref.watch(focusPolicyListProvider).valueOrNull ?? const [];
    _policy ??= policies.where((p) => p.id == widget.policyId).firstOrNull;
    final policy = _policy;

    if (policy == null) {
      return const AppScaffold(
        title: 'Edit Policy',
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('Policy not found.'),
            ),
          ),
        ],
      );
    }

    _name.text = _name.text.isEmpty ? policy.name : _name.text;

    return AppScaffold(
      title: 'Edit Policy',
      actions: [
        IconButton(
          tooltip: 'Save',
          onPressed: () async {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            final updated = policy.copyWith(
              name: _name.text.trim(),
              updatedAt: DateTime.now(),
            );
            final controller = ref.read(focusPolicyListProvider.notifier);
            await controller.upsert(updated);
            if (!context.mounted) return;

            final result = ref.read(focusPolicyListProvider);
            if (result.hasError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to save policy: ${result.error}')),
              );
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Policy saved')),
            );

            if (widget.closeOnSave) {
              context.go('/home/focus/policies');
            }
          },
          icon: const Icon(Icons.save),
        ),
      ],
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _AllowedAppsEditor(
                policy: policy,
                onChanged: (p) => setState(() => _policy = p),
              ),
              if (isIOS) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'iOS app blocking',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'On iOS, app blocking requires Apple’s Screen Time picker to select apps to block. '
                          'The “Allowed apps” list above is primarily used for Android.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: () async {
                            try {
                              await engine.configureApps();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Updated iOS blocked apps selection'),
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to open iOS app picker: $e'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.apps),
                          label: const Text('Choose apps to block (iOS)'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _FrictionEditor(
                friction: policy.friction,
                onChanged: (f) => setState(() => _policy = policy.copyWith(friction: f)),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    isIOS
                        ? 'iOS note: allowlisting is limited by Screen Time APIs. We may need to model a “blocked apps” selection in the iOS engine.'
                        : 'Android note: enforcement uses an AccessibilityService and cannot be 100% foolproof on all OEMs.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AllowedAppsEditor extends StatelessWidget {
  const _AllowedAppsEditor({required this.policy, required this.onChanged});

  final FocusPolicy policy;
  final ValueChanged<FocusPolicy> onChanged;

  @override
  Widget build(BuildContext context) {
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Allowed apps', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in policy.allowedApps)
                  InputChip(
                    label: Text(a.displayName ?? a.id),
                    onDeleted: () {
                      onChanged(
                        policy.copyWith(
                          allowedApps: policy.allowedApps
                              .where((x) => x.id != a.id || x.platform != a.platform)
                              .toList(growable: false),
                        ),
                      );
                    },
                  ),
                ActionChip(
                  label: const Text('Add app id…'),
                  avatar: const Icon(Icons.add),
                  onPressed: () async {
                    final added = await _promptAddApp(context);
                    if (added == null) return;
                    onChanged(
                      policy.copyWith(
                        allowedApps: [...policy.allowedApps, added],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isIOS
                  ? 'Enter an iOS bundle id (e.g. com.apple.Maps).'
                  : 'Enter an Android package name (e.g. com.google.android.youtube).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  static Future<AppIdentifier?> _promptAddApp(BuildContext context) async {
    final id = TextEditingController();
    final name = TextEditingController();
    final platform = (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
        ? AppPlatform.ios
        : AppPlatform.android;
    try {
      final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Add allowed app'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: id,
                    decoration: const InputDecoration(labelText: 'App id'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: name,
                    decoration:
                        const InputDecoration(labelText: 'Display name (optional)'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Add'),
                ),
              ],
            ),
          ) ??
          false;
      if (!ok) return null;
      final raw = id.text.trim();
      if (raw.isEmpty) return null;
      final dn = name.text.trim();
      return AppIdentifier(
        platform: platform,
        id: raw,
        displayName: dn.isEmpty ? null : dn,
      );
    } finally {
      id.dispose();
      name.dispose();
    }
  }
}

class _FrictionEditor extends StatefulWidget {
  const _FrictionEditor({required this.friction, required this.onChanged});

  final FocusFrictionSettings friction;
  final ValueChanged<FocusFrictionSettings> onChanged;

  @override
  State<_FrictionEditor> createState() => _FrictionEditorState();
}

class _FrictionEditorState extends State<_FrictionEditor> {
  late FocusFrictionSettings _f;

  @override
  void initState() {
    super.initState();
    _f = widget.friction;
  }

  @override
  void didUpdateWidget(covariant _FrictionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.friction != widget.friction) {
      _f = widget.friction;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Friction', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _NumberRow(
              label: 'Hold-to-unlock (sec)',
              value: _f.holdToUnlockSeconds,
              min: 1,
              max: 15,
              onChanged: (v) {
                setState(() => _f = _f.copyWith(holdToUnlockSeconds: v));
                widget.onChanged(_f);
              },
            ),
            _NumberRow(
              label: 'Unlock delay (sec)',
              value: _f.unlockDelaySeconds,
              min: 0,
              max: 120,
              onChanged: (v) {
                setState(() => _f = _f.copyWith(unlockDelaySeconds: v));
                widget.onChanged(_f);
              },
            ),
            _NumberRow(
              label: 'Emergency unlock (min)',
              value: _f.emergencyUnlockMinutes,
              min: 1,
              max: 30,
              onChanged: (v) {
                setState(() => _f = _f.copyWith(emergencyUnlockMinutes: v));
                widget.onChanged(_f);
              },
            ),
            _NumberRow(
              label: 'Max emergency unlocks/session',
              value: _f.maxEmergencyUnlocksPerSession,
              min: 0,
              max: 10,
              onChanged: (v) {
                setState(() => _f = _f.copyWith(maxEmergencyUnlocksPerSession: v));
                widget.onChanged(_f);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: value <= min ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(width: 36, child: Center(child: Text('$value'))),
        IconButton(
          onPressed: value >= max ? null : () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}


