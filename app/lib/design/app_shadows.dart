import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';

/// The single permitted shadow in the app: the floating selection bar.
abstract final class AppShadows {
  /// Light: black-ish at 14%, blur 24, offset (0, 8). Dark: none; a hairline
  /// border is used instead.
  static List<BoxShadow> floatingBar(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const <BoxShadow>[];
    }
    return const <BoxShadow>[
      BoxShadow(
        color: Color(0x240E0E14),
        blurRadius: 24,
        offset: Offset(0, 8),
      ),
    ];
  }
}
