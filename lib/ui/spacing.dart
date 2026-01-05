import 'package:flutter/widgets.dart';

/// App spacing scale.
///
/// Keep screen/layout padding aligned to these values to maintain a consistent
/// rhythm across the app.
class AppSpace {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
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

  static const w8 = Gap._(width: AppSpace.s8, height: 0);
  static const w12 = Gap._(width: AppSpace.s12, height: 0);
  static const w16 = Gap._(width: AppSpace.s16, height: 0);

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, height: height);
}
