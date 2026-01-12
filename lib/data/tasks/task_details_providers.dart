import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/env.dart';
import '../../app/supabase.dart';
import 'task_details_models.dart';
import 'supabase_task_details_repository.dart';
import 'task_details_repository.dart';

final taskDetailsRepositoryProvider = Provider<TaskDetailsRepository?>((ref) {
  final env = ref.watch(envProvider);
  final supabase = ref.watch(supabaseProvider);

  if (env.demoMode) return null;
  if (!supabase.isInitialized) return null;

  // Note: if the DB schema isn't migrated yet, calls will fail; the UI handles
  // this with retry and a graceful empty-details fallback.
  return SupabaseTaskDetailsRepository(Supabase.instance.client);
});

final taskDetailsProvider =
    FutureProvider.family<TaskDetails, String>((ref, taskId) async {
  final repo = ref.watch(taskDetailsRepositoryProvider);
  if (repo == null) return TaskDetails.empty(taskId);
  try {
    return await repo.getDetails(taskId: taskId);
  } catch (_) {
    return TaskDetails.empty(taskId);
  }
});
