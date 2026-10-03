import 'package:share_plus/share_plus.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/contracts/share_service.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/viewable_media.dart';
import 'package:statussozo/core/result.dart';
import 'package:statussozo/platform/saf_channel.dart';
import 'package:statussozo/utils/app_log.dart';

/// Opens the system share sheet with a list of files.
typedef FileSharer = Future<void> Function(List<XFile> files);

/// [ShareService] over `share_plus`. Each item is first copied to the cache
/// folder, so the share sheet reads a plain file rather than a document URI.
class PlusShareService implements ShareService {
  PlusShareService(this._channel, {FileSharer? sharer})
    : _sharer = sharer ?? _systemSharer;

  final SafChannel _channel;
  final FileSharer _sharer;

  static Future<void> _systemSharer(List<XFile> files) async {
    await Share.shareXFiles(files);
  }

  @override
  Future<Result<void>> share(List<ViewableMedia> items) async {
    if (items.isEmpty) {
      return const Ok<void>(null);
    }
    final List<XFile> files = <XFile>[];
    for (final ViewableMedia item in items) {
      final Result<String> copy = await _channel.copyToCache(
        uri: item.uri,
        name: item.name,
      );
      switch (copy) {
        case Err<String>(:final AppError error):
          return Err<void>(error);
        case Ok<String>(:final String value):
          files.add(XFile(value, mimeType: item.mime, name: item.name));
      }
    }
    try {
      await _sharer(files);
      return const Ok<void>(null);
    } on Object catch (error) {
      AppLog.error('share', 'share sheet failed', error);
      return Err<void>(
        AppError(
          AppErrorKind.unexpected,
          cause: error,
          detail: 'Share sheet failed',
        ),
      );
    }
  }

  @override
  Future<void> pruneCache() async {
    await _channel.pruneShareCache(AppConfig.shareCacheTtl.inMilliseconds);
  }
}
