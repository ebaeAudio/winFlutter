import 'package:flutter/material.dart';

import '../../../ui/components/accent_card.dart';
import '../../../ui/spacing.dart';

class ReflectionCard extends StatelessWidget {
  const ReflectionCard({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.accentColor,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return AccentCard(
      accentColor: accentColor,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Brain dump (optional)',
                hintText:
                    'What happened today? What’s one small improvement for tomorrow?',
              ),
            ),
            Gap.h8,
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                child: const Text('Done'),
              ),
            ),
            Text(
              'Auto-saves when you leave the field.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
