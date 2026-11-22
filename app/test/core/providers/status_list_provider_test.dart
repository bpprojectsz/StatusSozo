import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/models/folder_grant.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/providers/settings_provider.dart';
import 'package:statussozo/core/providers/status_list_provider.dart';

import '../../fakes/fakes.dart';

void main() {
  late FakeStatusRepository repository;
  late SettingsProvider settings;
  late StatusListProvider list;

  FolderGrant grant(StatusSource s) => FolderGrant(
    source: s,
    treeUri: 'content://tree/${s.id}',
    grantedAtMs: 1,
  );

  Future<void> grant1(Set<StatusSource> sources) {
    return settings.update(
      (AppSettings s) => s.copyWith(
        grants: <StatusSource, FolderGrant>{
          for (final StatusSource src in sources) src: grant(src),
        },
      ),
    );
  }

  Future<void> grantBoth() => grant1(StatusSource.values.toSet());

  List<String> names(Iterable<StatusItem> items) =>
      items.map((StatusItem i) => i.name).toList();

  setUp(() async {
    repository = FakeStatusRepository();
    settings = SettingsProvider(FakeSettingsStore());
    await settings.load();
    list = StatusListProvider(repository: repository, settings: settings);
    repository.itemsBySource[StatusSource.standard] = <StatusItem>[
      statusItem('old.jpg', modifiedMs: 100),
      statusItem('clip.mp4', mime: 'video/mp4', modifiedMs: 300),
      statusItem('new.jpg', modifiedMs: 200),
    ];
    repository.itemsBySource[StatusSource.business] = <StatusItem>[
      statusItem('biz.jpg', modifiedMs: 250),
    ];
  });
  tearDown(() {
    list.dispose();
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

  test('goes from loading to ready with every source merged, newest first', () async {
    await grantBoth();
    final Completer<void> gate = Completer<void>();
    repository.listGates[StatusSource.standard] = gate;

    final Future<void> pending = list.refresh();
    expect(list.value.phase, ListPhase.loading);
    expect(list.value.items, isEmpty);

    gate.complete();
    await pending;

    expect(list.value.phase, ListPhase.ready);
    expect(names(list.value.items), <String>[
      'clip.mp4',
      'biz.jpg',
      'new.jpg',
      'old.jpg',
    ]);
    expect(names(list.value.photos), <String>['biz.jpg', 'new.jpg', 'old.jpg']);
    expect(names(list.value.videos), <String>['clip.mp4']);
  });

  test('every item says which source it came from', () async {
    await grantBoth();
    await list.refresh();
    final Map<String, StatusSource> byName = <String, StatusSource>{
      for (final StatusItem i in list.value.items) i.name: i.source,
    };
    expect(byName['biz.jpg'], StatusSource.business);
    expect(byName['new.jpg'], StatusSource.standard);
  });

  test('itemsFor and countFor split by source', () async {
    await grantBoth();
    await list.refresh();
    expect(list.value.countFor(null), 4);
    expect(list.value.countFor(StatusSource.standard), 3);
    expect(list.value.countFor(StatusSource.business), 1);
    expect(names(list.value.itemsFor(StatusSource.business)), <String>[
      'biz.jpg',
    ]);
    expect(list.value.itemsFor(null), list.value.items);
  });

  test('a source that is not connected is not listed', () async {
    await grant1(<StatusSource>{StatusSource.business});
    await list.refresh();
    expect(names(list.value.items), <String>['biz.jpg']);
    expect(repository.listCalls, 1);
  });

  test('every source failing is the error phase', () async {
    await grantBoth();
    repository.listErrors[StatusSource.standard] = const AppError(
      AppErrorKind.io,
    );
    repository.listErrors[StatusSource.business] = const AppError(
      AppErrorKind.io,
    );
    await list.refresh();
    expect(list.value.phase, ListPhase.error);
    expect(list.value.error?.kind, AppErrorKind.io);
    expect(list.value.items, isEmpty);
  });

  test('one source failing still shows the other, and remembers why', () async {
    await grantBoth();
    repository.listErrors[StatusSource.business] = const AppError(
      AppErrorKind.io,
    );
    await list.refresh();
    expect(list.value.phase, ListPhase.ready);
    expect(names(list.value.items), <String>['clip.mp4', 'new.jpg', 'old.jpg']);
    expect(list.value.errors.keys, <StatusSource>[StatusSource.business]);
    expect(list.value.errors[StatusSource.business]?.kind, AppErrorKind.io);
  });

  test('a single connected source that fails is the error phase', () async {
    await grant1(<StatusSource>{StatusSource.standard});
    repository.listErrors[StatusSource.standard] = const AppError(
      AppErrorKind.io,
    );
    await list.refresh();
    expect(list.value.phase, ListPhase.error);
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
      expect(list.value.items, hasLength(4));

      gate.complete();
      await pending;
      expect(list.value.refreshing, isFalse);
      expect(names(list.value.items), <String>['only.jpg', 'biz.jpg']);
    });

    test('a total failure keeps the old list', () async {
      repository.listErrors[StatusSource.standard] = const AppError(
        AppErrorKind.io,
      );
      repository.listErrors[StatusSource.business] = const AppError(
        AppErrorKind.io,
      );
      await list.refresh(silent: true);
      expect(list.value.phase, ListPhase.ready);
      expect(list.value.refreshing, isFalse);
      expect(list.value.items, hasLength(4));
    });

    test('an unchanged result does not replace the state', () async {
      final StatusListState before = list.value;
      await list.refresh(silent: true);
      expect(list.value.items, before.items);
      expect(list.value.refreshing, isFalse);
    });

    test('a new status in either source shows up', () async {
      repository.itemsBySource[StatusSource.business] = <StatusItem>[
        statusItem('biz.jpg', modifiedMs: 250),
        statusItem('fresh.jpg', modifiedMs: 999),
      ];
      await list.refresh(silent: true);
      expect(list.value.items.first.name, 'fresh.jpg');
      expect(list.value.items.first.source, StatusSource.business);
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
    test('when every source lost it: calls the callback and shows the error', () async {
      await grantBoth();
      int calls = 0;
      list.onAccessLost = () => calls++;
      repository.listErrors[StatusSource.standard] = const AppError(
        AppErrorKind.accessLost,
      );
      repository.listErrors[StatusSource.business] = const AppError(
        AppErrorKind.accessLost,
      );
      await list.refresh();
      expect(calls, 1);
      expect(list.value.phase, ListPhase.error);
      expect(list.value.error?.kind, AppErrorKind.accessLost);
    });

    test('when one source lost it: the callback fires and the other still shows', () async {
      await grantBoth();
      int calls = 0;
      list.onAccessLost = () => calls++;
      repository.listErrors[StatusSource.standard] = const AppError(
        AppErrorKind.accessLost,
      );
      await list.refresh();
      expect(calls, 1);
      expect(list.value.phase, ListPhase.ready);
      expect(names(list.value.items), <String>['biz.jpg']);
      expect(
        list.value.errors[StatusSource.standard]?.kind,
        AppErrorKind.accessLost,
      );
    });

    test('also when it happens during a silent refresh', () async {
      await grant1(<StatusSource>{StatusSource.standard});
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
    test('a slow earlier request loses to a newer one', () async {
      await grantBoth();
      final Completer<void> slow = Completer<void>();
      repository.listGates[StatusSource.standard] = slow;
      final Future<void> first = list.refresh();

      repository.listGates.remove(StatusSource.standard);
      repository.itemsBySource[StatusSource.standard] = <StatusItem>[
        statusItem('fresh.jpg', modifiedMs: 1),
      ];
      await list.refresh();
      expect(names(list.value.items), <String>['biz.jpg', 'fresh.jpg']);

      repository.itemsBySource[StatusSource.standard] = <StatusItem>[
        statusItem('stale.jpg'),
      ];
      slow.complete();
      await first;
      expect(names(list.value.items), <String>['biz.jpg', 'fresh.jpg']);
    });
  });

  test('disconnecting a source and refreshing drops its items', () async {
    await grantBoth();
    await list.refresh();
    await grant1(<StatusSource>{StatusSource.standard});
    await list.refresh();
    expect(list.value.countFor(StatusSource.business), 0);
    expect(list.value.items, hasLength(3));
  });

  test('losing every grant goes idle', () async {
    await grantBoth();
    await list.refresh();
    await grant1(<StatusSource>{});
    await list.refresh();
    expect(list.value.phase, ListPhase.idle);
    expect(list.value.items, isEmpty);
  });
}
