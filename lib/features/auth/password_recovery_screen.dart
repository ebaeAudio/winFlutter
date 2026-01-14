import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show UserAttributes;

import '../../app/errors.dart';
import '../../app/supabase.dart';
import '../../ui/app_scaffold.dart';
import '../../ui/components/info_banner.dart';
import '../../ui/spacing.dart';

class PasswordRecoveryScreen extends ConsumerStatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  ConsumerState<PasswordRecoveryScreen> createState() =>
      _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends ConsumerState<PasswordRecoveryScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _busy = false;
  bool _submitted = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  String? _validatePassword(String raw) {
    if (raw.isEmpty) return 'Password is required.';
    if (raw.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  String? _validateConfirm(String raw) {
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
      setState(() => _info = 'Password updated.');
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);

    final passwordError = _validatePassword(_password.text);
    final confirmError = _validateConfirm(_confirm.text);
    if (passwordError != null || confirmError != null) return;

    final supabase = ref.read(supabaseProvider);
    final client = supabase.client;
    if (client == null) return;

    final session = client.auth.currentSession;
    if (session == null) {
      setState(() {
        _error = 'This reset link is invalid or expired. Request a new one.';
      });
      return;
    }

    await _run(() async {
      await client.auth.updateUser(
        UserAttributes(password: _password.text),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final supabase = ref.watch(supabaseProvider);
    final client = supabase.client;
    final session = client?.auth.currentSession;

    final passwordError = _submitted ? _validatePassword(_password.text) : null;
    final confirmError = _submitted ? _validateConfirm(_confirm.text) : null;

    final readOnly = _busy || client == null;

    return AppScaffold(
      title: 'Reset password',
      children: [
        if (client == null)
          const InfoBanner(
            title: 'Supabase isn’t configured',
            tone: InfoBannerTone.warning,
            message: 'Configure `assets/env` or enable demo mode.',
          )
        else if (session == null)
          const InfoBanner(
            title: 'Link invalid or expired',
            tone: InfoBannerTone.warning,
            message: 'Request a new password reset email and try again.',
          ),
        Gap.h16,
        TextField(
          controller: _password,
          focusNode: _passwordFocus,
          enabled: !readOnly,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'New password',
            errorText: passwordError,
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              onPressed:
                  readOnly ? null : () => setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
              ),
            ),
          ),
          onSubmitted: (_) {
            if (readOnly) return;
            _confirmFocus.requestFocus();
          },
        ),
        Gap.h12,
        TextField(
          controller: _confirm,
          focusNode: _confirmFocus,
          enabled: !readOnly,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Confirm password',
            errorText: confirmError,
            suffixIcon: IconButton(
              tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
              onPressed:
                  readOnly ? null : () => setState(() => _obscureConfirm = !_obscureConfirm),
              icon: Icon(
                _obscureConfirm ? Icons.visibility : Icons.visibility_off,
              ),
            ),
          ),
          onSubmitted: (_) {
            if (readOnly) return;
            _submit();
          },
        ),
        if (_error != null) ...[
          Gap.h12,
          InfoBanner(
            title: 'Couldn’t update password',
            tone: InfoBannerTone.error,
            message: _error,
          ),
        ],
        if (_info != null) ...[
          Gap.h12,
          InfoBanner(
            title: 'Done',
            tone: InfoBannerTone.neutral,
            message: _info,
          ),
        ],
        Gap.h12,
        FilledButton(
          onPressed: readOnly || session == null ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update password'),
        ),
      ],
    );
  }
}

