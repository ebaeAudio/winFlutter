import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../spacing.dart';

/// Visual tone for contextual banners.
enum InfoBannerTone { neutral, warning, error, success }

/// A contextual inline banner for important messages.
///
/// Use sparingly — avoid showing multiple banners simultaneously.
/// For errors, prefer [ErrorState] when the error blocks the entire view.
///
/// Design system: Uses `kRadiusMedium` (12px) for container corners.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.title,
    this.message,
    this.tone = InfoBannerTone.neutral,
    this.action,
    this.onDismiss,
  });

  final String title;
  final String? message;
  final InfoBannerTone tone;

  /// Optional action button (e.g., "Retry", "Learn more").
  final Widget? action;

  /// If provided, shows a dismiss button.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (bg, fg, icon) = switch (tone) {
      InfoBannerTone.neutral => (
          scheme.surfaceContainerHighest,
          scheme.onSurface,
          Icons.info_outline,
        ),
      InfoBannerTone.warning => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.warning_amber_outlined,
        ),
      InfoBannerTone.error => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.error_outline,
        ),
      InfoBannerTone.success => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          Icons.check_circle_outline,
        ),
    };

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(kRadiusMedium),
      ),
      padding: const EdgeInsets.all(AppSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                if (message != null && message!.trim().isNotEmpty) ...[
                  Gap.h4,
                  Text(
                    message!,
                    style: theme.textTheme.bodySmall?.copyWith(color: fg),
                  ),
                ],
                if (action != null) ...[
                  Gap.h8,
                  action!,
                ],
              ],
            ),
          ),
          if (onDismiss != null) ...[
            Gap.w8,
            IconButton(
              onPressed: onDismiss,
              icon: Icon(Icons.close, size: 18, color: fg),
              constraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
              padding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }
}
