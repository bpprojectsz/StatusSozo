// Shared in-memory test doubles for every contract in lib/core/contracts.
// Each fake has switches to inject failures and delays, and call counters.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:statussozo/core/contracts/haptics_service.dart';
import 'package:statussozo/core/contracts/link_launcher.dart';
import 'package:statussozo/core/contracts/saved_repository.dart';
import 'package:statussozo/core/contracts/settings_store.dart';
import 'package:statussozo/core/contracts/share_service.dart';
import 'package:statussozo/core/contracts/status_repository.dart';
import 'package:statussozo/core/contracts/thumbnail_source.dart';
import 'package:statussozo/core/contracts/video_playback.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/models/folder_grant.dart';
import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/models/viewable_media.dart';
import 'package:statussozo/core/result.dart';

/// A controllable clock.
class FakeClock {
  FakeClock([int startMs = 1700000000000]) : _ms = startMs;

  int _ms;

  int get nowMs => _ms;

  DateTime get now => DateTime.fromMillisecondsSinceEpoch(_ms);

  void advance(Duration duration) => _ms += duration.inMilliseconds;
}

/// Convenience builder for a status item.
StatusItem statusItem(
  String name, {
  String mime = 'image/jpeg',
  int modifiedMs = 1000,
  int sizeBytes = 100,
  String? uri,
}) {
  return StatusItem(
    uri: uri ?? 'content://status/$name',
    name: name,
    mime: mime,
    sizeBytes: sizeBytes,
    modifiedMs: modifiedMs,
  );
}

/// Convenience builder for a saved item.
SavedItem savedItem(
  String name, {
  String mime = 'image/jpeg',
  int savedAtMs = 1000,
  int sizeBytes = 100,
  String? uri,
}) {
  return SavedItem(
    uri: uri ?? 'content://saved/$name',
    name: name,
    mime: mime,
    sizeBytes: sizeBytes,
    savedAtMs: savedAtMs,
  );
}

class FakeStatusRepository implements StatusRepository {
  FakeStatusRepository({FakeClock? clock}) : clock = clock ?? FakeClock();

  final FakeClock clock;

  /// Items returned by [list], by source.
  final Map<StatusSource, List<StatusItem>> itemsBySource =
      <StatusSource, List<StatusItem>>{};

  /// When set, [pickFolder] returns this instead of a generated grant.
  Result<FolderGrant>? pickResult;

  /// Errors returned by [list], by source.
  final Map<StatusSource, AppError> listErrors = <StatusSource, AppError>{};

  /// Sources whose grant no longer works.
  final Set<StatusSource> lostAccess = <StatusSource>{};

  /// Per-source gates: [list] waits for the completer before answering.
  final Map<StatusSource, Completer<void>> listGates =
      <StatusSource, Completer<void>>{};

  /// Delay applied to every call.
  Duration delay = Duration.zero;

  int pickCalls = 0;
  int hasAccessCalls = 0;
  int listCalls = 0;
  final List<FolderGrant> released = <FolderGrant>[];

  Future<void> _wait() async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

  @override
  Future<Result<FolderGrant>> pickFolder(StatusSource source) async {
    pickCalls++;
    await _wait();
    return pickResult ??
        Ok<FolderGrant>(
          FolderGrant(
            source: source,
            treeUri: 'content://tree/${source.id}',
            grantedAtMs: clock.nowMs,
          ),
        );
  }

  @override
  Future<bool> hasAccess(FolderGrant grant) async {
    hasAccessCalls++;
    await _wait();
    return !lostAccess.contains(grant.source);
  }

  @override
  Future<void> release(FolderGrant grant) async {
    await _wait();
    released.add(grant);
  }

  @override
  Future<Result<List<StatusItem>>> list(FolderGrant grant) async {
    listCalls++;
    final Completer<void>? gate = listGates[grant.source];
    if (gate != null) {
      await gate.future;
    }
    await _wait();
    final AppError? error = listErrors[grant.source];
    if (error != null) {
      return Err<List<StatusItem>>(error);
    }
    return Ok<List<StatusItem>>(
      List<StatusItem>.of(itemsBySource[grant.source] ?? <StatusItem>[]),
    );
  }
}

