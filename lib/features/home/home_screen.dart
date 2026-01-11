import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/auth.dart';
import '../../app/supabase.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider).valueOrNull;
    final supabase = ref.watch(supabaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Win the Year')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth?.isDemo == true ? 'Demo Mode' : 'Signed in',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(auth?.email ??
                        (auth?.isDemo == true ? 'demo@local' : '—')),
                    const SizedBox(height: 6),
                    Text(
                      supabase.isInitialized
                          ? 'Supabase: connected'
                          : 'Supabase: not configured',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.go('/today'),
              icon: const Icon(Icons.today),
              label: const Text('Today'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => context.go('/tasks'),
              icon: const Icon(Icons.view_list),
              label: const Text('All Tasks'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => context.go('/rollups'),
              icon: const Icon(Icons.bar_chart),
              label: const Text('Rollups'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.settings),
              label: const Text('Settings'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => context.go('/focus'),
              icon: const Icon(Icons.lock),
              label: const Text('Dumb Phone Mode'),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: auth?.isDemo == true
                  ? null
                  : () async {
                      final client = supabase.client;
                      if (client == null) return;
                      await client.auth.signOut();
                    },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
