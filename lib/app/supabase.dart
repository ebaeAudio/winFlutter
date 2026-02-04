import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

final supabaseProvider =
    StateNotifierProvider<SupabaseController, SupabaseState>(
  (ref) => SupabaseController(),
);

class SupabaseState {
  const SupabaseState({
    required this.isInitialized,
    required this.isConfigured,
  });

  final bool isInitialized;
  final bool isConfigured;

  SupabaseClient? get client => isInitialized ? Supabase.instance.client : null;

  static const unconfigured = SupabaseState(
    isInitialized: false,
    isConfigured: false,
  );
}

class SupabaseController extends StateNotifier<SupabaseState> {
  SupabaseController() : super(SupabaseState.unconfigured);

  Future<void> initIfConfigured(Env env) async {
    if (!env.isSupabaseConfigured) {
      state = const SupabaseState(isInitialized: false, isConfigured: false);
      return;
    }
    if (state.isInitialized) return;

    await Supabase.initialize(
      url: env.supabaseUrl,
      anonKey: env.supabaseAnonKey,
      // On mobile, configure the SDK to listen for auth deep links
      // (magic link sign-in, password reset). The SDK uses app_links internally.
      authOptions: kIsWeb
          ? const FlutterAuthClientOptions()
          : const FlutterAuthClientOptions(
              authFlowType: AuthFlowType.pkce,
            ),
    );
    state = const SupabaseState(isInitialized: true, isConfigured: true);
  }
}
