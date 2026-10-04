import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:statussozo/core/contracts/status_repository.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/folder_grant.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/providers/settings_provider.dart';
import 'package:statussozo/core/providers/source_provider.dart';
import 'package:statussozo/core/result.dart';
import 'package:statussozo/core/services/status_organizer.dart';
import 'package:statussozo/utils/app_log.dart';

/// Loading phase of a list.
enum ListPhase { idle, loading, ready, error }

@immutable
class StatusListState {
  StatusListState({
    required this.phase,
    required this.source,
    this.items = const <StatusItem>[],
    this.error,
    this.refreshing = false,
  });

  final ListPhase phase;
  final StatusSource source;

  /// Newest first.
  final List<StatusItem> items;
  final AppError? error;

  /// True while a silent refresh runs and the old list stays on screen.
  final bool refreshing;

  late final List<StatusItem> photos = StatusOrganizer.photos(items);
  late final List<StatusItem> videos = StatusOrganizer.videos(items);

  StatusListState copyWith({bool? refreshing}) => StatusListState(
    phase: phase,
    source: source,
    items: items,
    error: error,
    refreshing: refreshing ?? this.refreshing,
  );
}

/// The list for the current source.
class StatusListProvider extends ValueNotifier<StatusListState> {
  StatusListProvider({
    required StatusRepository repository,
    required SettingsProvider settings,
    required SourceProvider source,
  }) : _repository = repository,
       _settings = settings,
       _source = source,
       super(
         StatusListState(phase: ListPhase.idle, source: source.value),
       ) {
    _source.addListener(_onSourceChanged);
  }

  final StatusRepository _repository;
  final SettingsProvider _settings;
  final SourceProvider _source;
  int _requestId = 0;

  /// Called when listing fails because folder access was lost.
  VoidCallback? onAccessLost;

  void _onSourceChanged() {
    unawaited(refresh());
  }

  /// Reloads the list. A silent refresh keeps the old list on screen and sets
  /// [StatusListState.refreshing]. Each request has an id, so a slow response
  /// for an earlier source or request can never overwrite a newer one.
  Future<void> refresh({bool silent = false}) async {
    final StatusSource source = _source.value;
    final FolderGrant? grant = _settings.settings.grants[source];
    final int id = ++_requestId;

    if (grant == null) {
      value = StatusListState(phase: ListPhase.idle, source: source);
      return;
    }

    final bool keep =
        silent && value.source == source && value.phase == ListPhase.ready;
    value = keep
        ? value.copyWith(refreshing: true)
        : StatusListState(phase: ListPhase.loading, source: source);

    final Result<List<StatusItem>> result = await _repository.list(grant);
    if (id != _requestId) {
      return;
    }

    switch (result) {
      case Ok<List<StatusItem>>(value: final List<StatusItem> items):
        value = StatusListState(
          phase: ListPhase.ready,
          source: source,
          items: StatusOrganizer.newestFirst(items),
        );
      case Err<List<StatusItem>>(:final AppError error):
        if (error.kind == AppErrorKind.accessLost) {
          value = StatusListState(
            phase: ListPhase.error,
            source: source,
            error: error,
          );
          onAccessLost?.call();
        } else if (keep) {
          AppLog.warn('list', 'silent refresh failed', error);
          value = value.copyWith(refreshing: false);
        } else {
          value = StatusListState(
            phase: ListPhase.error,
            source: source,
            error: error,
          );
        }
    }
  }

  @override
  void dispose() {
    _source.removeListener(_onSourceChanged);
    super.dispose();
  }
}
