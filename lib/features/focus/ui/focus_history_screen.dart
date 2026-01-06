import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../ui/app_scaffold.dart';
import '../focus_session_controller.dart';

class FocusHistoryScreen extends ConsumerWidget {
  const FocusHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(focusSessionHistoryProvider);

    return AppScaffold(
      title: 'Session history',
      actions: [
        IconButton(
          tooltip: 'Clear',
          onPressed: () async {
            final controller = ref.read(focusSessionHistoryProvider.notifier);
            final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear history?'),
                    content:
                        const Text('This removes all recorded Focus Sessions.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ) ??
                false;
            if (!ok) return;
            await controller.clear();
          },
          icon: const Icon(Icons.delete_sweep),
        ),
      ],
      children: [
        history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Failed to load history: $e'),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No sessions yet.'),
                ),
              );
            }
            return Column(
              children: [
                for (final s in items) ...[
                  Card(
                    child: ListTile(
                      title: Text(
                        '${DateFormat.yMMMd().add_jm().format(s.startedAt)} → ${DateFormat.jm().format(s.plannedEndAt)}',
                      ),
                      subtitle: Text(
                        'Reason: ${s.endReason?.name ?? '—'} • Emergency unlocks: ${s.emergencyUnlocksUsed}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}


