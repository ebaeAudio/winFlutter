import 'package:flutter/material.dart';

import '../../../ui/spacing.dart';
import '../pitch_content.dart';

class StickyCtaBar extends StatelessWidget {
  const StickyCtaBar({
    super.key,
    required this.content,
    required this.primaryLabel,
    required this.onPrimaryPressed,
  });

  final PitchStickyCtaBarContent content;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Semantics(
        container: true,
        label: content.semanticsLabel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(color: theme.dividerColor.withOpacity(0.6)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s12),
            child: SizedBox(
              width: double.infinity,
              height: 48, // touch target >= 44
              child: FilledButton(
                onPressed: onPrimaryPressed,
                child: Text(primaryLabel),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

