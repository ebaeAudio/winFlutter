import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/auth.dart';
import '../../app/supabase.dart';
import '../../app/theme.dart' show sharedPreferencesProvider;
import '../../data/focus/focus_policy_repository.dart';
import '../../data/focus/focus_session_repository.dart';
import '../../data/focus/local_focus_policy_repository.dart';
import '../../data/focus/local_focus_session_repository.dart';
import '../../data/focus/supabase_focus_session_sync.dart';
import '../../data/focus/synced_focus_session_repository.dart';
import '../../platform/restriction_engine/restriction_engine.dart';
import '../../platform/restriction_engine/restriction_engine_channel.dart';

final focusPolicyRepositoryProvider = Provider<FocusPolicyRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalFocusPolicyRepository(prefs);
});

/// Provider for the Supabase focus session sync layer.
///
/// Returns null if Supabase is not initialized or user is not signed in.
final supabaseFocusSessionSyncProvider =
    Provider<SupabaseFocusSessionSync?>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final auth = ref.watch(authStateProvider).valueOrNull;

  if (!supabase.isInitialized) return null;
  if (auth == null || !auth.isSignedIn || auth.isDemo) return null;

  return SupabaseFocusSessionSync(Supabase.instance.client);
});

/// Provider for the synced focus session repository.
///
/// Returns the synced repository when signed in to Supabase,
/// otherwise falls back to local-only storage.
final focusSessionRepositoryProvider = Provider<FocusSessionRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final sync = ref.watch(supabaseFocusSessionSyncProvider);

  if (sync != null) {
    return SyncedFocusSessionRepository(prefs: prefs, remoteSync: sync);
  }

  return LocalFocusSessionRepository(prefs);
});

/// Provider specifically for the synced repository (when available).
///
/// This allows access to the remote session metadata (e.g., source platform).
/// Returns null if not using synced repository.
final syncedFocusSessionRepositoryProvider =
    Provider<SyncedFocusSessionRepository?>((ref) {
  final repo = ref.watch(focusSessionRepositoryProvider);
  if (repo is SyncedFocusSessionRepository) return repo;
  return null;
});

final restrictionEngineProvider = Provider<RestrictionEngine>((ref) {
  return const MethodChannelRestrictionEngine();
});