class FakeSavedRepository implements SavedRepository {
  FakeSavedRepository({FakeClock? clock}) : clock = clock ?? FakeClock();

  final FakeClock clock;

  /// What the gallery currently holds.
  final List<SavedItem> items = <SavedItem>[];

  /// Errors returned by [save], by item name.
  final Map<String, AppError> saveErrors = <String, AppError>{};

  /// Errors returned by [delete], by item URI.
  final Map<String, AppError> deleteErrors = <String, AppError>{};

  /// When set, [list] fails with this error.
  AppError? listError;

  /// When true, [save] throws instead of returning a result.
  bool throwOnSave = false;

  Duration delay = Duration.zero;

  int listCalls = 0;
  int saveCalls = 0;
  int deleteCalls = 0;
  final List<String> savedNames = <String>[];
  int _nextId = 1;

  Future<void> _wait() async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

  @override
  Future<Result<List<SavedItem>>> list() async {
    listCalls++;
    await _wait();
    final AppError? error = listError;
    if (error != null) {
      return Err<List<SavedItem>>(error);
    }
    return Ok<List<SavedItem>>(List<SavedItem>.of(items));
  }

  @override
  Future<Result<SavedItem>> save(StatusItem item) async {
    saveCalls++;
    await _wait();
    if (throwOnSave) {
      throw StateError('save exploded');
    }
    final AppError? error = saveErrors[item.name];
    if (error != null) {
      return Err<SavedItem>(error);
    }
    final SavedItem created = SavedItem(
      uri: 'content://media/${_nextId++}',
      name: item.name,
      mime: item.mime,
      sizeBytes: item.sizeBytes,
      savedAtMs: clock.nowMs,
    );
    items.add(created);
    savedNames.add(item.name);
    return Ok<SavedItem>(created);
  }

  @override
  Future<Result<void>> delete(SavedItem item) async {
    deleteCalls++;
    await _wait();
    final AppError? error = deleteErrors[item.uri];
    if (error != null) {
      return Err<void>(error);
    }
    items.removeWhere((SavedItem s) => s.uri == item.uri);
    return const Ok<void>(null);
  }
}

class FakeThumbnailSource implements ThumbnailSource {
  /// Bytes returned for any thumbnail without a specific entry.
  Uint8List? defaultThumbnail = Uint8List.fromList(<int>[1, 2, 3]);

  /// Specific thumbnails by URI. A null value means "cannot decode".
  final Map<String, Uint8List?> thumbnailsByUri = <String, Uint8List?>{};

  /// Bytes returned by [readImage].
  Uint8List imageBytes = Uint8List.fromList(<int>[9, 9, 9]);

  /// When set, [readImage] fails with this error.
  AppError? readError;

  /// When set, [thumbnail] and [readImage] wait for it first.
  Completer<void>? gate;

  int thumbnailCalls = 0;
  int readCalls = 0;

  @override
  Future<Uint8List?> thumbnail(ViewableMedia media, int px) async {
    thumbnailCalls++;
    final Completer<void>? g = gate;
    if (g != null) {
      await g.future;
    }
    if (thumbnailsByUri.containsKey(media.uri)) {
      return thumbnailsByUri[media.uri];
    }
    return defaultThumbnail;
  }

  @override
  Future<Result<Uint8List>> readImage(ViewableMedia media) async {
    readCalls++;
    final Completer<void>? g = gate;
    if (g != null) {
      await g.future;
    }
    final AppError? error = readError;
    if (error != null) {
      return Err<Uint8List>(error);
    }
    return Ok<Uint8List>(imageBytes);
  }
}

class FakeShareService implements ShareService {
  /// When set, [share] fails with this error.
  AppError? error;

  final List<List<ViewableMedia>> shared = <List<ViewableMedia>>[];
  int pruneCalls = 0;

