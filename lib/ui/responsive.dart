import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppBreakpoints {
  /// Wide enough that we can lay out sections side-by-side.
  static const double desktop = 840;
}

/// Returns true if the screen width is >= desktop breakpoint.
bool isDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;

/// Returns true if the screen width is < desktop breakpoint.
bool isMobile(BuildContext context) => !isDesktop(context);

/// Returns true if running on macOS (not web).
bool get isMacOS =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

/// Returns true if running on a desktop OS (macOS, Windows, Linux).
bool get isDesktopOS =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

/// Returns true if running on iOS or Android.
bool get isMobileOS =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

/// Returns true if the platform supports keyboard shortcuts (desktop or web).
bool get supportsKeyboardShortcuts => isDesktopOS || kIsWeb;

