
import 'package:flutter/services.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/errors/error_codes.dart';
import 'package:statussozo/core/models/json_fields.dart';
import 'package:statussozo/core/result.dart';
import 'package:statussozo/utils/app_log.dart';

/// The folder the person picked in the system picker.
class PickedFolder {
  const PickedFolder({required this.uri, required this.name});

  final String uri;
  final String name;
}

/// The single owner of the native channel. One typed method per row of the
/// protocol; every failure is returned as a value, never thrown.
class SafChannel {
  SafChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'statussozo/saf';

  final MethodChannel _channel;

  Future<Result<T>> _call<T>(
    String method,
    Map<String, Object?> arguments,
    T Function(Object? raw) parse,
  ) async {
    try {
      final Object? raw = await _channel.invokeMethod<Object?>(
        method,
        arguments,
      );
      return Ok<T>(parse(raw));
    } on PlatformException catch (error) {
      AppLog.warn('saf', '$method failed with ${error.code}', error.message);
      return Err<T>(
        appErrorFromCode(error.code, message: error.message, cause: error),
      );
    } on MissingPluginException catch (error) {
      AppLog.error('saf', '$method has no native handler', error);
      return Err<T>(
        AppError(
          AppErrorKind.unsupported,
          cause: error,
          detail: 'No native handler for $method',
        ),
      );
    } on Object catch (error) {
      AppLog.error('saf', '$method returned an unexpected payload', error);
      return Err<T>(
        AppError(
          AppErrorKind.unexpected,
          cause: error,
          detail: 'Bad payload from $method',
        ),
      );
    }
  }

  static List<Map<String, Object?>> _rows(Object? raw) {
    if (raw is! List<Object?>) {
      throw FormatException('Expected a list of rows', raw);
    }
    return <Map<String, Object?>>[
      for (final Object? row in raw)
        if (row is Map<Object?, Object?>)
          stringKeyed(row)
        else
          throw FormatException('Expected a map row', row),
    ];
  }

  static Map<String, Object?> _row(Object? raw) {
    if (raw is! Map<Object?, Object?>) {
      throw FormatException('Expected a map', raw);
    }
    return stringKeyed(raw);
  }

  /// Opens the system folder picker. `Ok(null)` means the person cancelled.
  Future<Result<PickedFolder?>> pickFolder({String? initialUri}) {
    return _call<PickedFolder?>(
      'pickFolder',
      <String, Object?>{'initialUri': initialUri},
      (Object? raw) {
        if (raw == null) {
          return null;
        }
        final Map<String, Object?> row = _row(raw);
        return PickedFolder(
          uri: readString(row, 'uri'),
          name: readString(row, 'name'),
        );
      },
    );
  }

  /// Whether the persisted permission for [uri] still works. False on error.
  Future<bool> hasAccess(String uri) async {
    final Result<bool> result = await _call<bool>(
      'hasAccess',
      <String, Object?>{'uri': uri},
      (Object? raw) => raw == true,
    );
    return result.valueOrNull ?? false;
  }

  /// Releases the persisted permission for [uri]. Errors are logged only.
  Future<void> releaseFolder(String uri) async {
    await _call<void>('releaseFolder', <String, Object?>{'uri': uri}, (
      Object? raw,
    ) {});
  }

  /// Rows of `{uri, name, mime, size, modified}`, unsorted.
  Future<Result<List<Map<String, Object?>>>> listFolder(String uri) {
    return _call<List<Map<String, Object?>>>(
      'listFolder',
      <String, Object?>{'uri': uri},
      _rows,
    );
  }

  /// JPEG bytes, or null when the file cannot be decoded or on any error.
  Future<Uint8List?> thumbnail({
    required String uri,
    required String mime,
    required int px,
  }) async {
    final Result<Uint8List?> result = await _call<Uint8List?>(
      'thumbnail',
      <String, Object?>{'uri': uri, 'mime': mime, 'px': px},
      (Object? raw) {
        if (raw == null) {
          return null;
        }
        if (raw is Uint8List) {
          return raw;
        }
        throw FormatException('Expected bytes', raw);
      },
    );
    return result.valueOrNull;
  }

  /// Reads at most [maxBytes] from [uri].
  Future<Result<Uint8List>> readBytes({
    required String uri,
    required int maxBytes,
  }) {
    return _call<Uint8List>(
      'readBytes',
      <String, Object?>{'uri': uri, 'maxBytes': maxBytes},
      (Object? raw) {
        if (raw is Uint8List) {
          return raw;
        }
        throw FormatException('Expected bytes', raw);
      },
    );
  }

  /// Copies [uri] into the gallery. Returns `{uri, name, mime, size, added}`.
  Future<Result<Map<String, Object?>>> saveToGallery({
    required String uri,
    required String name,
    required String mime,
    required String subfolder,
  }) {
    return _call<Map<String, Object?>>(
      'saveToGallery',
      <String, Object?>{
        'uri': uri,
        'name': name,
        'mime': mime,
        'subfolder': subfolder,
      },
      _row,
    );
  }

  /// Rows of `{uri, name, mime, size, added}` saved by this app.
  Future<Result<List<Map<String, Object?>>>> listSaved(String subfolder) {
    return _call<List<Map<String, Object?>>>(
      'listSaved',
      <String, Object?>{'subfolder': subfolder},
      _rows,
    );
  }

  /// Deletes a saved item. `Ok(false)` means nothing was deleted.
  Future<Result<bool>> deleteSaved(String uri) {
    return _call<bool>(
      'deleteSaved',
      <String, Object?>{'uri': uri},
      (Object? raw) => raw == true,
    );
  }

  /// Copies [uri] into the share cache and returns the absolute path.
  Future<Result<String>> copyToCache({
    required String uri,
    required String name,
  }) {
    return _call<String>(
      'copyToCache',
      <String, Object?>{'uri': uri, 'name': name},
      (Object? raw) {
        if (raw is String) {
          return raw;
        }
        throw FormatException('Expected a path', raw);
      },
    );
  }

  /// Deletes share-cache files older than [olderThanMs]. Returns the count.
  Future<int> pruneShareCache(int olderThanMs) async {
    final Result<int> result = await _call<int>(
      'pruneShareCache',
      <String, Object?>{'olderThanMs': olderThanMs},
      (Object? raw) => raw is int ? raw : 0,
    );
    return result.valueOrNull ?? 0;
  }
}
