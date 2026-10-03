import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/contracts/status_repository.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/folder_grant.dart';
import 'package:statussozo/core/models/json_fields.dart';
import 'package:statussozo/core/models/media_kind.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/result.dart';
import 'package:statussozo/platform/saf_channel.dart';
import 'package:statussozo/utils/app_log.dart';

/// [StatusRepository] over the storage access framework.
class SafStatusRepository implements StatusRepository {
  SafStatusRepository(this._channel, {int Function()? nowMs})
    : _nowMs = nowMs ?? _systemNowMs;

  final SafChannel _channel;
  final int Function() _nowMs;

  static int _systemNowMs() => DateTime.now().millisecondsSinceEpoch;

  @override
  Future<Result<FolderGrant>> pickFolder(StatusSource source) async {
    final Result<PickedFolder?> picked = await _channel.pickFolder(
      initialUri: source.initialTreeUri,
    );
    switch (picked) {
      case Err<PickedFolder?>(:final AppError error):
        return Err<FolderGrant>(error);
      case Ok<PickedFolder?>(:final PickedFolder? value):
        if (value == null) {
          return const Err<FolderGrant>(
            AppError(AppErrorKind.pickerCancelled),
          );
        }
        if (value.name != AppConfig.statusFolderName) {
          // Do not keep a permission the app cannot use.
          await _channel.releaseFolder(value.uri);
          return Err<FolderGrant>(
            AppError(
              AppErrorKind.wrongFolder,
              detail: 'Picked "${value.name}"',
            ),
          );
        }
        return Ok<FolderGrant>(
          FolderGrant(
            source: source,
            treeUri: value.uri,
            grantedAtMs: _nowMs(),
          ),
        );
    }
  }

  @override
  Future<bool> hasAccess(FolderGrant grant) => _channel.hasAccess(grant.treeUri);

  @override
  Future<void> release(FolderGrant grant) =>
      _channel.releaseFolder(grant.treeUri);

  @override
  Future<Result<List<StatusItem>>> list(FolderGrant grant) async {
    final Result<List<Map<String, Object?>>> rows = await _channel.listFolder(
      grant.treeUri,
    );
    return rows.map((List<Map<String, Object?>> value) {
      final List<StatusItem> items = <StatusItem>[];
      for (final Map<String, Object?> row in value) {
        final String? mime = tryReadString(row, 'mime');
        if (mime == null || MediaKind.fromMime(mime) == null) {
          continue;
        }
        try {
          items.add(StatusItem.fromJson(row));
        } on FormatException catch (error) {
          AppLog.warn('status', 'dropped a malformed row', error);
        }
      }
      return items;
    });
  }
}
