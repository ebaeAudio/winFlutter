import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/env.dart';
import '../../app/supabase.dart';
import '../../app/theme.dart';
import 'local_tracker_tallies_repository.dart';
import 'local_trackers_repository.dart';
import 'supabase_tracker_tallies_repository.dart';
import 'supabase_trackers_repository.dart';
import 'tracker_tallies_repository.dart';
import 'trackers_repository.dart';

final trackersRepositoryProvider = Provider<TrackersRepository?>((ref) {
  final env = ref.watch(envProvider);
  final supabase = ref.watch(supabaseProvider);

  if (env.demoMode) return null;
  if (!supabase.isInitialized) return null;

  return SupabaseTrackersRepository(Supabase.instance.client);
});

final trackerTalliesRepositoryProvider =
    Provider<TrackerTalliesRepository?>((ref) {
  final env = ref.watch(envProvider);
  final supabase = ref.watch(supabaseProvider);

  if (env.demoMode) return null;
  if (!supabase.isInitialized) return null;

  return SupabaseTrackerTalliesRepository(Supabase.instance.client);
});

final localTrackersRepositoryProvider = Provider<TrackersRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalTrackersRepository(prefs);
});

final localTrackerTalliesRepositoryProvider =
    Provider<TrackerTalliesRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalTrackerTalliesRepository(prefs);
});


