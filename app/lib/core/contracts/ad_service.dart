import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Where one banner is in its life.
enum AdState { disabled, loading, ready, failed }

/// One banner on one screen. The screen owns it and calls [dispose] when it
/// goes away or is covered by another screen.
abstract interface class BannerHandle {
  ValueListenable<AdState> get state;

  /// The ad to draw, or null until it is ready.
  Widget? get widget;

  /// Height the ad needs, or zero until it is ready.
  double get height;

  void dispose();
}

/// Port for ads. **No method may throw.** Every failure is logged locally and
/// leaves the app working without that ad.
abstract interface class AdService {
  /// Whether the SDK started. Ads are never requested before consent.
  bool get initialised;

  /// Starts the SDK. Safe to call more than once.
  Future<void> initialise();

  /// Starts loading a banner of the given width in logical pixels.
  BannerHandle createBanner(int widthDp);

  /// True while an interstitial is loaded and can be shown.
  ValueListenable<bool> get interstitialReady;

  /// Starts loading the next interstitial if none is loaded.
  Future<void> loadInterstitial();

  /// Shows the loaded interstitial. Completes when it is dismissed. False if
  /// nothing was shown.
  Future<bool> showInterstitial();
}
