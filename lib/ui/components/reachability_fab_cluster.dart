import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../spacing.dart';

enum ReachabilityFabSide { start, end }

@immutable
class ReachabilityFabAction {
  const ReachabilityFabAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isPrimary = false,
    this.label,
    this.semanticLabel,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Primary action is rendered as an extended FAB (icon + label).
  final bool isPrimary;

  /// Required when [isPrimary] is true.
  final String? label;

  final String? semanticLabel;
}

/// A small “thumb zone” cluster of FABs that sits above the bottom nav bar.
///
/// Use this on detail/editor screens so key actions are reachable on large
/// phones without hand gymnastics.
class ReachabilityFabCluster extends StatelessWidget {
  const ReachabilityFabCluster({
    super.key,
    required this.actions,
    this.bottomBarHeight = 0,
    this.side = ReachabilityFabSide.end,
  });

  /// Include exactly 0–1 primary action; any remaining actions become small FABs.
  final List<ReachabilityFabAction> actions;

  /// Height of an always-visible bottom bar owned by a parent scaffold
  /// (ex: `NavShell`’s `NavigationBar`).
  final double bottomBarHeight;

  final ReachabilityFabSide side;

  @override
  Widget build(BuildContext context) {
    final primary = actions.where((a) => a.isPrimary).toList(growable: false);
    final secondary =
        actions.where((a) => !a.isPrimary).toList(growable: false);

    assert(primary.length <= 1, 'Only one primary ReachabilityFabAction allowed');
    assert(
      primary.isEmpty || (primary.first.label?.trim().isNotEmpty == true),
      'Primary ReachabilityFabAction must have a non-empty label',
    );

    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    // When the keyboard is up, we want this cluster to sit just above the
    // keyboard; the bottom nav bar is effectively irrelevant then.
    final bottomOffset = viewInsetsBottom > 0 ? 0.0 : bottomBarHeight;

    final alignment = switch (side) {
      ReachabilityFabSide.start => Alignment.bottomLeft,
      ReachabilityFabSide.end => Alignment.bottomRight,
    };

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpace.s16,
          right: AppSpace.s16,
          bottom: AppSpace.s16 + bottomOffset,
        ),
        child: Align(
          alignment: alignment,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: switch (side) {
              ReachabilityFabSide.start => CrossAxisAlignment.start,
              ReachabilityFabSide.end => CrossAxisAlignment.end,
            },
            children: [
              for (final a in secondary) ...[
                _SmallFab(action: a),
                Gap.h12,
              ],
              if (primary.isNotEmpty) _PrimaryFab(action: primary.first),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryFab extends StatelessWidget {
  const _PrimaryFab({required this.action});

  final ReachabilityFabAction action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: action.semanticLabel ?? action.tooltip,
      child: FloatingActionButton.extended(
        onPressed: action.onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                action.onPressed?.call();
              },
        icon: Icon(action.icon),
        label: Text(action.label ?? ''),
        tooltip: action.tooltip,
      ),
    );
  }
}

class _SmallFab extends StatelessWidget {
  const _SmallFab({required this.action});

  final ReachabilityFabAction action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: action.semanticLabel ?? action.tooltip,
      child: FloatingActionButton.small(
        heroTag: null, // allow multiple on the same route
        onPressed: action.onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                action.onPressed?.call();
              },
        tooltip: action.tooltip,
        child: Icon(action.icon),
      ),
    );
  }
}

