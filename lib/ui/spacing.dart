import 'package:flutter/widgets.dart';

/// App spacing scale — strict 4/8/12/16/24 only.
///
/// See `design_system.dart` for full documentation.
///
/// Usage:
/// - `s4`: Inline spacing (icon-to-text, tight groups)
/// - `s8`: Default compact spacing (list item padding, between related items)
/// - `s12`: Medium spacing (section content padding, form field gaps)
/// - `s16`: Standard spacing (screen padding, card padding, section gaps)
/// - `s24`: Large spacing (between major sections)
///
/// DO NOT add new values. If you need something larger, reconsider the
/// hierarchy or combine values (e.g., s16 + s24 section with internal s12).
class AppSpace {
  AppSpace._();

  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;

  /// Screen edge padding (use s16 for standard screens).
  static const double screenPadding = s16;

  /// @Deprecated('Use s24 or combine smaller values')
  /// Legacy value for gradual migration. Remove uses over time.
  static const double s32 = 32;

  /// @Deprecated('Use s24 or combine smaller values')
  /// Legacy value for gradual migration. Remove uses over time.
  static const double s48 = 48;
}

/// Small reusable gaps to avoid sprinkling raw `SizedBox(height: x)` everywhere.
class Gap extends StatelessWidget {
  const Gap._({super.key, required this.width, required this.height});

  const Gap.h(double h, {Key? key}) : this._(key: key, width: 0, height: h);
  const Gap.w(double w, {Key? key}) : this._(key: key, width: w, height: 0);

  static const h4 = Gap._(width: 0, height: AppSpace.s4);
  static const h8 = Gap._(width: 0, height: AppSpace.s8);
  static const h12 = Gap._(width: 0, height: AppSpace.s12);
  static const h16 = Gap._(width: 0, height: AppSpace.s16);
  static const h24 = Gap._(width: 0, height: AppSpace.s24);

  static const w4 = Gap._(width: AppSpace.s4, height: 0);
  static const w8 = Gap._(width: AppSpace.s8, height: 0);
  static const w12 = Gap._(width: AppSpace.s12, height: 0);
  static const w16 = Gap._(width: AppSpace.s16, height: 0);
  static const w24 = Gap._(width: AppSpace.s24, height: 0);

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, height: height);
}