  @override
  Future<Result<void>> share(List<ViewableMedia> items) async {
    final AppError? e = error;
    if (e != null) {
      return Err<void>(e);
    }
    shared.add(List<ViewableMedia>.of(items));
    return const Ok<void>(null);
  }

  @override
  Future<void> pruneCache() async {
    pruneCalls++;
  }
}

class FakeSettingsStore implements SettingsStore {
  FakeSettingsStore({AppSettings? initial})
    : stored = initial ?? AppSettings.defaults();

  /// What a later [load] returns.
  AppSettings stored;

  /// Reported by [load] as `recovered`.
  bool recovered = false;

  /// Reported by [load] as `persistenceAvailable`.
  bool persistenceAvailable = true;

  /// When true, [save] returns false and stores nothing.
  bool failSave = false;

  Duration delay = Duration.zero;

  int loadCalls = 0;
  final List<AppSettings> saves = <AppSettings>[];

  @override
  Future<StoredSettings> load() async {
    loadCalls++;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return StoredSettings(
      settings: stored,
      recovered: recovered,
      persistenceAvailable: persistenceAvailable,
    );
  }

  @override
  Future<bool> save(AppSettings settings) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (failSave) {
      return false;
    }
    stored = settings;
    saves.add(settings);
    return true;
  }
}

/// An email recorded by [FakeLinkLauncher].
class SentEmail {
  const SentEmail({
    required this.to,
    required this.subject,
    required this.body,
  });

  final String to;
  final String subject;
  final String body;
}

class FakeLinkLauncher implements LinkLauncher {
  /// Result returned by every method.
  bool succeed = true;

  final List<Uri> opened = <Uri>[];
  final List<SentEmail> emails = <SentEmail>[];
  int storeListingOpened = 0;

  @override
  Future<bool> openUrl(Uri uri) async {
    opened.add(uri);
    return succeed;
  }

  @override
  Future<bool> composeEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    emails.add(SentEmail(to: to, subject: subject, body: body));
    return succeed;
  }

  @override
  Future<bool> openStoreListing() async {
    storeListingOpened++;
    return succeed;
  }
}

class FakeHapticsService implements HapticsService {
  int selectionCount = 0;
  int lightCount = 0;
  int successCount = 0;

  @override
  void selection() => selectionCount++;

  @override
  void light() => lightCount++;

  @override
  void success() => successCount++;
}

class FakeVideoSession implements VideoSession {
  FakeVideoSession(this.uri, this._factory);

  final String uri;
  final FakeVideoSessionFactory _factory;
  final ValueNotifier<VideoState> _state = ValueNotifier<VideoState>(
    const VideoState(),
  );

  bool disposed = false;

  @override
  ValueListenable<VideoState> get state => _state;

  @override
  Future<void> initialise() async {
    if (_factory.failInitialise) {
      _state.value = _state.value.copyWith(hasError: true);
      return;
    }
    _state.value = _state.value.copyWith(
      initialised: true,
      duration: const Duration(seconds: 10),
    );
  }

  @override
  Future<void> play() async {
    _state.value = _state.value.copyWith(playing: true, ended: false);
  }

  @override
  Future<void> pause() async {
    _state.value = _state.value.copyWith(playing: false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    _state.value = _state.value.copyWith(position: position);
  }

  @override
  Widget buildSurface() => const SizedBox.expand();

  @override
  void dispose() {
    if (disposed) {
      return;
    }
    disposed = true;
    _factory._alive--;
    _state.dispose();
  }
}

class FakeVideoSessionFactory implements VideoSessionFactory {
  /// When true, new sessions fail to initialise.
  bool failInitialise = false;

  final List<FakeVideoSession> created = <FakeVideoSession>[];
  int _alive = 0;
  int maxAlive = 0;

  /// Sessions created and not yet disposed.
  int get alive => _alive;

  @override
  VideoSession create(String uri) {
    final FakeVideoSession session = FakeVideoSession(uri, this);
    created.add(session);
    _alive++;
    if (_alive > maxAlive) {
      maxAlive = _alive;
    }
    return session;
  }
}
