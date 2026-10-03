import 'package:statussozo/core/errors/app_error.dart';

/// Error code strings sent by the native layer. Mirrors `ErrorCodes.kt`.
abstract final class ErrorCodes {
  static const String accessLost = 'ACCESS_LOST';
  static const String notFound = 'NOT_FOUND';
  static const String io = 'IO';
  static const String permissionLost = 'PERMISSION_LOST';
  static const String tooLarge = 'TOO_LARGE';
  static const String unsupported = 'UNSUPPORTED';
}

/// Converts a native error [code] to an [AppError]. Unknown codes become
/// [AppErrorKind.unexpected]. A file that is too large is reported as an I/O
/// failure with the code kept in [AppError.detail].
AppError appErrorFromCode(String code, {String? message, Object? cause}) {
  final AppErrorKind kind = switch (code) {
    ErrorCodes.accessLost => AppErrorKind.accessLost,
    ErrorCodes.notFound => AppErrorKind.notFound,
    ErrorCodes.io || ErrorCodes.tooLarge => AppErrorKind.io,
    ErrorCodes.permissionLost => AppErrorKind.permissionLost,
    ErrorCodes.unsupported => AppErrorKind.unsupported,
    _ => AppErrorKind.unexpected,
  };
  final String detail = message == null ? code : '$code: $message';
  return AppError(kind, cause: cause, detail: detail);
}
