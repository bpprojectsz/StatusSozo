import 'package:statussozo/core/models/viewable_media.dart';
import 'package:statussozo/core/result.dart';

/// Port for the system share sheet.
abstract interface class ShareService {
  /// Shares one or many items.
  Future<Result<void>> share(List<ViewableMedia> items);

  /// Shares plain text, such as an invitation to install the app.
  Future<Result<void>> shareText(String text);

  /// Deletes staged share copies older than the configured time to live, and
  /// the oldest ones beyond the size cap.
  Future<void> pruneCache();

  /// The size of the staged share copies in bytes (0 if unknown).
  Future<int> cacheSize();

  /// Deletes every staged share copy and returns how many files went.
  Future<int> clearCache();
}
