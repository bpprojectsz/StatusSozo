import 'package:statussozo/core/app_config.dart';

/// The two supported sources. All path knowledge lives only in this file, so a
/// change by the service provider is a one-file patch.
enum StatusSource {
  standard(
    id: 'standard',
    packageName: 'com.whatsapp',
    mediaRoot: 'WhatsApp',
  ),
  business(
    id: 'business',
    packageName: 'com.whatsapp.w4b',
    mediaRoot: 'WhatsApp Business',
  );

  const StatusSource({
    required this.id,
    required this.packageName,
    required this.mediaRoot,
  });

  /// Stable identifier used in persisted settings.
  final String id;

  /// Android package that owns the status folder.
  final String packageName;

  /// Folder name directly under `Android/media/<package>/`.
  final String mediaRoot;

  /// Folder path relative to primary external storage.
  String get relativeFolderPath =>
      'Android/media/$packageName/$mediaRoot/Media/${AppConfig.statusFolderName}';

  /// Document URI the folder picker opens at.
  String get initialTreeUri =>
      'content://com.android.externalstorage.documents/document/'
      'primary%3A${Uri.encodeComponent(relativeFolderPath)}';

  /// Finds a source by [id], or null when unknown.
  static StatusSource? fromId(String? id) {
    for (final StatusSource source in StatusSource.values) {
      if (source.id == id) {
        return source;
      }
    }
    return null;
  }
}
