import 'package:flutter/material.dart';

import '../spacing.dart';

enum InfoBannerTone { neutral, warning, error }

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.title,
    this.message,
    this.tone = InfoBannerTone.neutral,
    this.trailing,
  });

  final String title;
  final String? message;
  final InfoBannerTone tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (bg, fg, icon) = switch (tone) {
      InfoBannerTone.neutral => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurface,
          Icons.info_outline,
        ),
      InfoBannerTone.warning => (
          theme.colorScheme.tertiaryContainer,
          theme.colorScheme.onTertiaryContainer,
          Icons.warning_amber_outlined,
        ),
      InfoBannerTone.error => (
          theme.colorScheme.errorContainer,
          theme.colorScheme.onErrorContainer,
          Icons.error_outline,
        ),
    };

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
      ),
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
                if (message != null && message!.trim().isNotEmpty) ...[
                  Gap.h8,
                  SelectableText(
                    message!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            Gap.w12,
            trailing!,
          ],
        ],
      ),
    );
  }
}
