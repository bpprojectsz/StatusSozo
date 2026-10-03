import 'package:flutter/foundation.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/saved_item.dart';

/// The result of a batch save.
@immutable
class SaveSummary {
  SaveSummary({
    required List<SavedItem> saved,
    required this.skippedDuplicates,
    required this.failed,
    this.firstError,
  }) : saved = List<SavedItem>.unmodifiable(saved);

  /// Items that were newly saved.
  final List<SavedItem> saved;

  /// Items skipped because a saved item with the same name already exists.
  final int skippedDuplicates;

  /// Items that could not be saved, including items not attempted because the
  /// batch stopped early.
  final int failed;

  /// The first error encountered, if any.
  final AppError? firstError;

  /// Every item in the batch.
  int get total => saved.length + skippedDuplicates + failed;

  /// True when nothing failed.
  bool get allSucceeded => failed == 0 && firstError == null;
}
