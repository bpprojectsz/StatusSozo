import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:statussozo/core/contracts/status_repository.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/folder_grant.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/providers/settings_provider.dart';
import 'package:statussozo/core/result.dart';
import 'package:statussozo/core/services/status_organizer.dart';
import 'package:statussozo/utils/app_log.dart';

/// Loading phase of a list.
enum ListPhase { idle, loading, ready, error }

@immutable
class StatusListState {
  StatusListState({
    required this.phase,
    this.items = const <StatusItem>[],
    this.error,
    Map<StatusSource, AppError> errors = const <StatusSource, AppError>{},
    this.refreshing = false,
  }) : errors = Map<StatusSource, AppError>.unmodifiable(errors);

  final ListPhase phase;

  /// Every connected source's items together, newest first.
  final List<StatusItem> items;

  /// Set in [ListPhase.error]: the reason the whole list failed.
  final AppError? error;

  /// Sources that failed while others worked. The list still shows the rest.
  final Map<StatusSource, AppError> errors;

  /// True while a silent refresh runs and the old list stays on screen.
  final bool refreshing;

  late final List<StatusItem> photos = StatusOrganizer.photos(items);
  late final List<StatusItem> videos = StatusOrganizer.videos(items);

  /// The items of one source, or all of them when [scope] is null.
  List<StatusItem> itemsFor(StatusSource? scope) => scope == null
      ? items
      : items.where((StatusItem i) => i.source == scope).toList();

  /// How many items one source has, or all together when [scope] is null.
  int countFor(StatusSource? scope) => scope == null
      ? items.length
      : items.where((StatusItem i) => i.source == scope).length;

  StatusListState copyWith({bool? refreshing}) => StatusListState(
    phase: phase,
    items: items,
    error: error,
    errors: errors,
    refreshing: refreshing ?? this.refreshing,
  );
}

bool _sameErrors(
  Map<StatusSource, AppError> a,
  Map<StatusSource, AppError> b,
) {
  if (a.length != b.length) {
    return false;
  }
  for (final MapEntry<StatusSource, AppError> e in a.entries) {
    if (b[e.key]?.kind != e.value.kind) {
      return false;
    }
  }
  return true;
}

/// The statuses of every connected source, read together.
///
/// Both folders are always listed, so switching between All, Standard and
/// Business is instant and each one can show its count. A source that fails
/// while another works is recorded in [StatusListState.errors] and the rest is
/// still shown; the whole list is an error only when every source failed.
class StatusListProvider extends ValueNotifier<StatusListState> {
  StatusListProvider({
    required StatusRepository repository,
    required SettingsProvider settings,
  }) : _repository = repository,
       _settings = settings,
       super(StatusListState(phase: ListPhase.idle));

  final StatusRepository _repository;
  final SettingsProvider _settings;
  int _requestId = 0;

  /// Called when listing fails because folder access was lost.
  VoidCallback? onAccessLost;

  /// Reloads the list. A silent refresh keeps the old list on screen and sets
  /// [StatusListState.refreshing]. Each request has an id, so a slow response
  /// for an earlier request can never overwrite a newer one.
  Future<void> refresh({bool silent = false}) async {
    final Map<StatusSource, FolderGrant> grants = Map<StatusSource, FolderGrant>.of(
      _settings.settings.grants,
    );
    final int id = ++_requestId;

    if (grants.isEmpty) {
      value = StatusListState(phase: ListPhase.idle);
      return;
    }

    final bool keep = silent && value.phase == ListPhase.ready;
    value = keep
        ? value.copyWith(refreshing: true)
        : StatusListState(phase: ListPhase.loading);

    final List<MapEntry<StatusSource, Result<List<StatusItem>>>> results =
        await Future.wait(
          grants.entries.map(
            (MapEntry<StatusSource, FolderGrant> e) async =>
                MapEntry<StatusSource, Result<List<StatusItem>>>(
                  e.key,
                  await _repository.list(e.value),
                ),
          ),
        );
    if (id != _requestId) {
      return;
    }

    final List<StatusItem> all = <StatusItem>[];
    final Map<StatusSource, AppError> errors = <StatusSource, AppError>{};
    for (final MapEntry<StatusSource, Result<List<StatusItem>>> r in results) {
      switch (r.value) {
        case Ok<List<StatusItem>>(value: final List<StatusItem> items):
          all.addAll(items);
        case Err<List<StatusItem>>(:final AppError error):
          errors[r.key] = error;
      }
    }
    final bool lostAccess = errors.values.any(
      (AppError e) => e.kind == AppErrorKind.accessLost,
    );
    final bool everySourceFailed = errors.length == results.length;

    if (everySourceFailed) {
      final AppError first = errors.values.first;
      if (lostAccess) {
        value = StatusListState(
          phase: ListPhase.error,
          error: errors.values.firstWhere(
            (AppError e) => e.kind == AppErrorKind.accessLost,
          ),
          errors: errors,
        );
        onAccessLost?.call();
      } else if (keep) {
        AppLog.warn('list', 'silent refresh failed', first);
        value = value.copyWith(refreshing: false);
      } else {
        value = StatusListState(
          phase: ListPhase.error,
          error: first,
          errors: errors,
        );
      }
      return;
    }

    final List<StatusItem> sorted = StatusOrganizer.newestFirst(all);
    if (keep &&
        listEquals(sorted, value.items) &&
        _sameErrors(errors, value.errors)) {
      // Nothing changed: do not rebuild the grid.
      value = value.copyWith(refreshing: false);
    } else {
      value = StatusListState(
        phase: ListPhase.ready,
        items: sorted,
        errors: errors,
      );
    }
    if (lostAccess) {
      onAccessLost?.call();
    }
  }
}
