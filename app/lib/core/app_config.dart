/// Every constant that is not a design token.
abstract final class AppConfig {
  // Identity.
  static const String appName = 'StatusSozo';
  static const String applicationId = 'com.zdmgold.statussozo';

  // Contact and web.
  static const String supportEmail = 'stmakarios@gmail.com';
  static const String websiteBaseUrl = 'https://statussozo.bpprojectsz.workers.dev';
  static const String privacyUrl = '$websiteBaseUrl/privacy';
  static const String supportUrl = '$websiteBaseUrl/support';
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

  // Persistence.
  static const int settingsSchemaVersion = 1;
  static const String settingsPrefsKey = 'sozo.settings';
}
