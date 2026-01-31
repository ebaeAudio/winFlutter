import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// A themed [Card] with a subtle colored accent stripe on the left.
///
/// Designed to help users visually distinguish sections while scrolling.
/// Use sparingly — prefer plain layout for most content.
///
/// Design system: Uses `kRadiusMedium` (12px) for container corners.
class AccentCard extends StatelessWidget {
  const AccentCard({
    super.key,
    required this.accentColor,
    required this.child,
    this.accentWidth = 4,
  });

  final Color accentColor;
  final Widget child;
  final double accentWidth;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(kRadiusMedium);

    return Card(
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // Non-positioned child determines Stack's intrinsic size
            child,
            // Accent stripe stretches to match the child's height
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: accentWidth,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.only(
                    topLeft: radius.topLeft,
                    bottomLeft: radius.bottomLeft,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

