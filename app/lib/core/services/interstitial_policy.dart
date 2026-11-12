import 'package:statussozo/core/app_config.dart';

/// The moments at which an interstitial may be considered.
enum InterstitialTrigger {
  /// A save of two or more items finished on Home.
  batchSave,

  /// A single photo was saved in the viewer.
  viewerSave,

  /// Items were deleted from the Saved screen.
  savedDelete,

  /// A photo was deleted in the Saved viewer and another photo is showing.
  viewerDelete,

  /// The viewer was closed. Only every Nth close qualifies.
  viewerClose,
}

/// The rules for when an interstitial may appear. Pure logic, no SDK.
///
/// Never: at launch, on exit, during video playback or before consent. Those
/// are enforced by where the triggers are raised and by the ad provider. This
/// class enforces the counts and the spacing. There is no daily limit.
class InterstitialPolicy {
  InterstitialPolicy({
    required this.nowMs,
    this.minGap = AppConfig.interstitialMinGap,
    this.viewerClosesPerAd = AppConfig.viewerClosesPerInterstitial,
    this.batchSaveMinItems = AppConfig.batchSaveMinItems,
  });

  final int Function() nowMs;
  final Duration minGap;
  final int viewerClosesPerAd;
  final int batchSaveMinItems;

  int? _lastShownMs;
  int _viewerCloses = 0;

  /// Whether an interstitial may be shown now for [trigger].
  ///
  /// [items] is how many items the action touched. A viewer close is counted
  /// even when the spacing blocks it, so the next close can qualify.
  bool allows(InterstitialTrigger trigger, {int items = 0}) {
    final bool qualifies = switch (trigger) {
      InterstitialTrigger.batchSave => items >= batchSaveMinItems,
      InterstitialTrigger.viewerSave ||
      InterstitialTrigger.savedDelete ||
      InterstitialTrigger.viewerDelete => items >= 1,
      InterstitialTrigger.viewerClose => (++_viewerCloses) >= viewerClosesPerAd,
    };
    if (!qualifies) {
      return false;
    }
    final int? last = _lastShownMs;
    if (last != null && nowMs() - last < minGap.inMilliseconds) {
      return false;
    }
    return true;
  }

  /// Records that an interstitial was actually shown.
  void markShown() {
    _lastShownMs = nowMs();
    _viewerCloses = 0;
  }
}

/// The local calendar day as yyyy-MM-dd, used for the daily count.
String dayKey(DateTime time) {
  final String month = time.month.toString().padLeft(2, '0');
  final String day = time.day.toString().padLeft(2, '0');
  return '${time.year}-$month-$day';
}
