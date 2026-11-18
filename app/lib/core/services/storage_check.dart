import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/contracts/storage_space.dart';
import 'package:statussozo/core/errors/app_error.dart';

/// Checks that [neededBytes] fit at [target] with the safety margin to spare.
///
/// Returns null when there is room, or when the free space cannot be read (an
/// unknown amount never blocks anything). Otherwise returns a
/// [AppErrorKind.lowStorage] error naming the numbers for the log.
Future<AppError?> lowStorageError(
  StorageSpace? storage,
  StorageTarget target,
  int neededBytes,
) async {
  if (storage == null || neededBytes <= 0) {
    return null;
  }
  int? free;
  try {
    free = await storage.freeBytes(target);
  } on Object {
    return null;
  }
  if (free == null) {
    return null;
  }
  final int required = neededBytes + AppConfig.lowStorageMarginBytes;
  if (free >= required) {
    return null;
  }
  return AppError(
    AppErrorKind.lowStorage,
    detail: 'needs $required bytes including the margin, $free free',
  );
}
