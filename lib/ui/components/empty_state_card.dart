import 'package:flutter/material.dart';

import '../spacing.dart';

/// Empty state display for when content is not available.
///
/// Use this to guide users toward action. Keep copy concise and operational.
///
/// Design system: Uses plain layout (no Card wrapper) to avoid component soup.
/// Add `useCard: true` only when this appears in a context requiring grouping.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.ctaLabel,
    this.onCtaPressed,
    this.useCard = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? ctaLabel;
  final VoidCallback? onCtaPressed;

  /// When true, wraps content in a Card. Prefer false for inline empty states.
  final bool useCard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: scheme.onSurfaceVariant),
        Gap.h12,
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Gap.h4,
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (ctaLabel != null && onCtaPressed != null) ...[
          Gap.h12,
          FilledButton(
            onPressed: onCtaPressed,
            child: Text(ctaLabel!),
          ),
        ],
      ],
    );

    if (!useCard) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s16),
        child: content,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: content,
      ),
    );
  }
}

/// @Deprecated('Use EmptyState instead')
/// Kept for backwards compatibility during migration.
typedef EmptyStateCard = EmptyState;
