import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/env.dart';
import '../../app/supabase.dart';
import 'supabase_tasks_repository.dart';
import 'tasks_repository.dart';

final tasksRepositoryProvider = Provider<TasksRepository?>((ref) {
  final env = ref.watch(envProvider);
  final supabase = ref.watch(supabaseProvider);

  if (env.demoMode) return null;
  if (!supabase.isInitialized) return null;

  return SupabaseTasksRepository(Supabase.instance.client);
});
