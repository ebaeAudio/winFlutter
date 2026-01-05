import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Map raw exceptions into concise, user-friendly messages.
///
/// Keep this small and boring; it’s used in UI.
String friendlyError(Object error) {
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'That email/password combination doesn’t look right.';
    }
    if (msg.contains('user already registered')) {
      return 'That email is already registered. Try signing in instead.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please confirm your email, then try again.';
    }
    return error.message;
  }

  return 'Something went wrong. Please try again.';
}

Future<void> showErrorDialog(
  BuildContext context, {
  String title = 'Something went wrong',
  required Object error,
  String? message,
  bool includeRawDetails = true,
}) async {
  final friendly = message ?? friendlyError(error);
  final raw = error.toString();
  final showRaw = includeRawDetails &&
      raw.trim().isNotEmpty &&
      raw.trim() != friendly.trim();

  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(friendly),
              if (showRaw) ...[
                const SizedBox(height: 12),
                Text('Details', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                SelectableText(
                  raw,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}
