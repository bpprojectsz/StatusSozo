import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:statussozo/core/contracts/status_repository.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/models/folder_grant.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/providers/settings_provider.dart';
import 'package:statussozo/core/providers/source_provider.dart';
import 'package:statussozo/core/result.dart';

/// Connection state of one source.
enum AccessStatus { unknown, connected, needsRenewal, notConnected }

@immutable
class FolderAccessState {
  FolderAccessState({
    required Map<StatusSource, AccessStatus> status,
    this.connecting,
  }) : status = Map<StatusSource, AccessStatus>.unmodifiable(status);

  factory FolderAccessState.initial() => FolderAccessState(
    status: <StatusSource, AccessStatus>{
      for (final StatusSource s in StatusSource.values) s: AccessStatus.unknown,
    },
  );

  final Map<StatusSource, AccessStatus> status;

  /// The source whose picker is currently open, if any.
  final StatusSource? connecting;

  AccessStatus statusOf(StatusSource source) =>
      status[source] ?? AccessStatus.unknown;

  FolderAccessState copyWith({
    Map<StatusSource, AccessStatus>? status,
    StatusSource? connecting,
    bool clearConnecting = false,
  }) {
    return FolderAccessState(
      status: status ?? this.status,
      connecting: clearConnecting ? null : (connecting ?? this.connecting),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FolderAccessState &&
      other.connecting == connecting &&
      mapEquals(other.status, status);

  @override
  int get hashCode => Object.hash(
    connecting,
    Object.hashAllUnordered(
      status.entries.map(
        (MapEntry<StatusSource, AccessStatus> e) => Object.hash(e.key, e.value),
      ),
    ),
  );
}

/// Per-source connection state: verify, connect, disconnect.
class FolderAccessProvider extends ValueNotifier<FolderAccessState> {
  FolderAccessProvider({
    required StatusRepository repository,
    required SettingsProvider settings,
    required SourceProvider source,
  }) : _repository = repository,
       _settings = settings,
       _source = source,
       super(FolderAccessState.initial());

  final StatusRepository _repository;
  final SettingsProvider _settings;
  final SourceProvider _source;
  int _verifyId = 0;

  /// True when at least one source is connected.
  bool get hasUsableSource => value.status.values.any(
    (AccessStatus s) => s == AccessStatus.connected,
  );

  /// Sources that are connected, in declaration order.
  List<StatusSource> get connectedSources => <StatusSource>[
    for (final StatusSource s in StatusSource.values)
      if (value.statusOf(s) == AccessStatus.connected) s,
  ];

  /// Checks every stored grant. No grant means not connected; a working grant
  /// means connected; a grant that no longer works needs renewal.
  Future<void> verifyAll() async {
    final int id = ++_verifyId;
    final Map<StatusSource, AccessStatus> next =
        <StatusSource, AccessStatus>{};
    await Future.wait<void>(
      StatusSource.values.map((StatusSource source) async {
        final FolderGrant? grant = _settings.settings.grants[source];
        if (grant == null) {
          next[source] = AccessStatus.notConnected;
          return;
        }
        final bool ok = await _repository.hasAccess(grant);
        next[source] = ok ? AccessStatus.connected : AccessStatus.needsRenewal;
      }),
    );
    if (id != _verifyId) {
      return;
    }
    value = value.copyWith(status: next);
  }

  /// Opens the picker for [source]. Returns the failure, or null on success.
  /// Ignored (returns null) while another picker is open.
  Future<AppError?> connect(StatusSource source) async {
    if (value.connecting != null) {
      return null;
    }
    value = value.copyWith(connecting: source);
    final Result<FolderGrant> result = await _repository.pickFolder(source);
    switch (result) {
      case Err<FolderGrant>(:final AppError error):
        value = value.copyWith(clearConnecting: true);
        return error;
      case Ok<FolderGrant>(value: final FolderGrant grant):
        final FolderGrant? previous = _settings.settings.grants[source];
        if (previous != null && previous.treeUri != grant.treeUri) {
          await _repository.release(previous);
        }
        final bool currentUsable =
            value.statusOf(_source.value) == AccessStatus.connected;
        unawaited(
          _settings.update(
            (AppSettings s) => s.copyWith(
              grants: <StatusSource, FolderGrant>{...s.grants, source: grant},
            ),
          ),
        );
        value = value.copyWith(
          status: <StatusSource, AccessStatus>{
            ...value.status,
            source: AccessStatus.connected,
          },
          clearConnecting: true,
        );
        if (!currentUsable) {
          unawaited(_source.select(source));
        }
        return null;
    }
  }

  /// Releases the grant for [source]. If it was the selected source, switches
  /// to another connected one.
  Future<void> disconnect(StatusSource source) async {
    final FolderGrant? grant = _settings.settings.grants[source];
    if (grant == null) {
      return;
    }
    await _repository.release(grant);
    unawaited(
      _settings.update(
        (AppSettings s) => s.copyWith(
          grants: <StatusSource, FolderGrant>{...s.grants}..remove(source),
        ),
      ),
    );
    value = value.copyWith(
      status: <StatusSource, AccessStatus>{
        ...value.status,
        source: AccessStatus.notConnected,
      },
    );
    if (_source.value == source) {
      for (final StatusSource other in connectedSources) {
        if (other != source) {
          unawaited(_source.select(other));
          break;
        }
      }
    }
  }
}
