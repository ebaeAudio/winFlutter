import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';
import 'supabase.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  final env = ref.watch(envProvider);
  final supabase = ref.watch(supabaseProvider);

  // Demo mode behaves like an always-signed-in user.
  if (env.demoMode) {
    return Stream<AuthState>.value(const AuthState.signedIn(isDemo: true));
  }

  // If Supabase isn't configured, force "signed out" (setup required).
  if (!supabase.isInitialized) {
    return Stream<AuthState>.value(const AuthState.signedOut(needsSetup: true));
  }

  final client = Supabase.instance.client;
  final controller = StreamController<AuthState>();

  void emitFromSession(Session? session) {
    if (session == null) {
      controller.add(const AuthState.signedOut(needsSetup: false));
    } else {
      controller
          .add(AuthState.signedIn(isDemo: false, email: session.user.email));
    }
  }

  // Emit current session immediately.
  emitFromSession(client.auth.currentSession);

  final sub = client.auth.onAuthStateChange.listen((data) {
    emitFromSession(data.session);
  });

  ref.onDispose(() async {
    await sub.cancel();
    await controller.close();
  });

  return controller.stream;
});

class AuthState {
  const AuthState._({
    required this.isSignedIn,
    required this.isDemo,
    required this.needsSetup,
    required this.email,
  });

  final bool isSignedIn;
  final bool isDemo;
  final bool needsSetup;
  final String? email;

  const AuthState.signedIn({required bool isDemo, String? email})
      : this._(
          isSignedIn: true,
          isDemo: isDemo,
          needsSetup: false,
          email: email,
        );

  const AuthState.signedOut({required bool needsSetup})
      : this._(
          isSignedIn: false,
          isDemo: false,
          needsSetup: needsSetup,
          email: null,
        );
}
