import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/contracts/thumbnail_source.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/viewable_media.dart';
import 'package:statussozo/core/result.dart';
import 'package:statussozo/platform/saf_channel.dart';

/// [ThumbnailSource] with a least-recently-used cache of futures keyed by
/// `(uri, px)`. Scrolling back never re-decodes, and identical [Uint8List]
/// instances let Flutter's image cache hit. Failed decodes are not cached.
class NativeThumbnailSource implements ThumbnailSource {
  NativeThumbnailSource(
    this._channel, {
    int capacity = AppConfig.thumbnailCacheEntries,
  }) : _capacity = capacity;

  final SafChannel _channel;
  final int _capacity;
  final LinkedHashMap<String, Future<Uint8List?>> _cache =
      LinkedHashMap<String, Future<Uint8List?>>();

  /// Number of cached entries.
  @visibleForTesting
  int get cacheSize => _cache.length;

  @override
  Future<Uint8List?> thumbnail(ViewableMedia media, int px) {
    final String key = '${media.uri}|$px';
    final Future<Uint8List?>? hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return hit;
    }
    final Future<Uint8List?> future = _channel.thumbnail(
      uri: media.uri,
      mime: media.mime,
      px: px,
    );
    _cache[key] = future;
    while (_cache.length > _capacity) {
      _cache.remove(_cache.keys.first);
    }
    unawaited(
      future.then((Uint8List? bytes) {
        if (bytes == null && identical(_cache[key], future)) {
          _cache.remove(key);
        }
      }),
    );
    return future;
  }

  @override
  Future<Result<Uint8List>> readImage(ViewableMedia media) {
    if (media.sizeBytes > AppConfig.imageMaxBytes) {
      return Future<Result<Uint8List>>.value(
        Err<Uint8List>(
          AppError(
            AppErrorKind.io,
            detail: 'TOO_LARGE: ${media.sizeBytes} bytes',
          ),
        ),
      );
    }
    return _channel.readBytes(
      uri: media.uri,
      maxBytes: AppConfig.imageMaxBytes,
    );
  }
}
