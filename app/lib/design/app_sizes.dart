/// Fixed dimensions shared across the app.
abstract final class AppSizes {
  // Touch and chrome.
  static const double touchTarget = 48;
  static const double navBar = 56;
  static const double iconChip = 40;
  static const double buttonHeight = 52;
  static const double segmentHeight = 40;
  static const double hairline = 0.5;
  static const double heroIconChip = 56;
  static const double emptyStateCircle = 72;

  // Icons.
  static const double iconNav = 22;
  static const double iconRowLeading = 22;
  static const double iconRowTrailing = 18;
  static const double iconChipGlyph = 18;
  static const double iconHero = 40;
  static const double iconBadge = 14;

  /// Stroke width applied to every icon so weight matches adjacent text.
  static const double iconStroke = 2;

  // Grid.
  static const double gridMaxTileExtent = 140;
  static const int thumbnailRequestPx = 256;
  static const double selectionBadge = 24;
  static const double selectionRing = 2;

  // Viewer.
  static const double playCircle = 64;
  static const double scrubTrack = 4;
  static const double scrubTrackActive = 6;
  static const double scrubThumb = 14;

  // Ad slot (Stage 2).
  static const double adSlotMaxHeight = 90;
  static const double adSlotGapAbove = 8;
}
