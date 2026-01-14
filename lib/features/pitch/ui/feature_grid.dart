import 'package:flutter/material.dart';

import '../../../app/analytics/track.dart';
import '../../../ui/spacing.dart';
import '../pitch_content.dart';

class FeatureGrid extends StatelessWidget {
  const FeatureGrid({
    super.key,
    required this.content,
    required this.analyticsEvent,
  });

  final PitchFeatureGridContent content;
  final String analyticsEvent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final crossAxisCount = w >= 720
            ? 3
            : w >= 480
                ? 2
                : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpace.s12,
            mainAxisSpacing: AppSpace.s12,
            childAspectRatio: crossAxisCount == 1 ? 3.4 : 1.35,
          ),
          itemCount: content.features.length,
          itemBuilder: (context, idx) {
            final f = content.features[idx];
            return _FeatureCard(
              feature: f,
              onTap: () => track(
                analyticsEvent,
                {'kind': 'feature_tapped', 'id': f.id, 'index': idx},
              ),
            );
          },
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature, required this.onTap});

  final PitchFeature feature;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: feature.title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(feature.icon, color: scheme.primary),
                Gap.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Gap.h8,
                      Text(
                        feature.body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

