import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

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

  final client = sb.Supabase.instance.client;
  final controller = StreamController<AuthState>();

  void emit({required sb.Session? session, required bool needsPasswordReset}) {
    if (session == null) {
      controller.add(const AuthState.signedOut(needsSetup: false));
      return;
    }
    controller.add(
      AuthState.signedIn(
        isDemo: false,
        email: session.user.email,
        needsPasswordReset: needsPasswordReset,
      ),
    );
  }

  // Emit current session immediately.
  emit(session: client.auth.currentSession, needsPasswordReset: false);

  final sub = client.auth.onAuthStateChange.listen((data) {
    final needsPasswordReset = data.event == sb.AuthChangeEvent.passwordRecovery;
    emit(session: data.session, needsPasswordReset: needsPasswordReset);
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
    required this.needsPasswordReset,
  });

  final bool isSignedIn;
  final bool isDemo;
  final bool needsSetup;
  final String? email;
  final bool needsPasswordReset;

  const AuthState.signedIn({
    required bool isDemo,
    String? email,
    bool needsPasswordReset = false,
  })
      : this._(
          isSignedIn: true,
          isDemo: isDemo,
          needsSetup: false,
          email: email,
          needsPasswordReset: needsPasswordReset,
        );

  const AuthState.signedOut({required bool needsSetup})
      : this._(
          isSignedIn: false,
          isDemo: false,
          needsSetup: needsSetup,
          email: null,
          needsPasswordReset: false,
        );
}
