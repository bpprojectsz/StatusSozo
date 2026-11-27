import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:statussozo/core/contracts/ad_service.dart';
import 'package:statussozo/core/contracts/consent_service.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/providers/settings_provider.dart';
import 'package:statussozo/core/services/interstitial_policy.dart';

/// Where ads stand for the whole app.
enum AdsPhase {
  /// Nothing has started yet.
  idle,

  /// The consent step is running.
  gathering,

  /// Consent allows ads and the SDK is running.
  ready,

  /// Ads are off: consent was not given, or the SDK did not start.
  disabled,
}

@immutable
class AdProviderState {
  const AdProviderState({required this.phase, this.privacyOptionsRequired = false});

  final AdsPhase phase;

  /// The Privacy choices row must be shown (EEA and UK).
  final bool privacyOptionsRequired;

  @override
  bool operator ==(Object other) =>
      other is AdProviderState &&
      other.phase == phase &&
      other.privacyOptionsRequired == privacyOptionsRequired;

  @override
  int get hashCode => Object.hash(phase, privacyOptionsRequired);
}

/// Orchestrates consent, the ad SDK and the interstitial rules.
///
/// Ads are never requested before consent. Every ad failure leaves the app
/// working with that ad collapsed.
class AdProvider extends ValueNotifier<AdProviderState> {
  AdProvider({
    required AdService ads,
    required ConsentService consent,
    required InterstitialPolicy policy,
    required SettingsProvider settings,
    DateTime Function()? now,
    Future<void> Function(Duration pause)? delay,
  }) : _ads = ads,
       _consent = consent,
       _policy = policy,
       _settings = settings,
       _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed,
       super(const AdProviderState(phase: AdsPhase.idle)) {
    addListener(_syncEnabled);
  }

  final AdService _ads;
  final ConsentService _consent;
  final InterstitialPolicy _policy;
  final SettingsProvider _settings;
  final DateTime Function() _now;
  final Future<void> Function(Duration pause) _delay;

  bool _starting = false;
  bool _showing = false;

  /// The last consent step failed and has not been retried yet.
  bool _retryPending = false;

  /// The one retry of this launch has been used; a second failure does not
  /// schedule another, so a broken consent step can never loop.
  bool _retryUsed = false;
  DateTime? _lastInterstitialAt;

  bool _foreground = true;
  bool _attemptScheduled = false;
  int? _lastFailedMs;

  /// Checks that must all say yes at the moment an ad would appear: no video
  /// in progress, no sheet or dialog open, no review request just made. If one
  /// says no, the ad stays pending and waits for the next action.
  final List<bool Function()> interruptionGuards = <bool Function()>[];

  /// The app is in front of the person (not in the background, not covered by
  /// another app such as the share sheet).
  void setForeground({required bool foreground}) {
    _foreground = foreground;
  }

  /// An interstitial is on screen right now.
  bool get showingInterstitial => _showing;

  /// When the last interstitial was shown, or null.
  DateTime? get lastInterstitialAt => _lastInterstitialAt;

  /// True while banners and interstitials may be requested. Screens bind their
  /// ad slots to this.
  final ValueNotifier<bool> isEnabled = ValueNotifier<bool>(false);

  void _syncEnabled() {
    isEnabled.value = enabled;
  }

  @override
  void dispose() {
    removeListener(_syncEnabled);
    isEnabled.dispose();
    super.dispose();
  }

  /// The ad service, for screens that create banners.
  AdService get service => _ads;

  /// Whether banners and interstitials may be requested.
  bool get enabled => value.phase == AdsPhase.ready;

  /// Runs the consent step and, when allowed, starts the SDK. Call after the
  /// first frame, never before.
  Future<void> start() async {
    if (_starting) {
      return;
    }
    _starting = true;
    try {
      if (value.phase == AdsPhase.idle) {
        value = const AdProviderState(phase: AdsPhase.gathering);
      }
      await _apply(await _consent.gather());
    } finally {
      _starting = false;
    }
  }

