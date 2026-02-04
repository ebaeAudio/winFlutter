import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/user_settings.dart';
import 'spacing.dart';

/// Standard page wrapper:
/// - consistent padding
/// - safe area
/// - centered content with max width on larger screens
class AppScaffold extends ConsumerWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.children,
    this.body,
    this.actions,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.maxWidth = 720,
  });

  final String title;
  final List<Widget> children;
  final Widget? body;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsControllerProvider);
    final oneHandEnabled = settings.oneHandModeEnabled;
    final hand = settings.oneHandModeHand;

    // Screen padding using the design system scale.
    const baseVerticalPadding = AppSpace.s16;
    final baseHorizontalPadding =
        settings.disableHorizontalScreenPadding ? AppSpace.s8 : AppSpace.s16;
    // One-hand mode gutter: combine s24 + s24 for a meaningful gutter width
    const preferredGutter = AppSpace.s24 + AppSpace.s24;

    final extraLeft =
        oneHandEnabled && hand == OneHandModeHand.right ? preferredGutter : 0.0;
    final extraRight =
        oneHandEnabled && hand == OneHandModeHand.left ? preferredGutter : 0.0;

    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final gutterColor = scheme.surfaceContainerHighest
        .withOpacity(brightness == Brightness.dark ? 0.18 : 0.55);
    final dividerColor = scheme.outlineVariant
        .withOpacity(brightness == Brightness.dark ? 0.45 : 0.75);

    final builtBody = body != null
        ? Padding(
            padding: EdgeInsets.only(left: extraLeft, right: extraRight),
            child: body,
          )
        : ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              left: baseHorizontalPadding + extraLeft,
              right: baseHorizontalPadding + extraRight,
              top: baseVerticalPadding,
              bottom: baseVerticalPadding,
            ),
            children: children,
          );

    final tapToDismiss = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: builtBody,
    );

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: oneHandEnabled
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final maxGutter = math.max(0.0,
                          constraints.maxWidth - baseHorizontalPadding * 2,);
                      final gutterWidth = math.min(preferredGutter, maxGutter);
                      final opposingSideIsRight = hand == OneHandModeHand.left;

                      return Stack(
                        children: [
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: opposingSideIsRight ? null : 0,
                            right: opposingSideIsRight ? 0 : null,
                            width: gutterWidth,
                            child: ColoredBox(color: gutterColor),
                          ),
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: opposingSideIsRight ? null : gutterWidth,
                            right: opposingSideIsRight ? gutterWidth : null,
                            width: 1,
                            child: ColoredBox(color: dividerColor),
                          ),
                          tapToDismiss,
                        ],
                      );
                    },
                  )
                : tapToDismiss,
          ),
        ),
      ),
    );
  }
}
