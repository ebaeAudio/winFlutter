import 'package:flutter/material.dart';

import '../../../ui/spacing.dart';
import '../pitch_content.dart';

class FinalCta extends StatelessWidget {
  const FinalCta({
    super.key,
    required this.content,
    required this.onPrimaryPressed,
  });

  final PitchFinalCtaContent content;
  final VoidCallback onPrimaryPressed;

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
                content.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Gap.h8,
            Text(
              content.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Gap.h16,
            FilledButton(
              onPressed: onPrimaryPressed,
              child: Text(content.primaryCtaLabel),
            ),
          ],
        ),
      ),
    );
  }
}

