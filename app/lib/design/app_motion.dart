import 'package:flutter/widgets.dart';

/// Durations and curves. There are no spring or bounce curves in this app.
abstract final class AppMotion {
  static const Duration push = Duration(milliseconds: 350);
  static const Duration pop = Duration(milliseconds: 280);
  static const Duration sheet = Duration(milliseconds: 400);
  static const Duration press = Duration(milliseconds: 150);
  static const Duration toast = Duration(milliseconds: 300);
  static const Duration theme = Duration(milliseconds: 200);
  static const Duration tab = Duration(milliseconds: 200);
  static const Duration viewerControls = Duration(milliseconds: 200);

  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOut = Curves.easeOut;
  static const Curve linear = Curves.linear;

  /// Every curve this app may use. Guarded by a test.
  static const List<Curve> allCurves = <Curve>[easeInOut, easeOut, linear];

  /// True when the system asks for reduced motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// [duration], or zero when motion is reduced.
  static Duration resolve(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
