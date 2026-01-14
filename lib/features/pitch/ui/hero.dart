import 'package:flutter/material.dart';

import '../../../ui/spacing.dart';
import '../pitch_content.dart';

class HeroSection extends StatelessWidget {
  const HeroSection({
    super.key,
    required this.content,
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
  });

  final PitchHeroContent content;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                content.headline,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Gap.h8,
            Text(
              content.subheadline,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Gap.h16,
            Wrap(
              spacing: AppSpace.s12,
              runSpacing: AppSpace.s12,
              children: [
                FilledButton(
                  onPressed: onPrimaryPressed,
                  child: Text(content.primaryCtaLabel),
                ),
                OutlinedButton(
                  onPressed: onSecondaryPressed,
                  child: Text(content.secondaryCtaLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