  Future<void> _apply(ConsentOutcome outcome) async {
    if (outcome.needsRetry && !_retryUsed) {
      _retryPending = true;
    }
    if (!outcome.canRequestAds) {
      value = AdProviderState(
        phase: AdsPhase.disabled,
        privacyOptionsRequired: outcome.privacyOptionsRequired,
      );
      return;
    }
    await _ads.initialise();
    if (!_ads.initialised) {
      value = AdProviderState(
        phase: AdsPhase.disabled,
        privacyOptionsRequired: outcome.privacyOptionsRequired,
      );
      return;
    }
    value = AdProviderState(
      phase: AdsPhase.ready,
      privacyOptionsRequired: outcome.privacyOptionsRequired,
    );
    unawaited(_ads.loadInterstitial());
  }

  /// The app came back to the foreground: top up the interstitial, or look at
  /// consent again if ads were off.
  Future<void> onResumed() async {
    if (_retryPending && !_starting) {
      // The consent step failed earlier: run it once more, once. Ads keep
      // running meanwhile.
      _retryPending = false;
      _retryUsed = true;
      _starting = true;
      try {
        await _apply(await _consent.gather());
      } finally {
        _starting = false;
      }
      return;
    }
    if (value.phase == AdsPhase.ready) {
      unawaited(_ads.loadInterstitial());
    } else if (value.phase == AdsPhase.disabled) {
      await start();
    }
  }

  /// Reopens Google's privacy choices form and applies the result.
  Future<void> showPrivacyOptions() async {
    await _apply(await _consent.showPrivacyOptions());
  }

  InterstitialState get _state => InterstitialState(
    tally: _settings.settings.adTally,
    pending: _settings.settings.adPending,
    lastShownMs: _settings.settings.adLastShownMs,
  );

  Future<void> _save(InterstitialState next) => _settings.update(
    (AppSettings s) => s.copyWith(
      adTally: next.tally,
      adPending: next.pending,
      // A reset to "never shown" cannot happen, so a null never overwrites.
      adLastShownMs: next.lastShownMs,
    ),
  );

  /// Counts one action toward the next full-screen ad. After the target the ad
  /// is pending; it shows a short pause after the first action that may show
  /// it, once the gap since the last ad has passed. Never throws, and does
  /// nothing while ads are off.
  Future<void> onAction(AdAction action) async {
    if (!enabled) {
      return;
    }
    final int nowMs = _now().millisecondsSinceEpoch;
    final InterstitialState before = _state;
    final AdDecision decision = _policy.onAction(
      action,
      before,
      nowMs: nowMs,
      lastFailedMs: _lastFailedMs,
    );
    if (decision.state != before) {
      await _save(decision.state);
    }
    if (decision.attempt) {
      _scheduleAttempt();
    }
  }

  void _scheduleAttempt() {
    if (_attemptScheduled) {
      return;
    }
    _attemptScheduled = true;
    unawaited(
      _delay(_policy.hold).then((void _) async {
        _attemptScheduled = false;
        await _attempt();
      }),
    );
  }

  /// Everything is checked again after the pause, because the person may have
  /// moved on (started a video, opened a sheet, left the app).
  Future<void> _attempt() async {
    if (!enabled || _showing || !_foreground) {
      return;
    }
    final int nowMs = _now().millisecondsSinceEpoch;
    final InterstitialState state = _state;
    if (!state.pending || !_policy.gapPassed(state, nowMs)) {
      return;
    }
    for (final bool Function() guard in interruptionGuards) {
      if (!guard()) {
        return;
      }
    }
    if (!_ads.interstitialReady.value) {
      // Nothing to show yet: load one, and do not try again for a minute.
      _lastFailedMs = nowMs;
      unawaited(_ads.loadInterstitial());
      return;
    }
    _showing = true;
    try {
      final bool shown = await _ads.showInterstitial();
      if (shown) {
        _lastFailedMs = null;
        _lastInterstitialAt = _now();
        await _save(_policy.shown(_now().millisecondsSinceEpoch));
      } else {
        _lastFailedMs = _now().millisecondsSinceEpoch;
      }
    } on Object {
      _lastFailedMs = _now().millisecondsSinceEpoch;
    } finally {
      _showing = false;
      unawaited(_ads.loadInterstitial());
    }
  }
}
