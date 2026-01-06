import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/trackers/tracker_models.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/components/empty_state_card.dart';
import '../../../ui/components/section_header.dart';
import '../../../ui/spacing.dart';
import 'trackers_controller.dart';

class TrackersScreen extends ConsumerWidget {
  const TrackersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackersAsync = ref.watch(trackersListProvider);

    return AppScaffold(
      title: 'Trackers',
      actions: [
        IconButton(
          tooltip: 'Create',
          onPressed: () => context.go('/home/settings/trackers/new'),
          icon: const Icon(Icons.add),
        ),
      ],
      children: [
        trackersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s12),
              child: Text('Failed to load trackers: $e'),
            ),
          ),
          data: (items) {
            final active = items.where((t) => !t.archived).toList();
            final archived = items.where((t) => t.archived).toList();

            if (active.isEmpty && archived.isEmpty) {
              return EmptyStateCard(
                icon: Icons.emoji_objects_outlined,
                title: 'Add a tracker',
                description:
                    'Track three quick-tally items (emoji + description) right from Today.',
                ctaLabel: 'Create tracker',
                onCtaPressed: () => context.go('/home/settings/trackers/new'),
              );
            }

            return Column(
              children: [
                if (active.isNotEmpty) ...[
                  const SectionHeader(title: 'Active'),
                  for (final t in active) ...[
                    _TrackerTile(tracker: t),
                    Gap.h12,
                  ],
                ],
                if (archived.isNotEmpty) ...[
                  const SectionHeader(title: 'Archived'),
                  for (final t in archived) ...[
                    _TrackerTile(tracker: t),
                    Gap.h12,
                  ],
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TrackerTile extends StatelessWidget {
  const _TrackerTile({required this.tracker});

  final Tracker tracker;

  @override
  Widget build(BuildContext context) {
    final emojis = tracker.items.map((i) => i.emoji).where((e) => e.trim().isNotEmpty).join(' ');
    final subtitle = emojis.isEmpty ? '3 items' : emojis;

    return Card(
      child: ListTile(
        title: Text(tracker.name),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/home/settings/trackers/edit/${tracker.id}'),
      ),
    );
  }
}


