import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/env.dart';
import '../../app/supabase.dart';
import '../../app/theme.dart';
import 'all_tasks_repository.dart';
import 'local_all_tasks_repository.dart';
import 'supabase_all_tasks_repository.dart';
import 'tasks_providers.dart';

final allTasksRepositoryProvider = Provider<AllTasksRepository?>((ref) {
  final env = ref.watch(envProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final tasksRepo = ref.watch(tasksRepositoryProvider);
  final supabase = ref.watch(supabaseProvider);

  if (env.demoMode) {
    return LocalAllTasksRepository(prefs);
  }

  if (tasksRepo == null) return null;
  return SupabaseAllTasksRepository(
    client: supabase.client!,
    tasksRepository: tasksRepo,
  );
});
