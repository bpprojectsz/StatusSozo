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
    required SettingsProvider settings,
    required InterstitialPolicy policy,
    DateTime Function()? now,
  }) : _ads = ads,
       _consent = consent,
       _settings = settings,
       _policy = policy,
       _now = now ?? DateTime.now,
       super(const AdProviderState(phase: AdsPhase.idle)) {
    addListener(_syncEnabled);
  }

  final AdService _ads;
  final ConsentService _consent;
  final SettingsProvider _settings;
  final InterstitialPolicy _policy;
  final DateTime Function() _now;

  bool _starting = false;
  bool _showing = false;

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

  /// Shows an interstitial if the rules allow it. Returns whether one was
  /// shown. Never throws.
  Future<bool> maybeShowInterstitial(
    InterstitialTrigger trigger, {
    int items = 0,
  }) async {
    if (!enabled || _showing) {
      return false;
    }
    final String today = dayKey(_now());
    final AppSettings s = _settings.settings;
    final int shownToday = s.interstitialDay == today ? s.interstitialsToday : 0;
    if (!_policy.allows(trigger, items: items, shownToday: shownToday)) {
      return false;
    }
    if (!_ads.interstitialReady.value) {
      unawaited(_ads.loadInterstitial());
      return false;
    }
    _showing = true;
    try {
      final bool shown = await _ads.showInterstitial();
      if (shown) {
        _policy.markShown();
        await _settings.update(
          (AppSettings current) => current.copyWith(
            interstitialDay: today,
            interstitialsToday:
                (current.interstitialDay == today
                    ? current.interstitialsToday
                    : 0) +
                1,
          ),
        );
      }
      return shown;
    } finally {
      _showing = false;
      unawaited(_ads.loadInterstitial());
    }
  }
}
