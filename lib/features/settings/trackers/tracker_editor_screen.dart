import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/trackers/tracker_models.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/components/reachability_fab_cluster.dart';
import '../../../ui/nav_shell.dart';
import '../../../ui/components/section_header.dart';
import '../../../ui/spacing.dart';
import '../../../utils/iterable_extensions.dart';
import 'trackers_controller.dart';

class TrackerEditorScreen extends ConsumerStatefulWidget {
  const TrackerEditorScreen({
    super.key,
    required this.trackerId,
  });

  final String? trackerId;

  @override
  ConsumerState<TrackerEditorScreen> createState() =>
      _TrackerEditorScreenState();
}

class _TrackerEditorScreenState extends ConsumerState<TrackerEditorScreen> {
  final _nameController = TextEditingController();
  final List<TextEditingController> _emojiControllers = [];
  final List<TextEditingController> _descControllers = [];
  final List<TextEditingController> _targetControllers = [];
  final List<bool> _targetEnabled = [];
  final List<TargetCadence?> _targetCadence = [];

  String? _loadedForId;
  final List<String> _itemKeys = [];

  bool get _isNew => (widget.trackerId ?? '').trim().isEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _emojiControllers) {
      c.dispose();
    }
    for (final c in _descControllers) {
      c.dispose();
    }
    for (final c in _targetControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _resetItemControllers() {
    for (final c in _emojiControllers) {
      c.dispose();
    }
    for (final c in _descControllers) {
      c.dispose();
    }
    for (final c in _targetControllers) {
      c.dispose();
    }
    _emojiControllers.clear();
    _descControllers.clear();
    _targetControllers.clear();
    _targetEnabled.clear();
    _targetCadence.clear();
    _itemKeys.clear();
  }

  void _addEmptyItem({required String key}) {
    _itemKeys.add(key);
    _emojiControllers.add(TextEditingController());
    _descControllers.add(TextEditingController());
    _targetControllers.add(TextEditingController());
    _targetEnabled.add(false);
    _targetCadence.add(TargetCadence.daily);
  }

  void _removeItemAt(int index) {
    _emojiControllers[index].dispose();
    _descControllers[index].dispose();
    _targetControllers[index].dispose();
    _emojiControllers.removeAt(index);
    _descControllers.removeAt(index);
    _targetControllers.removeAt(index);
    _targetEnabled.removeAt(index);
    _targetCadence.removeAt(index);
    _itemKeys.removeAt(index);
  }

  String _nextKey() {
    for (final k in const ['a', 'b', 'c']) {
      if (!_itemKeys.contains(k)) return k;
    }
    // Should never happen (max 3 items), but keep deterministic.
    return 'x';
  }

  @override
  Widget build(BuildContext context) {
    final trackersAsync = ref.watch(trackersListProvider);
    final trackerId = widget.trackerId?.trim();

    Tracker? tracker;
    if (!_isNew) {
      tracker = trackersAsync.valueOrNull
          ?.where((t) => t.id == trackerId)
          .cast<Tracker?>()
          .firstOrNull;
    }

    if (!_isNew && tracker == null && trackersAsync.isLoading) {
      return const AppScaffold(title: 'Tracker', children: [
        Center(child: CircularProgressIndicator()),
      ]);
    }

    if (!_isNew && tracker == null) {
      return const AppScaffold(
        title: 'Tracker',
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpace.s12),
              child: Text('Tracker not found.'),
            ),
          ),
        ],
      );
    }

    // Seed controllers once when editing.
    final loadKey = _isNew ? 'new' : tracker!.id;
    if (_loadedForId != loadKey) {
      _loadedForId = loadKey;
      _resetItemControllers();
      if (_isNew) {
        _nameController.text = '';
        // Start with one item; user can add up to 3.
        _addEmptyItem(key: 'a');
      } else {
        _nameController.text = tracker!.name;
        final items = tracker.items.isEmpty
            ? const [TrackerItem(key: 'a', emoji: '', description: '')]
            : tracker.items.take(3).toList();
        for (final it in items) {
          _addEmptyItem(key: it.key.trim().isEmpty ? _nextKey() : it.key);
          final idx = _itemKeys.length - 1;
          _emojiControllers[idx].text = it.emoji;
          _descControllers[idx].text = it.description;
          _targetEnabled[idx] = it.hasTarget;
          _targetCadence[idx] = it.targetCadence ?? TargetCadence.daily;
          _targetControllers[idx].text = (it.targetValue ?? '').toString();
        }
      }
    }

    final title = _isNew ? 'New tracker' : 'Edit tracker';

    return AppScaffold(
      title: title,
      actions: [
        if (!_isNew)
          IconButton(
            tooltip: (tracker!.archived) ? 'Unarchive' : 'Archive',
            icon: Icon(
                tracker.archived ? Icons.unarchive : Icons.archive_outlined),
            onPressed: () => _toggleArchive(context, tracker: tracker!),
          ),
      ],
      floatingActionButton: ReachabilityFabCluster(
        bottomBarHeight: NavShell.navBarHeight,
        actions: [
          ReachabilityFabAction(
            icon: Icons.add,
            tooltip: 'Add item',
            onPressed: _itemKeys.length >= 3
                ? null
                : () => setState(() => _addEmptyItem(key: _nextKey())),
            semanticLabel: 'Add tracker item',
          ),
          ReachabilityFabAction(
            icon: Icons.save,
            tooltip: _isNew ? 'Create' : 'Save',
            label: _isNew ? 'Create' : 'Save',
            isPrimary: true,
            onPressed: () => _save(context, tracker: tracker),
          ),
        ],
      ),
      children: [
        const SectionHeader(title: 'Basics'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tracker name',
                hintText: 'Ex: Water',
              ),
              textInputAction: TextInputAction.next,
            ),
          ),
        ),
        Gap.h16,
        SectionHeader(
          title: 'Items',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_itemKeys.length}/3'),
              Gap.w8,
              FilledButton.icon(
                onPressed: _itemKeys.length >= 3
                    ? null
                    : () => setState(() => _addEmptyItem(key: _nextKey())),
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ],
          ),
        ),
        for (var i = 0; i < _itemKeys.length; i++) ...[
          _ItemEditor(
            index: i,
            emojiController: _emojiControllers[i],
            descriptionController: _descControllers[i],
            targetController: _targetControllers[i],
            targetEnabled: _targetEnabled[i],
            cadence: _targetCadence[i] ?? TargetCadence.daily,
            canRemove: _itemKeys.length > 1,
            onRemove: () => setState(() => _removeItemAt(i)),
            onTargetEnabledChanged: (v) =>
                setState(() => _targetEnabled[i] = v),
            onCadenceChanged: (v) => setState(() => _targetCadence[i] = v),
          ),
          Gap.h12,
        ],
        Gap.h8,
        FilledButton.icon(
          onPressed: () => _save(context, tracker: tracker),
          icon: const Icon(Icons.save),
          label: Text(_isNew ? 'Create' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _toggleArchive(BuildContext context,
      {required Tracker tracker}) async {
    final wantArchive = !tracker.archived;
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title:
                Text(wantArchive ? 'Archive tracker?' : 'Unarchive tracker?'),
            content: Text(
              wantArchive
                  ? 'This hides it from Today but keeps historical tallies.'
                  : 'This shows it on Today again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(wantArchive ? 'Archive' : 'Unarchive'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    await ref
        .read(trackersListProvider.notifier)
        .setArchived(id: tracker.id, archived: wantArchive);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(wantArchive ? 'Archived' : 'Unarchived')),
    );
  }

  Future<void> _save(BuildContext context, {required Tracker? tracker}) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }

    final items = <TrackerItem>[];
    for (var i = 0; i < _itemKeys.length; i++) {
      final emoji = _emojiControllers[i].text.trim();
      final desc = _descControllers[i].text.trim();
      if (emoji.isEmpty || desc.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Each item needs an emoji + description')),
        );
        return;
      }
      final enabled = _targetEnabled[i];
      final cadence = _targetCadence[i] ?? TargetCadence.daily;
      final targetRaw = _targetControllers[i].text.trim();
      final target = targetRaw.isEmpty ? null : int.tryParse(targetRaw);
      if (enabled) {
        if (target == null || target <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Target must be a positive number')),
          );
          return;
        }
      }
      items.add(
        TrackerItem(
          key: _itemKeys[i],
          emoji: emoji,
          description: desc,
          targetCadence: enabled ? cadence : null,
          targetValue: enabled ? target : null,
        ),
      );
    }

    try {
      if (_isNew) {
        final created = await ref
            .read(trackersListProvider.notifier)
            .create(name: name, items: items);
        if (!context.mounted) return;
        context.go('/settings/trackers/edit/${created.id}');
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Tracker created')));
      } else {
        await ref
            .read(trackersListProvider.notifier)
            .updateTracker(id: tracker!.id, name: name, items: items);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }
}

