import 'package:flutter/material.dart';

import '../spacing.dart';

enum Corner {
  bottomLeft,
  bottomRight,
}

class CornerNavBubbleDestination {
  const CornerNavBubbleDestination({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class CornerNavBubbleBar extends StatelessWidget {
  const CornerNavBubbleBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.corner,
  });

  final List<CornerNavBubbleDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Corner corner;

  BorderRadius _borderRadius() {
    // Emphasize the screen-corner curve so it feels like a “bubble” hugging the
    // corner. The opposite corner is tighter so it reads as “anchored”.
    const inner = Radius.circular(AppSpace.s24);
    const outer = Radius.circular(AppSpace.s48);

    return switch (corner) {
      Corner.bottomLeft => const BorderRadius.only(
          topLeft: inner,
          topRight: inner,
          bottomRight: inner,
          bottomLeft: outer,
        ),
      Corner.bottomRight => const BorderRadius.only(
          topLeft: inner,
          topRight: inner,
          bottomLeft: inner,
          bottomRight: outer,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final destinations = this.destinations;

    // 2 columns x 3 rows (last cell unused when we have 5 destinations).
    // Sized to ensure >=44px touch targets and avoid layout thrash.
    const cell = 48.0;
    const gridSpacing = AppSpace.s8;
    const padding = AppSpace.s12;
    const columns = 2;
    const rows = 3;
    const width = padding * 2 + columns * cell + (columns - 1) * gridSpacing;
    const height = padding * 2 + rows * cell + (rows - 1) * gridSpacing;

    return Material(
      elevation: 8,
      color: scheme.surface,
      shadowColor: scheme.shadow.withOpacity(0.28),
      shape: RoundedRectangleBorder(
        borderRadius: _borderRadius(),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: height,
        child: Padding(
          padding: const EdgeInsets.all(padding),
          child: GridView.count(
            crossAxisCount: columns,
            mainAxisSpacing: gridSpacing,
            crossAxisSpacing: gridSpacing,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              for (var i = 0; i < columns * rows; i++)
                if (i < destinations.length)
                  _CornerNavIconButton(
                    icon: destinations[i].icon,
                    label: destinations[i].label,
                    selected: i == selectedIndex,
                    onPressed: () => onSelected(i),
                  )
                else
                  const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}

class _CornerNavIconButton extends StatelessWidget {
  const _CornerNavIconButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bg =
        selected ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpace.s16),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppSpace.s16),
            child: Center(
              child: Icon(icon, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
