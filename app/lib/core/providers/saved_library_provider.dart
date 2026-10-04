import 'package:flutter/foundation.dart';
import 'package:statussozo/core/contracts/saved_repository.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/core/providers/status_list_provider.dart';
import 'package:statussozo/core/result.dart';
import 'package:statussozo/core/services/status_organizer.dart';

@immutable
class SavedLibraryState {
  SavedLibraryState({
    required this.phase,
    this.items = const <SavedItem>[],
    this.error,
  }) : names = StatusOrganizer.savedNames(items);

  final ListPhase phase;

  /// Newest first.
  final List<SavedItem> items;

  /// File names of saved items, for the Saved badge and duplicate checks.
  final Set<String> names;
  final AppError? error;
}

/// The result of deleting several items.
class DeleteOutcome {
  const DeleteOutcome({
    required this.deleted,
    required this.failed,
    this.firstError,
  });

  final int deleted;
  final int failed;
  final AppError? firstError;
}

/// What has been saved to the gallery.
class SavedLibraryProvider extends ValueNotifier<SavedLibraryState> {
  SavedLibraryProvider(this._repository)
    : super(SavedLibraryState(phase: ListPhase.idle));

  final SavedRepository _repository;
  int _requestId = 0;

  // Changes made locally while a refresh is in flight. They are merged into
  // the refresh result so a slow query can never undo a save or a delete.
  final Map<String, SavedItem> _addedDuringRefresh = <String, SavedItem>{};
  final Set<String> _deletedDuringRefresh = <String>{};

  /// Reloads from the gallery. The current list stays visible while it runs.
  Future<void> refresh() async {
    final int id = ++_requestId;
    _addedDuringRefresh.clear();
    _deletedDuringRefresh.clear();
    if (value.phase != ListPhase.ready) {
      value = SavedLibraryState(phase: ListPhase.loading, items: value.items);
    }
    final Result<List<SavedItem>> result = await _repository.list();
    if (id != _requestId) {
      return;
    }
    switch (result) {
      case Ok<List<SavedItem>>(value: final List<SavedItem> items):
        final Map<String, SavedItem> merged = <String, SavedItem>{
          for (final SavedItem item in items) item.uri: item,
          ..._addedDuringRefresh,
        };
        _deletedDuringRefresh.forEach(merged.remove);
        value = SavedLibraryState(
          phase: ListPhase.ready,
          items: StatusOrganizer.savedNewestFirst(merged.values.toList()),
        );
      case Err<List<SavedItem>>(:final AppError error):
        value = SavedLibraryState(
          phase: ListPhase.error,
          items: value.items,
          error: error,
        );
    }
  }

  /// Merges newly saved items without re-querying the gallery.
  void onSaved(List<SavedItem> saved) {
    if (saved.isEmpty) {
      return;
    }
    final Map<String, SavedItem> merged = <String, SavedItem>{
      for (final SavedItem item in value.items) item.uri: item,
      for (final SavedItem item in saved) item.uri: item,
    };
    for (final SavedItem item in saved) {
      _addedDuringRefresh[item.uri] = item;
      _deletedDuringRefresh.remove(item.uri);
    }
    value = SavedLibraryState(
      phase: ListPhase.ready,
      items: StatusOrganizer.savedNewestFirst(merged.values.toList()),
    );
  }

  /// Deletes [items] one at a time, updating the list after each success.
  Future<DeleteOutcome> delete(List<SavedItem> items) async {
    int deleted = 0;
    int failed = 0;
    AppError? firstError;
    for (final SavedItem item in items) {
      final Result<void> result = await _repository.delete(item);
      switch (result) {
        case Ok<void>():
          deleted++;
          _deletedDuringRefresh.add(item.uri);
          _addedDuringRefresh.remove(item.uri);
          value = SavedLibraryState(
            phase: value.phase == ListPhase.ready
                ? ListPhase.ready
                : value.phase,
            items: value.items
                .where((SavedItem s) => s.uri != item.uri)
                .toList(),
            error: value.error,
          );
        case Err<void>(:final AppError error):
          failed++;
          firstError ??= error;
      }
    }
    return DeleteOutcome(
      deleted: deleted,
      failed: failed,
      firstError: firstError,
    );
  }
}
