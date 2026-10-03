import 'package:statussozo/core/models/folder_grant.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/result.dart';

/// Port for the status source folders.
abstract interface class StatusRepository {
  /// Opens the folder picker for [source]. A cancelled picker returns
  /// `Err(pickerCancelled)`; a folder with the wrong name is released and
  /// returns `Err(wrongFolder)`.
  Future<Result<FolderGrant>> pickFolder(StatusSource source);

  /// Whether the persisted [grant] still works.
  Future<bool> hasAccess(FolderGrant grant);

  /// Releases the persisted permission for [grant].
  Future<void> release(FolderGrant grant);

  /// Lists the images and videos in the granted folder, unsorted.
  Future<Result<List<StatusItem>>> list(FolderGrant grant);
}
