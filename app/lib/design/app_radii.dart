import 'package:flutter/painting.dart';

/// Corner radii, as doubles and as ready-made [BorderRadius] values.
abstract final class AppRadii {
  static const double card = 16;
  static const double hero = 24;
  static const double button = 12;
  static const double iconChip = 12;
  static const double thumb = 12;
  static const double sheetTop = 20;
  static const double dialog = 16;
  static const double pill = 999;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius heroRadius = BorderRadius.all(Radius.circular(hero));
  static const BorderRadius buttonRadius =
      BorderRadius.all(Radius.circular(button));
  static const BorderRadius iconChipRadius =
      BorderRadius.all(Radius.circular(iconChip));
  static const BorderRadius thumbRadius =
      BorderRadius.all(Radius.circular(thumb));
  static const BorderRadius dialogRadius =
      BorderRadius.all(Radius.circular(dialog));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(pill));

  /// Top corners only, for bottom sheets.
  static const BorderRadius sheetTopRadius = BorderRadius.only(
    topLeft: Radius.circular(sheetTop),
    topRight: Radius.circular(sheetTop),
  );
}
