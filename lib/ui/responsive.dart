import 'package:flutter/widgets.dart';

class AppBreakpoints {
  /// Wide enough that we can lay out sections side-by-side.
  static const double desktop = 840;
}

bool isDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;

bool isMobile(BuildContext context) => !isDesktop(context);

