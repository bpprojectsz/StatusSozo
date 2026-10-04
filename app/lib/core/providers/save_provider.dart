import 'package:flutter/foundation.dart';
import 'package:statussozo/core/contracts/haptics_service.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/save_summary.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/providers/saved_library_provider.dart';
import 'package:statussozo/core/providers/toast_provider.dart';
import 'package:statussozo/core/services/save_coordinator.dart';

@immutable
class SaveState {
  const SaveState({
    this.saving = false,
    this.done = 0,
    this.total = 0,
    this.last,
  });

  final bool saving;
  final int done;
  final int total;

  /// The summary of the most recent batch.
  final SaveSummary? last;
}

/// Save operations. Emits exactly one toast per batch.
class SaveProvider extends ValueNotifier<SaveState> {
  SaveProvider({
    required SaveCoordinator coordinator,
    required SavedLibraryProvider library,
    required HapticsService haptics,
    required ToastProvider toasts,
  }) : _coordinator = coordinator,
       _library = library,
       _haptics = haptics,
       _toasts = toasts,
       super(const SaveState());

  final SaveCoordinator _coordinator;
  final SavedLibraryProvider _library;
  final HapticsService _haptics;
  final ToastProvider _toasts;

  /// Saves [items]. Returns null when refused because a save is already
  /// running or there is nothing to save.
  Future<SaveSummary?> save(List<StatusItem> items) async {
    if (value.saving || items.isEmpty) {
      return null;
    }
    value = SaveState(saving: true, total: items.length, last: value.last);
    final SaveSummary summary = await _coordinator.saveAll(
      items,
      alreadySavedNames: _library.value.names,
      onProgress: (int done, int total) {
        value = SaveState(
          saving: true,
          done: done,
          total: total,
          last: value.last,
        );
      },
    );
    _library.onSaved(summary.saved);
    if (summary.saved.isNotEmpty) {
      _haptics.success();
    }
    value = SaveState(done: summary.total, total: summary.total, last: summary);
    _announce(summary);
    return summary;
  }

  void _announce(SaveSummary summary) {
    final int saved = summary.saved.length;
    if (saved > 0 && summary.failed > 0) {
      _toasts.show(
        ToastCode.savedPartial,
        count: saved,
        secondCount: summary.failed,
      );
    } else if (saved > 0) {
      _toasts.show(ToastCode.saved, count: saved);
    } else if (summary.failed > 0) {
      final bool lostAccess =
          summary.firstError?.kind == AppErrorKind.accessLost;
      _toasts.show(lostAccess ? ToastCode.accessLost : ToastCode.saveFailed);
    } else if (summary.skippedDuplicates > 0) {
      _toasts.show(ToastCode.alreadySaved);
    }
  }
}
