import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../spacing.dart';

/// A prominent call-to-action button designed to be the primary action on screen.
///
/// Use sparingly — ideally **one per screen**. This is the visual anchor that
/// guides users to the main action.
///
/// Design system:
/// - Uses `kRadiusSmall` (8px) for button corners
/// - Minimum 48px height for accessibility
/// - Full width by default to maximize tap target
class PrimaryCTA extends StatelessWidget {
  const PrimaryCTA({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s24,
          vertical: AppSpace.s12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusSmall),
        ),
        textStyle: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.onPrimary,
              ),
            )
          else if (icon != null)
            Icon(icon, size: 20),
          if (icon != null || loading) Gap.w8,
          Text(label),
        ],
      ),
    );
  }
}
