import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/contracts/storage_space.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/save_summary.dart';
import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/services/save_coordinator.dart';

import '../fakes/fakes.dart';

void main() {
  late FakeSavedRepository repository;
  late SaveCoordinator coordinator;
  late List<String> progress;

  void record(int done, int total) => progress.add('$done/$total');

  setUp(() {
    repository = FakeSavedRepository();
    coordinator = SaveCoordinator(repository);
    progress = <String>[];
  });

  List<StatusItem> batch(List<String> names) =>
      names.map((String n) => statusItem(n)).toList();

  test('all succeed', () async {
    final SaveSummary summary = await coordinator.saveAll(
      batch(<String>['a.jpg', 'b.jpg', 'c.jpg']),
      alreadySavedNames: <String>{},
      onProgress: record,
    );
    expect(summary.saved.map((SavedItem s) => s.name), <String>['a.jpg', 'b.jpg', 'c.jpg']);
    expect(summary.skippedDuplicates, 0);
    expect(summary.failed, 0);
    expect(summary.firstError, isNull);
    expect(summary.allSucceeded, isTrue);
    expect(summary.total, 3);
    expect(progress, <String>['1/3', '2/3', '3/3']);
    expect(repository.saveCalls, 3);
  });

  test('names that are already saved are skipped', () async {
    final SaveSummary summary = await coordinator.saveAll(
      batch(<String>['a.jpg', 'b.jpg']),
      alreadySavedNames: <String>{'a.jpg'},
      onProgress: record,
    );
    expect(summary.saved.map((SavedItem s) => s.name), <String>['b.jpg']);
    expect(summary.skippedDuplicates, 1);
    expect(summary.allSucceeded, isTrue);
    expect(summary.total, 2);
    expect(progress, <String>['1/2', '2/2']);
    expect(repository.saveCalls, 1);
  });

  test('duplicates inside the batch are saved once', () async {
    final SaveSummary summary = await coordinator.saveAll(
      <StatusItem>[
        statusItem('a.jpg', uri: 'content://one'),
        statusItem('a.jpg', uri: 'content://two'),
      ],
      alreadySavedNames: <String>{},
    );
    expect(summary.saved, hasLength(1));
    expect(summary.skippedDuplicates, 1);
    expect(repository.saveCalls, 1);
  });

  test('the caller\'s name set is not modified', () async {
    final Set<String> names = <String>{'x.jpg'};
    await coordinator.saveAll(batch(<String>['a.jpg']), alreadySavedNames: names);
    expect(names, <String>{'x.jpg'});
  });

  test('an io failure mid batch continues with the rest', () async {
    repository.saveErrors['b.jpg'] = const AppError(AppErrorKind.io);
    final SaveSummary summary = await coordinator.saveAll(
      batch(<String>['a.jpg', 'b.jpg', 'c.jpg']),
      alreadySavedNames: <String>{},
      onProgress: record,
    );
    expect(summary.saved.map((SavedItem s) => s.name), <String>['a.jpg', 'c.jpg']);
    expect(summary.failed, 1);
    expect(summary.firstError?.kind, AppErrorKind.io);
    expect(summary.allSucceeded, isFalse);
    expect(progress, <String>['1/3', '2/3', '3/3']);
    expect(repository.saveCalls, 3);
  });

  test('permissionLost stops the batch and counts the rest as failed', () async {
    repository.saveErrors['b.jpg'] = const AppError(AppErrorKind.permissionLost);
    final SaveSummary summary = await coordinator.saveAll(
      batch(<String>['a.jpg', 'b.jpg', 'c.jpg', 'd.jpg']),
      alreadySavedNames: <String>{},
      onProgress: record,
    );
    expect(summary.saved.map((SavedItem s) => s.name), <String>['a.jpg']);
    expect(summary.failed, 3);
    expect(summary.total, 4);
    expect(summary.firstError?.kind, AppErrorKind.permissionLost);
    expect(repository.saveCalls, 2);
    expect(progress, <String>['1/4', '2/4', '4/4']);
  });

  test('accessLost stops the batch', () async {
    repository.saveErrors['a.jpg'] = const AppError(AppErrorKind.accessLost);
    final SaveSummary summary = await coordinator.saveAll(
      batch(<String>['a.jpg', 'b.jpg']),
      alreadySavedNames: <String>{},
      onProgress: record,
    );
    expect(summary.saved, isEmpty);
    expect(summary.failed, 2);
    expect(repository.saveCalls, 1);
    expect(progress, <String>['1/2', '2/2']);
  });

  test('stopping on the last item reports progress once', () async {
    repository.saveErrors['b.jpg'] = const AppError(AppErrorKind.accessLost);
    await coordinator.saveAll(
      batch(<String>['a.jpg', 'b.jpg']),
      alreadySavedNames: <String>{},
      onProgress: record,
    );
    expect(progress, <String>['1/2', '2/2']);
  });

  test('firstError is the first one only', () async {
    repository.saveErrors['a.jpg'] = const AppError(AppErrorKind.io, detail: 'first');
    repository.saveErrors['b.jpg'] = const AppError(AppErrorKind.notFound);
    final SaveSummary summary = await coordinator.saveAll(
      batch(<String>['a.jpg', 'b.jpg']),
      alreadySavedNames: <String>{},
    );
    expect(summary.failed, 2);
    expect(summary.firstError?.kind, AppErrorKind.io);
    expect(summary.firstError?.detail, 'first');
  });

  test('a repository that throws becomes an unexpected failure', () async {
    repository.throwOnSave = true;
    final SaveSummary summary = await coordinator.saveAll(
      batch(<String>['a.jpg', 'b.jpg']),
      alreadySavedNames: <String>{},
    );
    expect(summary.failed, 2);
    expect(summary.firstError?.kind, AppErrorKind.unexpected);
    expect(repository.saveCalls, 2);
  });

  test('an empty batch succeeds without progress', () async {
    final SaveSummary summary = await coordinator.saveAll(
      <StatusItem>[],
      alreadySavedNames: <String>{},
      onProgress: record,
    );
    expect(summary.total, 0);
    expect(summary.allSucceeded, isTrue);
    expect(progress, isEmpty);
  });

  test('SaveSummary exposes an unmodifiable saved list', () {
    final SaveSummary summary = SaveSummary(
      saved: <SavedItem>[],
      skippedDuplicates: 0,
      failed: 0,
    );
    expect(() => summary.saved.add(savedItem('x.jpg')), throwsUnsupportedError);
  });

  group('low storage', () {
    late FakeStorageSpace storage;
    late SaveCoordinator guarded;
    const int margin = AppConfig.lowStorageMarginBytes;

    setUp(() {
      storage = FakeStorageSpace();
      guarded = SaveCoordinator(repository, storage: storage);
    });

    List<StatusItem> sized(List<String> names, int size) =>
        names.map((String n) => statusItem(n, sizeBytes: size)).toList();

    test('saves when the whole batch fits with the margin to spare', () async {
      storage.free = 3000 + margin;
      final SaveSummary summary = await guarded.saveAll(
        sized(<String>['a.jpg', 'b.jpg', 'c.jpg'], 1000),
        alreadySavedNames: <String>{},
      );
      expect(summary.saved, hasLength(3));
      expect(storage.asked, <StorageTarget>[StorageTarget.gallery]);
    });

    test('saves nothing and says so when it does not fit', () async {
      storage.free = 3000 + margin - 1;
      final SaveSummary summary = await guarded.saveAll(
        sized(<String>['a.jpg', 'b.jpg', 'c.jpg'], 1000),
        alreadySavedNames: <String>{},
        onProgress: record,
      );
      expect(summary.saved, isEmpty);
      expect(summary.failed, 3);
      expect(summary.firstError?.kind, AppErrorKind.lowStorage);
      expect(repository.saveCalls, 0);
      expect(progress, <String>['3/3']);
    });

    test('names already saved and duplicates do not count toward the need', () async {
      storage.free = 1000 + margin;
      final SaveSummary summary = await guarded.saveAll(
        sized(<String>['a.jpg', 'a.jpg', 'b.jpg'], 1000),
        alreadySavedNames: <String>{'b.jpg'},
      );
      expect(summary.saved, hasLength(1));
      expect(summary.skippedDuplicates, 2);
    });

    test('a batch of only duplicates asks nothing', () async {
      storage.free = 0;
      final SaveSummary summary = await guarded.saveAll(
        sized(<String>['a.jpg'], 1 << 30),
        alreadySavedNames: <String>{'a.jpg'},
      );
      expect(summary.skippedDuplicates, 1);
      expect(summary.firstError, isNull);
      expect(storage.asked, isEmpty);
    });

    test('an unknown amount of space still saves', () async {
      storage.free = null;
      final SaveSummary summary = await guarded.saveAll(
        sized(<String>['a.jpg'], 1 << 30),
        alreadySavedNames: <String>{},
      );
      expect(summary.saved, hasLength(1));
    });

    test('the low-storage summary reports the stop, not a partial save', () async {
      storage.free = 0;
      final SaveSummary summary = await guarded.saveAll(
        sized(<String>['a.jpg', 'b.jpg'], 10),
        alreadySavedNames: <String>{},
      );
      expect(summary.allSucceeded, isFalse);
      expect(summary.total, 2);
    });
  });
}