class _ItemEditor extends StatelessWidget {
  const _ItemEditor({
    required this.index,
    required this.emojiController,
    required this.descriptionController,
    required this.targetController,
    required this.targetEnabled,
    required this.cadence,
    required this.canRemove,
    required this.onRemove,
    required this.onTargetEnabledChanged,
    required this.onCadenceChanged,
  });

  final int index;
  final TextEditingController emojiController;
  final TextEditingController descriptionController;
  final TextEditingController targetController;

  final bool targetEnabled;
  final TargetCadence cadence;
  final bool canRemove;
  final VoidCallback onRemove;
  final ValueChanged<bool> onTargetEnabledChanged;
  final ValueChanged<TargetCadence> onCadenceChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Item ${index + 1}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (canRemove)
                  IconButton(
                    tooltip: 'Remove item',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            Gap.h12,
            Row(
              children: [
                SizedBox(
                  width: 84,
                  child: TextField(
                    controller: emojiController,
                    decoration: const InputDecoration(
                      labelText: 'Emoji',
                      hintText: '🥤',
                    ),
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      // Keep it simple: max 2 UTF-16 code units to discourage multi-char input.
                      LengthLimitingTextInputFormatter(2),
                    ],
                  ),
                ),
                Gap.w12,
                Expanded(
                  child: TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Cup (8oz)',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            Gap.h12,
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: targetEnabled,
              onChanged: onTargetEnabledChanged,
              title: const Text('Target (optional)'),
              subtitle: const Text('Daily, weekly, or yearly'),
            ),
            if (targetEnabled) ...[
              Gap.h8,
              Row(
                children: [
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<TargetCadence>(
                      value: cadence,
                      items: const [
                        DropdownMenuItem(
                          value: TargetCadence.daily,
                          child: Text('Daily'),
                        ),
                        DropdownMenuItem(
                          value: TargetCadence.weekly,
                          child: Text('Weekly'),
                        ),
                        DropdownMenuItem(
                          value: TargetCadence.yearly,
                          child: Text('Yearly'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        onCadenceChanged(v);
                      },
                      decoration: const InputDecoration(labelText: 'Cadence'),
                    ),
                  ),
                  Gap.w12,
                  Expanded(
                    child: TextField(
                      controller: targetController,
                      decoration: const InputDecoration(
                        labelText: 'Target',
                        hintText: '8',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
