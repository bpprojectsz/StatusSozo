import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/contracts/ad_service.dart';
import 'package:statussozo/utils/app_log.dart';

/// Ads through the Google Mobile Ads SDK. Nothing here throws: a failure is
/// logged and the ad simply does not appear.
class GoogleAdService implements AdService {
  bool _initialised = false;
  Future<void>? _initialising;
  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;
  final ValueNotifier<bool> _interstitialReady = ValueNotifier<bool>(false);

  @override
  bool get initialised => _initialised;

  @override
  Future<void> initialise() => _initialising ??= _initialise();

  Future<void> _initialise() async {
    try {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg),
      );
      await MobileAds.instance.initialize().timeout(AppConfig.adInitTimeout);
      _initialised = true;
    } on Object catch (error) {
      AppLog.warn('ads', 'The ad SDK did not start', error);
      _initialising = null;
    }
  }

  @override
  BannerHandle createBanner(int widthDp) {
    if (!_initialised) {
      return _GoogleBanner.failed();
    }
    return _GoogleBanner(widthDp);
  }

  @override
  ValueListenable<bool> get interstitialReady => _interstitialReady;

  @override
  Future<void> loadInterstitial() async {
    if (!_initialised || _interstitial != null || _loadingInterstitial) {
      return;
    }
    _loadingInterstitial = true;
    try {
      await InterstitialAd.load(
        adUnitId: AppConfig.interstitialUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            _interstitial = ad;
            _interstitialReady.value = true;
            _loadingInterstitial = false;
          },
          onAdFailedToLoad: (LoadAdError error) {
            AppLog.warn('ads', 'Interstitial failed to load: ${error.message}');
            _loadingInterstitial = false;
          },
        ),
      );
    } on Object catch (error) {
      AppLog.warn('ads', 'Interstitial load threw', error);
      _loadingInterstitial = false;
    }
  }

  @override
  Future<bool> showInterstitial() async {
    final InterstitialAd? ad = _interstitial;
    if (ad == null) {
      return false;
    }
    _interstitial = null;
    _interstitialReady.value = false;
    final Completer<bool> done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (InterstitialAd shown) {
        shown.dispose();
        if (!done.isCompleted) {
          done.complete(true);
        }
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd shown, AdError error) {
        AppLog.warn('ads', 'Interstitial failed to show: ${error.message}');
        shown.dispose();
        if (!done.isCompleted) {
          done.complete(false);
        }
      },
    );
    try {
      await ad.show();
    } on Object catch (error) {
      AppLog.warn('ads', 'Interstitial show threw', error);
      unawaited(ad.dispose());
      return false;
    }
    return done.future;
  }
}

/// One adaptive banner. A failed load is retried once after a delay; after that
/// it waits for the screen to ask again.
class _GoogleBanner implements BannerHandle {
  _GoogleBanner(this._widthDp) {
    unawaited(_load());
  }

  _GoogleBanner.failed() : _widthDp = 0 {
    _state.value = AdState.failed;
  }

  final int _widthDp;
  final ValueNotifier<AdState> _state = ValueNotifier<AdState>(AdState.loading);
  BannerAd? _ad;
  AdSize? _size;
  Timer? _retry;
  bool _retried = false;
  bool _disposed = false;

  @override
  ValueListenable<AdState> get state => _state;

  @override
  Widget? get widget {
    final BannerAd? ad = _ad;
    final AdSize? size = _size;
    if (_state.value != AdState.ready || ad == null || size == null) {
      return null;
    }
    return SizedBox(
      width: size.width.toDouble(),
      height: size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }

  @override
  double get height =>
      _state.value == AdState.ready ? (_size?.height ?? 0).toDouble() : 0;

  Future<void> _load() async {
    if (_disposed || _widthDp <= 0) {
      return;
    }
    try {
      final AdSize size =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
            _widthDp,
          ) ??
          AdSize.banner;
      if (_disposed) {
        return;
      }
      _size = size;
      final BannerAd ad = BannerAd(
        adUnitId: AppConfig.bannerUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (Ad loaded) {
            if (_disposed) {
              loaded.dispose();
              return;
            }
            _state.value = AdState.ready;
          },
          onAdFailedToLoad: (Ad failed, LoadAdError error) {
            failed.dispose();
            _ad = null;
            _fail('Banner failed to load: ${error.message}');
          },
        ),
      );
      _ad = ad;
      await ad.load();
    } on Object catch (error) {
      _fail('Banner threw: $error');
    }
  }

  void _fail(String message) {
    AppLog.warn('ads', message);
    if (_disposed) {
      return;
    }
    _state.value = AdState.failed;
    if (!_retried) {
      _retried = true;
      _retry = Timer(AppConfig.adRetryDelay, () {
        if (_disposed) {
          return;
        }
        _state.value = AdState.loading;
        unawaited(_load());
      });
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _retry?.cancel();
    _ad?.dispose();
    _ad = null;
    _state.dispose();
  }
}
