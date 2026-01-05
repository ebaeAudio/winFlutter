import 'package:flutter/material.dart';

import '../spacing.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding,
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: padding ??
          const EdgeInsets.only(top: AppSpace.s8, bottom: AppSpace.s8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
