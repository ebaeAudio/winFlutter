import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Map raw exceptions into concise, user-friendly messages.
///
/// Keep this small and boring; it’s used in UI.
String friendlyError(Object error) {
  if (error is StateError) {
    final msg = error.message.toString().trim();
    if (msg.isNotEmpty) return msg;
  }

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

  if (error is PostgrestException) {
    final msg = error.message.toLowerCase();
    final details = (error.details?.toString() ?? '').toLowerCase();
    final hint = (error.hint?.toString() ?? '').toLowerCase();
    final combined = '$msg $details $hint';

    // Feedback constraints (keep these aligned with supabase migrations).
    if (combined.contains('user_feedback_description_length')) {
      return 'Your description is too long. Keep it under 280 characters, then try again.';
    }
    if (combined.contains('user_feedback_details_length')) {
      return 'Your details are too long. Keep them under 2000 characters, then try again.';
    }

    // Common schema mismatch when the repo code is newer than the Supabase DB.
    bool looksLikeMissingColumn(String column) {
      final c = column.toLowerCase();
      if (!combined.contains(c)) return false;
      return combined.contains('does not exist') ||
          combined.contains('could not find the column') ||
          (combined.contains('column') && combined.contains('not found'));
    }

    // Common schema mismatch when the repo code is newer than the Supabase DB.
    if (looksLikeMissingColumn('in_progress')) {
      return 'Your Supabase schema is missing `tasks.in_progress`. Apply the migration in `supabase/migrations/20260112000000_add_tasks_in_progress.sql`, then restart the app.';
    }

    if (looksLikeMissingColumn('notes') ||
        looksLikeMissingColumn('next_step') ||
        looksLikeMissingColumn('estimate_minutes') ||
        looksLikeMissingColumn('actual_minutes')) {
      return 'Your Supabase schema is missing Task Details columns on `tasks`. Run `docs/SUPABASE_TASK_DETAILS_SCHEMA.sql` in the Supabase SQL editor, then restart the app.';
    }

    if (combined.contains('task_subtasks') &&
        (combined.contains('does not exist') ||
            combined.contains('could not find the table') ||
            (combined.contains('relation') && combined.contains('does not exist')))) {
      return 'Your Supabase schema is missing the `task_subtasks` table. Run `docs/SUPABASE_TASK_DETAILS_SCHEMA.sql` in the Supabase SQL editor, then restart the app.';
    }

    if (combined.contains('permission denied') || combined.contains('rls')) {
      return 'Permission denied by the database (RLS). Check your Supabase policies, then try again.';
    }

    // Check for function/table not found errors
    if (combined.contains('function') && 
        (combined.contains('does not exist') || combined.contains('not found'))) {
      if (combined.contains('is_admin')) {
        return 'The is_admin() function is missing. Apply the migration in supabase/migrations/20260115_000001_admin_users.sql, then restart the app.';
      }
      if (combined.contains('admin_list_users')) {
        return 'The admin_list_users() function is missing. Apply the migration in supabase/migrations/20260116_000001_admin_user_management.sql, then restart the app.';
      }
      return 'Database function not found. Make sure all migrations are applied.';
    }

    // Check for missing admin_users table
    if ((combined.contains('admin_users') || combined.contains('admin users')) &&
        (combined.contains('does not exist') || 
         combined.contains('could not find the table') ||
         (combined.contains('relation') && combined.contains('does not exist')))) {
      return 'The admin_users table is missing. Apply the migration in supabase/migrations/20260115_000001_admin_users.sql, then restart the app.';
    }

    // Check for missing user_feedback table
    if ((combined.contains('user_feedback') || combined.contains('user feedback')) &&
        (combined.contains('does not exist') || 
         combined.contains('could not find the table') ||
         (combined.contains('relation') && combined.contains('does not exist')))) {
      return 'The user_feedback table is missing. Apply the migration in supabase/migrations/20260112_000001_user_feedback.sql, then restart the app.';
    }

    // Keep it concise; raw details can be shown via `showErrorDialog` when needed.
    return 'Database error. Please try again.';
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
