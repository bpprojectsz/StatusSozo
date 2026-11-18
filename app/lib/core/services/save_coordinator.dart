import 'package:statussozo/core/contracts/saved_repository.dart';
import 'package:statussozo/core/contracts/storage_space.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/save_summary.dart';
import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/result.dart';
import 'package:statussozo/core/services/storage_check.dart';

/// Batch save orchestration.
///
/// Sequential. Skips names that are already saved and duplicates inside the
/// batch. Continues after an I/O failure. Stops the batch on `permissionLost`
/// or `accessLost`, because retrying is pointless; items not attempted are
/// counted as failed. Before saving anything it checks that the whole batch
/// fits with a safety margin to spare; if not, nothing is saved and the batch
/// fails as [AppErrorKind.lowStorage].
class SaveCoordinator {
  const SaveCoordinator(this._repository, {StorageSpace? storage})
    : _storage = storage;

  final SavedRepository _repository;
  final StorageSpace? _storage;

  /// Saves [items]. [onProgress] receives `(done, total)` after each item; when
  /// the batch stops early it also receives a final `(total, total)`.
  Future<SaveSummary> saveAll(
    List<StatusItem> items, {
    required Set<String> alreadySavedNames,
    void Function(int done, int total)? onProgress,
  }) async {
    final Set<String> names = <String>{...alreadySavedNames};
    final List<SavedItem> saved = <SavedItem>[];
    final int total = items.length;

    // Is there room for everything that will really be written?
    final Set<String> seen = <String>{...alreadySavedNames};
    int needed = 0;
    int toSave = 0;
    for (final StatusItem item in items) {
      if (seen.add(item.name)) {
        needed += item.sizeBytes;
        toSave++;
      }
    }
    final AppError? noRoom = await lowStorageError(
      _storage,
      StorageTarget.gallery,
      needed,
    );
    if (noRoom != null) {
      onProgress?.call(total, total);
      return SaveSummary(
        saved: const <SavedItem>[],
        skippedDuplicates: total - toSave,
        failed: toSave,
        firstError: noRoom,
      );
    }

    int skipped = 0;
    int failed = 0;
    AppError? firstError;

    for (int i = 0; i < total; i++) {
      final StatusItem item = items[i];
      if (names.contains(item.name)) {
        skipped++;
        onProgress?.call(i + 1, total);
        continue;
      }

      Result<SavedItem> result;
      try {
        result = await _repository.save(item);
      } on Object catch (error) {
        result = Err<SavedItem>(
          AppError(
            AppErrorKind.unexpected,
            cause: error,
            detail: 'save threw an exception',
          ),
        );
      }

      bool stop = false;
      switch (result) {
        case Ok<SavedItem>(:final SavedItem value):
          saved.add(value);
          names.add(item.name);
        case Err<SavedItem>(:final AppError error):
          failed++;
          firstError ??= error;
          stop =
              error.kind == AppErrorKind.permissionLost ||
              error.kind == AppErrorKind.accessLost;
      }

      onProgress?.call(i + 1, total);
      if (stop) {
        final int remaining = total - (i + 1);
        if (remaining > 0) {
          failed += remaining;
          onProgress?.call(total, total);
        }
        break;
      }
    }

    return SaveSummary(
      saved: saved,
      skippedDuplicates: skipped,
      failed: failed,
      firstError: firstError,
    );
  }
}
