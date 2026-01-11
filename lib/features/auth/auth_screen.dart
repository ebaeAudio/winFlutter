import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/errors.dart';
import '../../app/supabase.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/components/info_banner.dart';
import '../../ui/components/section_header.dart';
import '../../ui/spacing.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.next});

  /// Safe relative path to return to after successful sign-in.
  /// Note: routing redirect logic is responsible for honoring this value.
  final String? next;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  var _mode = _AuthMode.signIn;
  var _busy = false;
  String? _error;
  String? _info;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _submitted = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validateEmail(String raw) {
    final email = raw.trim();
    if (email.isEmpty) return 'Email is required.';
    if (!email.contains('@')) return 'Enter a valid email.';
    return null;
  }

  String? _validatePassword(String raw) {
    if (_mode == _AuthMode.magicLink) return null;
    if (raw.isEmpty) return 'Password is required.';
    if (_mode == _AuthMode.signUp && raw.length < 8) {
      return 'Use at least 8 characters.';
    }
    return null;
  }

  String? _validateConfirm(String raw) {
    if (_mode != _AuthMode.signUp) return null;
    if (raw.isEmpty) return 'Confirm your password.';
    if (raw != _password.text) return 'Passwords do not match.';
    return null;
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await fn();
      setState(() => _info = 'Success.');
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabase = ref.watch(supabaseProvider);
    final client = supabase.client;
    final emailError = _submitted ? _validateEmail(_email.text) : null;
    final passwordError = _submitted ? _validatePassword(_password.text) : null;
    final confirmError = _submitted ? _validateConfirm(_confirm.text) : null;

    return AppScaffold(
      title: 'Sign in',
      children: [
        const SectionHeader(title: 'Method'),
        SegmentedButton<_AuthMode>(
          segments: const [
            ButtonSegment(value: _AuthMode.signIn, label: Text('Sign in')),
            ButtonSegment(value: _AuthMode.signUp, label: Text('Sign up')),
            ButtonSegment(
                value: _AuthMode.magicLink, label: Text('Magic link')),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() {
            _mode = s.first;
            _submitted = false;
            _error = null;
            _info = null;
          }),
        ),
        Gap.h16,
        const SectionHeader(title: 'Credentials'),
        TextField(
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            labelText: 'Email',
            errorText: emailError,
          ),
        ),
        Gap.h12,
        if (_mode != _AuthMode.magicLink) ...[
          TextField(
            controller: _password,
            enabled: !_busy,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Password',
              errorText: passwordError,
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: _busy
                    ? null
                    : () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off),
              ),
            ),
          ),
          Gap.h12,
          if (_mode == _AuthMode.signUp)
            TextField(
              controller: _confirm,
              enabled: !_busy,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                errorText: confirmError,
                suffixIcon: IconButton(
                  tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                  onPressed: _busy
                      ? null
                      : () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility
                      : Icons.visibility_off),
                ),
              ),
            ),
        ],
        Gap.h16,
        if (client == null)
          const InfoBanner(
            title: 'Supabase isn’t configured',
            tone: InfoBannerTone.warning,
            message: 'Go back and enable demo mode, or configure `assets/env`.',
          ),
        if (_error != null) ...[
          Gap.h12,
          InfoBanner(
              title: 'Couldn’t sign you in',
              tone: InfoBannerTone.error,
              message: _error),
        ],
        if (_info != null) ...[
          Gap.h12,
          InfoBanner(
              title: 'Done', tone: InfoBannerTone.neutral, message: _info),
        ],
        Gap.h12,
        FilledButton(
          onPressed: _busy || client == null
              ? null
              : () {
                  setState(() => _submitted = true);
                  if (emailError != null ||
                      passwordError != null ||
                      confirmError != null) return;

                  _run(() async {
                    final email = _email.text.trim();
                    switch (_mode) {
                      case _AuthMode.signIn:
                        await client.auth.signInWithPassword(
                          email: email,
                          password: _password.text,
                        );
                        break;
                      case _AuthMode.signUp:
                        await client.auth
                            .signUp(email: email, password: _password.text);
                        setState(() => _info =
                            'Check your email to confirm your account.');
                        break;
                      case _AuthMode.magicLink:
                        await client.auth.signInWithOtp(email: email);
                        setState(() =>
                            _info = 'Check your email for the magic link.');
                        break;
                    }
                  });
                },
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_mode.cta),
        ),
      ],
    );
  }
}

enum _AuthMode { signIn, signUp, magicLink }

extension on _AuthMode {
  String get cta => switch (this) {
        _AuthMode.signIn => 'Sign in',
        _AuthMode.signUp => 'Create account',
        _AuthMode.magicLink => 'Send magic link',
      };
}
