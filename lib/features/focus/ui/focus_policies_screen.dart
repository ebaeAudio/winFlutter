import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/app_scaffold.dart';
import '../focus_policy_controller.dart';

class FocusPoliciesScreen extends ConsumerWidget {
  const FocusPoliciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policies = ref.watch(focusPolicyListProvider);

    return AppScaffold(
      title: 'Focus Policies',
      actions: [
        IconButton(
          tooltip: 'Create',
          onPressed: () async {
            final created =
                await ref.read(focusPolicyListProvider.notifier).createDefault();
            if (!context.mounted) return;
            // `closeOnSave=1` makes the editor navigate back to the list after the
            // first successful save in the "new policy" flow.
            context.go('/home/focus/policies/edit/${created.id}?closeOnSave=1');
          },
          icon: const Icon(Icons.add),
        ),
      ],
      children: [
        policies.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Failed to load policies: $e'),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No policies yet. Tap + to create one.'),
                ),
              );
            }
            return Column(
              children: [
                for (final p in items) ...[
                  Card(
                    child: ListTile(
                      title: Text(p.name),
                      subtitle: Text('${p.allowedApps.length} allowed apps'),
                      trailing: IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final controller =
                              ref.read(focusPolicyListProvider.notifier);
                          final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete policy?'),
                                  content: Text('“${p.name}” will be removed.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;
                          if (!ok) return;
                          await controller.delete(p.id);
                        },
                      ),
                      onTap: () =>
                          context.go('/home/focus/policies/edit/${p.id}'),
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


