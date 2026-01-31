import 'package:flutter/material.dart';

import '../spacing.dart';

/// A section header for content grouping.
///
/// Design system:
/// - Uses typography for hierarchy, not visual weight
/// - Icons only when they improve scanning (avoid decorative icons)
/// - Trailing action should be contextual, not always visible
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.trailing,
    this.padding,
  });

  final String title;

  /// Optional icon. Only include if it helps disambiguate or improve scanning.
  final IconData? icon;
  final Color? iconColor;

  /// Optional trailing widget (action button, count badge, etc.).
  /// Should be contextual — avoid always-visible actions.
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding ??
          const EdgeInsets.only(top: AppSpace.s16, bottom: AppSpace.s8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: iconColor ?? scheme.onSurfaceVariant,
            ),
            Gap.w8,
          ],
          Expanded(
            child: Text(
              title,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (trailing != null) ...[
            Gap.w8,
            trailing!,
          ],
        ],
      ),
    );
  }
}
