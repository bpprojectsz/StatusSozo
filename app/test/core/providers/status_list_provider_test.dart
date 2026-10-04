import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/models/folder_grant.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/providers/settings_provider.dart';
import 'package:statussozo/core/providers/source_provider.dart';
import 'package:statussozo/core/providers/status_list_provider.dart';

import '../../fakes/fakes.dart';

void main() {
  late FakeStatusRepository repository;
  late SettingsProvider settings;
  late SourceProvider source;
  late StatusListProvider list;

  Future<void> grantBoth() {
    return settings.update(
      (AppSettings s) => s.copyWith(
        grants: <StatusSource, FolderGrant>{
          for (final StatusSource src in StatusSource.values)
            src: FolderGrant(
              source: src,
              treeUri: 'content://tree/${src.id}',
              grantedAtMs: 1,
            ),
        },
      ),
    );
  }

  setUp(() async {
    repository = FakeStatusRepository();
    settings = SettingsProvider(FakeSettingsStore());
    await settings.load();
    source = SourceProvider(settings);
    list = StatusListProvider(
      repository: repository,
      settings: settings,
      source: source,
    );
    repository.itemsBySource[StatusSource.standard] = <StatusItem>[
      statusItem('old.jpg', modifiedMs: 100),
      statusItem('clip.mp4', mime: 'video/mp4', modifiedMs: 300),
      statusItem('new.jpg', modifiedMs: 200),
    ];
    repository.itemsBySource[StatusSource.business] = <StatusItem>[
      statusItem('biz.jpg', modifiedMs: 50),
    ];
  });
  tearDown(() {
    list.dispose();
    source.dispose();
    settings.dispose();
  });

  test('starts idle', () {
    expect(list.value.phase, ListPhase.idle);
    expect(list.value.items, isEmpty);
  });

  test('without a grant a refresh stays idle and does not list', () async {
    await list.refresh();
    expect(list.value.phase, ListPhase.idle);
    expect(repository.listCalls, 0);
  });

  test('goes from loading to ready, newest first, with tab splits', () async {
    await grantBoth();
    final Completer<void> gate = Completer<void>();
    repository.listGates[StatusSource.standard] = gate;

    final Future<void> pending = list.refresh();
    expect(list.value.phase, ListPhase.loading);
    expect(list.value.items, isEmpty);

    gate.complete();
    await pending;

    expect(list.value.phase, ListPhase.ready);
    expect(list.value.items.map((StatusItem i) => i.name), <String>[
      'clip.mp4',
      'new.jpg',
      'old.jpg',
    ]);
    expect(list.value.photos.map((StatusItem i) => i.name), <String>[
      'new.jpg',
      'old.jpg',
    ]);
    expect(list.value.videos.map((StatusItem i) => i.name), <String>[
      'clip.mp4',
    ]);
    expect(list.value.source, StatusSource.standard);
  });

  test('maps a listing error to the error phase', () async {
    await grantBoth();
    repository.listErrors[StatusSource.standard] = const AppError(
      AppErrorKind.io,
    );
    await list.refresh();
    expect(list.value.phase, ListPhase.error);
    expect(list.value.error?.kind, AppErrorKind.io);
    expect(list.value.items, isEmpty);
  });

  group('silent refresh', () {
    setUp(() async {
      await grantBoth();
      await list.refresh();
    });

    test('keeps the old list on screen while it runs', () async {
      final Completer<void> gate = Completer<void>();
      repository.listGates[StatusSource.standard] = gate;
      repository.itemsBySource[StatusSource.standard] = <StatusItem>[
        statusItem('only.jpg', modifiedMs: 999),
      ];

      final Future<void> pending = list.refresh(silent: true);
      expect(list.value.phase, ListPhase.ready);
      expect(list.value.refreshing, isTrue);
      expect(list.value.items, hasLength(3));

      gate.complete();
      await pending;
      expect(list.value.refreshing, isFalse);
      expect(list.value.items.map((StatusItem i) => i.name), <String>[
        'only.jpg',
      ]);
    });

    test('a failure keeps the old list', () async {
      repository.listErrors[StatusSource.standard] = const AppError(
        AppErrorKind.io,
      );
      await list.refresh(silent: true);
      expect(list.value.phase, ListPhase.ready);
      expect(list.value.refreshing, isFalse);
      expect(list.value.items, hasLength(3));
    });

    test('a non-silent refresh clears to loading first', () async {
      final Completer<void> gate = Completer<void>();
      repository.listGates[StatusSource.standard] = gate;
      final Future<void> pending = list.refresh();
      expect(list.value.phase, ListPhase.loading);
      expect(list.value.items, isEmpty);
      gate.complete();
      await pending;
    });
  });

  group('access lost', () {
    test('calls the callback and shows the error', () async {
      await grantBoth();
      int calls = 0;
      list.onAccessLost = () => calls++;
      repository.listErrors[StatusSource.standard] = const AppError(
        AppErrorKind.accessLost,
      );
      await list.refresh();
      expect(calls, 1);
      expect(list.value.phase, ListPhase.error);
      expect(list.value.error?.kind, AppErrorKind.accessLost);
    });

    test('also when it happens during a silent refresh', () async {
      await grantBoth();
      await list.refresh();
      int calls = 0;
      list.onAccessLost = () => calls++;
      repository.listErrors[StatusSource.standard] = const AppError(
        AppErrorKind.accessLost,
      );
      await list.refresh(silent: true);
      expect(calls, 1);
      expect(list.value.phase, ListPhase.error);
    });
  });

  group('stale responses', () {
    test('a slow response for the old source never overwrites the new one', () async {
      await grantBoth();
      final Completer<void> slow = Completer<void>();
      repository.listGates[StatusSource.standard] = slow;

      final Future<void> oldRequest = list.refresh();
      expect(list.value.source, StatusSource.standard);

      await source.select(StatusSource.business);
      await Future<void>.delayed(Duration.zero);
      expect(list.value.source, StatusSource.business);
      expect(list.value.phase, ListPhase.ready);
      expect(list.value.items.map((StatusItem i) => i.name), <String>[
        'biz.jpg',
      ]);

      slow.complete();
      await oldRequest;
      expect(list.value.source, StatusSource.business);
      expect(list.value.items.map((StatusItem i) => i.name), <String>[
        'biz.jpg',
      ]);
    });

    test('a slow earlier request for the same source loses to a newer one', () async {
      await grantBoth();
      final Completer<void> slow = Completer<void>();
      repository.listGates[StatusSource.standard] = slow;
      final Future<void> first = list.refresh();

      repository.listGates.remove(StatusSource.standard);
      repository.itemsBySource[StatusSource.standard] = <StatusItem>[
        statusItem('fresh.jpg'),
      ];
      await list.refresh();
      expect(list.value.items.map((StatusItem i) => i.name), <String>[
        'fresh.jpg',
      ]);

      repository.itemsBySource[StatusSource.standard] = <StatusItem>[
        statusItem('stale.jpg'),
      ];
      slow.complete();
      await first;
      expect(list.value.items.map((StatusItem i) => i.name), <String>[
        'fresh.jpg',
      ]);
    });
  });

  test('a source change clears and refreshes', () async {
    await grantBoth();
    await list.refresh();
    expect(list.value.items, hasLength(3));
    await source.select(StatusSource.business);
    await Future<void>.delayed(Duration.zero);
    expect(list.value.source, StatusSource.business);
    expect(list.value.items, hasLength(1));
  });

  test('switching to a source without a grant goes idle', () async {
    await settings.update(
      (AppSettings s) => s.copyWith(
        grants: <StatusSource, FolderGrant>{
          StatusSource.standard: const FolderGrant(
            source: StatusSource.standard,
            treeUri: 'content://tree/standard',
            grantedAtMs: 1,
          ),
        },
      ),
    );
    await list.refresh();
    await source.select(StatusSource.business);
    await Future<void>.delayed(Duration.zero);
    expect(list.value.phase, ListPhase.idle);
    expect(list.value.items, isEmpty);
  });
}
