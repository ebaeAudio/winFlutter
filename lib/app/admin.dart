import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'auth.dart';
import 'env.dart';
import 'supabase.dart';

/// Provider that checks if the current user is an admin.
/// Returns null if not signed in, false if signed in but not admin, true if admin.
final isAdminProvider = FutureProvider<bool?>((ref) async {
  final env = ref.watch(envProvider);
  final supabase = ref.watch(supabaseProvider);
  final auth = ref.watch(authStateProvider).valueOrNull;

  // Demo mode is never admin.
  if (env.demoMode || auth?.isDemo == true) {
    return false;
  }

  // Must be signed in.
  if (auth?.isSignedIn != true) {
    return null;
  }

  // Must have Supabase configured.
  if (!supabase.isInitialized) {
    return false;
  }

  final client = sb.Supabase.instance.client;
  final session = client.auth.currentSession;
  if (session == null) {
    return false;
  }

  try {
    // Use the is_admin() function which bypasses RLS (security definer).
    // This function can check admin status even when RLS blocks direct table access.
    final result = await client.rpc('is_admin', params: {
      'user_id_param': session.user.id,
    });

    return result as bool? ?? false;
  } catch (e) {
    // If the function doesn't exist, that's a configuration issue - rethrow with context.
    if (e.toString().contains('function') && 
        (e.toString().contains('does not exist') || e.toString().contains('not found'))) {
      throw StateError(
        'The is_admin() database function is missing. Apply the migration in supabase/migrations/20260115_000001_admin_users.sql',
      );
    }
    
    // If the function doesn't exist or there's an error, try direct query as fallback.
    // This will fail if RLS blocks it, but that's okay - we'll return false.
    try {
      final result = await client
          .from('admin_users')
          .select('user_id')
          .eq('user_id', session.user.id)
          .maybeSingle();
      return result != null;
    } catch (_) {
      // If the table doesn't exist yet or RLS blocks access, return false (graceful degradation).
      return false;
    }
  }
});
