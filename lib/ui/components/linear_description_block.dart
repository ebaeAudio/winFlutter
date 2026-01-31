import 'package:flutter/material.dart';

import '../spacing.dart';
import 'linear_markdown_renderer.dart';

/// A clean description block for Linear issue descriptions.
///
/// Renders the description as markdown with good readability:
/// - Headings, bold/italic, lists, links, blockquotes
/// - Fenced code blocks with monospace, copy button, horizontal scroll
/// - Inline code with subtle background pill
/// - Mobile-optimized line height and paragraph spacing
///
/// Shows a subtle empty state if description is empty.
class LinearDescriptionBlock extends StatelessWidget {
  const LinearDescriptionBlock({
    super.key,
    required this.description,
    this.emptyMessage = 'No description in Linear',
    this.onLinkTap,
  });

  final String description;
  final String emptyMessage;

  /// Optional custom link handler. If null, opens URLs in external browser.
  final void Function(String url)? onLinkTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = description.trim();

    if (text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
        child: Text(
          emptyMessage,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant.withOpacity(0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // Render markdown with custom code block styling
    return LinearMarkdownRenderer(
      data: text,
      onLinkTap: onLinkTap,
    );
  }
}

/// Section label for separating Linear description from app notes.
class LinearDescriptionLabel extends StatelessWidget {
  const LinearDescriptionLabel({
    super.key,
    this.label = 'Description',
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
