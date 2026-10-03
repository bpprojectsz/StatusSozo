import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/contracts/saved_repository.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/json_fields.dart';
import 'package:statussozo/core/models/media_kind.dart';
import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/result.dart';
import 'package:statussozo/platform/saf_channel.dart';
import 'package:statussozo/utils/app_log.dart';

/// [SavedRepository] over MediaStore.
class MediaStoreSavedRepository implements SavedRepository {
  MediaStoreSavedRepository(this._channel);

  final SafChannel _channel;

  @override
  Future<Result<List<SavedItem>>> list() async {
    final Result<List<Map<String, Object?>>> rows = await _channel.listSaved(
      AppConfig.saveSubfolder,
    );
    return rows.map((List<Map<String, Object?>> value) {
      final List<SavedItem> items = <SavedItem>[];
      for (final Map<String, Object?> row in value) {
        final String? mime = tryReadString(row, 'mime');
        if (mime == null || MediaKind.fromMime(mime) == null) {
          continue;
        }
        try {
          items.add(SavedItem.fromJson(row));
        } on FormatException catch (error) {
          AppLog.warn('saved', 'dropped a malformed row', error);
        }
      }
      return items;
    });
  }

  @override
  Future<Result<SavedItem>> save(StatusItem item) async {
    final Result<Map<String, Object?>> row = await _channel.saveToGallery(
      uri: item.uri,
      name: item.name,
      mime: item.mime,
      subfolder: AppConfig.saveSubfolder,
    );
    switch (row) {
      case Err<Map<String, Object?>>(:final AppError error):
        return Err<SavedItem>(error);
      case Ok<Map<String, Object?>>(:final Map<String, Object?> value):
        try {
          return Ok<SavedItem>(SavedItem.fromJson(value));
        } on FormatException catch (error) {
          return Err<SavedItem>(
            AppError(
              AppErrorKind.unexpected,
              cause: error,
              detail: 'Bad save result',
            ),
          );
        }
    }
  }

  @override
  Future<Result<void>> delete(SavedItem item) async {
    final Result<bool> deleted = await _channel.deleteSaved(item.uri);
    switch (deleted) {
      case Err<bool>(:final AppError error):
        return Err<void>(error);
      case Ok<bool>(:final bool value):
        if (value) {
          return const Ok<void>(null);
        }
        return const Err<void>(
          AppError(AppErrorKind.notFound, detail: 'Nothing was deleted'),
        );
    }
  }
}
