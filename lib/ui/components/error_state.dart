import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../spacing.dart';

/// Actionable error state for async content failures.
///
/// Errors must be user-actionable. Always provide at least one of:
/// - `onRetry`: For transient errors (network, timeout)
/// - `onAction` + `actionLabel`: For navigation (settings, help)
///
/// Design system: Non-blocking by default. Use blocking sparingly.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
    this.actionLabel,
    this.onAction,
    this.isBlocking = false,
  });

  /// Short, clear error title. Avoid technical jargon.
  final String title;

  /// Optional details. Keep concise — users rarely read error messages.
  final String? message;

  /// Primary action: retry the failed operation.
  final VoidCallback? onRetry;

  /// Secondary action label (e.g., "Open Settings", "Learn more").
  final String? actionLabel;

  /// Secondary action callback.
  final VoidCallback? onAction;

  /// When true, uses more prominent styling for blocking errors.
  final bool isBlocking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.error_outline,
              size: 20,
              color: scheme.error,
            ),
            Gap.w8,
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.error,
                ),
              ),
            ),
          ],
        ),
        if (message != null && message!.isNotEmpty) ...[
          Gap.h8,
          Text(
            message!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (onRetry != null || onAction != null) ...[
          Gap.h12,
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              if (onRetry != null)
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                ),
              if (onAction != null && actionLabel != null)
                OutlinedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
            ],
          ),
        ],
      ],
    );

    if (isBlocking) {
      return Container(
        padding: const EdgeInsets.all(AppSpace.s16),
        decoration: BoxDecoration(
          color: scheme.errorContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(kRadiusMedium),
        ),
        child: content,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
      child: content,
    );
  }
}
