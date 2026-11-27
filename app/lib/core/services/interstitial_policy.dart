import 'package:flutter/foundation.dart';
import 'package:statussozo/core/app_config.dart';

/// The actions that count toward the next full-screen ad. Each counts once,
/// whatever its size: a batch of ten saves is one action.
enum AdAction {
  /// The viewer was closed (from Home or from Saved).
  viewerClosed,

  /// Saved was left for Home.
  savedClosed,

  /// Settings was left for Home.
  settingsClosed,

  /// Saved was opened from Home.
  openSaved,

  /// A save of one or more items finished on Home.
  saveFromHome,

  /// An item was saved in the viewer (photo or video).
  viewerSave,

  /// One item was shared from the viewer.
  shareOne,

  /// A selection was shared from Home.
  shareHome,

  /// A selection was shared from Saved.
  shareSaved,

  /// A selection was deleted from Saved.
  deleteSaved,

  /// An item was deleted in the Saved viewer.
  deleteViewer,

  /// A video played to its end.
  videoEnded,

  /// The temporary files were cleared in Settings.
  clearTemporaryFiles,

  /// The person swiped to another item in the viewer.
  viewerSwipe;

  /// Whether the ad may appear right after this action. Swiping counts toward
  /// the tally but never shows the ad in the middle of browsing.
  bool get mayShowAd => this != AdAction.viewerSwipe;
}

/// What is kept about full-screen ads, saved on the phone so a restart does
/// not wipe it.
@immutable
class InterstitialState {
  const InterstitialState({
    this.tally = 0,
    this.pending = false,
    this.lastShownMs,
  });

  /// Counted actions since the last ad. Stops at the target while pending.
  final int tally;

  /// The tally reached its target and an ad is waiting for its turn.
  final bool pending;

  /// When the last ad was shown, or null if none was.
  final int? lastShownMs;

  @override
  bool operator ==(Object other) =>
      other is InterstitialState &&
      other.tally == tally &&
      other.pending == pending &&
      other.lastShownMs == lastShownMs;

  @override
  int get hashCode => Object.hash(tally, pending, lastShownMs);
}

/// The outcome of counting one action.
@immutable
class AdDecision {
  const AdDecision({required this.state, required this.attempt});

  /// The state to keep.
  final InterstitialState state;

  /// An ad should be attempted for this action.
  final bool attempt;
}

/// The rules for full-screen ads. Pure logic, no SDK, no clock of its own.
///
/// One tally for the whole app. Every counted action adds one. At
/// [actionsPerAd] an ad becomes pending and the tally stops. The ad may show
/// on an action that [AdAction.mayShowAd], once [minGap] has passed since the
/// last ad, and not within [retryAfterFailure] of an attempt that showed
/// nothing. The tally resets only when an ad actually shows. There is no
/// daily limit. Never at launch, on return or exit, over a video, or before
/// consent: those are enforced by what raises actions and by the ad provider.
class InterstitialPolicy {
  const InterstitialPolicy({
    this.actionsPerAd = AppConfig.actionsPerInterstitial,
    this.minGap = AppConfig.interstitialMinGap,
    this.retryAfterFailure = AppConfig.interstitialRetryAfterFailure,
    this.hold = AppConfig.interstitialHold,
  });

  final int actionsPerAd;
  final Duration minGap;
  final Duration retryAfterFailure;

  /// The pause between the action and the ad.
  final Duration hold;

  /// True when [minGap] has passed since the last ad (or none was shown).
  bool gapPassed(InterstitialState state, int nowMs) {
    final int? last = state.lastShownMs;
    return last == null || nowMs - last >= minGap.inMilliseconds;
  }

  /// True when no attempt failed within [retryAfterFailure].
  bool retryAllowed(int? lastFailedMs, int nowMs) =>
      lastFailedMs == null ||
      nowMs - lastFailedMs >= retryAfterFailure.inMilliseconds;

  /// Counts [action] and says whether an ad should be attempted for it.
  AdDecision onAction(
    AdAction action,
    InterstitialState state, {
    required int nowMs,
    int? lastFailedMs,
  }) {
    InterstitialState next = state;
    if (!state.pending) {
      final int tally = state.tally + 1;
      next = InterstitialState(
        tally: tally,
        pending: tally >= actionsPerAd,
        lastShownMs: state.lastShownMs,
      );
    }
    final bool attempt =
        next.pending &&
        action.mayShowAd &&
        gapPassed(next, nowMs) &&
        retryAllowed(lastFailedMs, nowMs);
    return AdDecision(state: next, attempt: attempt);
  }

  /// The state after an ad was actually shown: the tally restarts and the gap
  /// starts again.
  InterstitialState shown(int nowMs) =>
      InterstitialState(lastShownMs: nowMs);
}

/// The local calendar day as yyyy-MM-dd.
String dayKey(DateTime time) {
  final String month = time.month.toString().padLeft(2, '0');
  final String day = time.day.toString().padLeft(2, '0');
  return '${time.year}-$month-$day';
}
