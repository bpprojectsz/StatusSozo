import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:statussozo/core/contracts/ad_service.dart';
import 'package:statussozo/core/contracts/consent_service.dart';

/// An ad service that never shows anything. Used in tests and wherever ads are
/// switched off, so the screens collapse their ad slots.
class DisabledAdService implements AdService {
  final ValueNotifier<bool> _ready = ValueNotifier<bool>(false);

  @override
  bool get initialised => false;

  @override
  Future<void> initialise() async {}

  @override
  BannerHandle createBanner(int widthDp) => _DisabledBanner();

  @override
  ValueListenable<bool> get interstitialReady => _ready;

  @override
  Future<void> loadInterstitial() async {}

  @override
  Future<bool> showInterstitial() async => false;
}

class _DisabledBanner implements BannerHandle {
  final ValueNotifier<AdState> _state = ValueNotifier<AdState>(
    AdState.disabled,
  );

  @override
  ValueListenable<AdState> get state => _state;

  @override
  Widget? get widget => null;

  @override
  double get height => 0;

  @override
  void dispose() => _state.dispose();
}

/// A consent service that never allows ads.
class DisabledConsentService implements ConsentService {
  static const ConsentOutcome _outcome = ConsentOutcome(
    canRequestAds: false,
    privacyOptionsRequired: false,
  );

  @override
  Future<ConsentOutcome> gather() async => _outcome;

  @override
  Future<ConsentOutcome> showPrivacyOptions() async => _outcome;
}
