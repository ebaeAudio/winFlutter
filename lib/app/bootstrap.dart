import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'env.dart';
import 'supabase.dart';

/// App startup initialization (env loading happens before this in `main()`).
Future<void> bootstrap(ProviderContainer container) async {
  // Read env and initialize services eagerly so routing/auth has what it needs.
  final env = container.read(envProvider);
  await container.read(supabaseProvider.notifier).initIfConfigured(env);
}
