/// Every constant that is not a design token.
abstract final class AppConfig {
  // Identity.
  static const String appName = 'StatusSozo';

  /// The wordmark is drawn in two colours: [wordmarkHead] in the text colour
  /// and [wordmarkTail] in the accent. Together they spell [appName].
  static const String wordmarkHead = 'Status';
  static const String wordmarkTail = 'Sozo';
  static const String applicationId = 'com.zdmgold.statussozo';

  // Contact and web.
  static const String supportEmail = 'stmakarios@gmail.com';
  static const String websiteBaseUrl = 'https://statussozo.bpprojectsz.workers.dev';
  static const String privacyUrl = '$websiteBaseUrl/privacy';
  static const String supportUrl = '$websiteBaseUrl/support';
  static const String termsUrl = '$websiteBaseUrl/terms';
  static const String storeListingUrl =
      'https://play.google.com/store/apps/details?id=$applicationId';

  // Folders.
  /// Name the picked folder must have; anything else is rejected.
  static const String statusFolderName = '.Statuses';

  /// Folder created under Pictures and Movies for saved items.
  static const String saveSubfolder = 'StatusSozo';

  // Performance and limits.
  static const int thumbnailConcurrency = 3;
  static const int thumbnailCacheEntries = 200;
  static const int imageMaxBytes = 25 * 1024 * 1024;
  static const Duration shareCacheTtl = Duration(hours: 24);
  static const Duration toastDuration = Duration(seconds: 3);

  // Ads. The defaults are Google's published test IDs. Live IDs are compiled in
  // only by an explicit release build (the live_ads workflow input).
  static const String bannerUnitId = String.fromEnvironment(
    'ADMOB_BANNER_ID',
    defaultValue: 'ca-app-pub-3940256099942544/9214589741',
  );
  static const String interstitialUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );

  /// Forces Google's consent form to behave as in the EEA, for testing.
  static const bool consentDebugEea = bool.fromEnvironment('CONSENT_DEBUG_EEA');

  /// How long to wait for the ad SDK and the consent update before moving on.
  static const Duration adInitTimeout = Duration(seconds: 5);

  /// A failed banner is retried once after this long.
  static const Duration adRetryDelay = Duration(seconds: 60);

  // Interstitial rules.
  static const Duration interstitialMinGap = Duration(minutes: 3);
  static const int interstitialDailyMax = 6;
  static const int viewerClosesPerInterstitial = 5;
  static const int batchSaveMinItems = 2;

  /// How often Home silently re-reads the status folder while it is showing.
  static const Duration autoRefreshInterval = Duration(seconds: 4);

  /// Overscroll, in logical pixels, that a pull-down needs to start a refresh.
  static const double pullToRefreshDistance = 72;

  /// The pull-down indicator stays at least this long, so it is seen.
  static const Duration pullIndicatorMinimum = Duration(seconds: 1);

  // Persistence.
  static const int settingsSchemaVersion = 1;
  static const String settingsPrefsKey = 'sozo.settings';
}
