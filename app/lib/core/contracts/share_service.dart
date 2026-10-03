import 'package:statussozo/core/models/viewable_media.dart';
import 'package:statussozo/core/result.dart';

/// Port for the system share sheet.
abstract interface class ShareService {
  /// Shares one or many items.
  Future<Result<void>> share(List<ViewableMedia> items);

  /// Deletes staged share copies older than the configured time to live.
  Future<void> pruneCache();
}
