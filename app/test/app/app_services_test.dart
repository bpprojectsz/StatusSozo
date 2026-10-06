import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/app/app_services.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/models/folder_grant.dart';
import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/providers/folder_access_provider.dart';
import 'package:statussozo/core/providers/status_list_provider.dart';
import 'package:statussozo/core/providers/toast_provider.dart';
import 'package:statussozo/core/result.dart';

import '../fakes/fakes.dart';

/// Records the order in which the bootstrap steps touch their dependencies.
class _LoggingStatusRepository extends FakeStatusRepository {
  _LoggingStatusRepository(this.log);

  final List<String> log;

  @override
  Future<bool> hasAccess(FolderGrant grant) {
    log.add('verify');
    return super.hasAccess(grant);
  }

  @override
  Future<Result<List<StatusItem>>> list(FolderGrant grant) {
    log.add('list');
    return super.list(grant);
  }
}

class _LoggingSavedRepository extends FakeSavedRepository {
  _LoggingSavedRepository(this.log);

  final List<String> log;

  @override
  Future<Result<List<SavedItem>>> list() {
    log.add('saved');
    return super.list();
  }
}

class _LoggingShare extends FakeShareService {
  _LoggingShare(this.log);

  final List<String> log;

  @override
  Future<void> pruneCache() {
    log.add('prune');
    return super.pruneCache();
  }
}

void main() {
  late FakeStatusRepository status;
  late FakeSavedRepository saved;
  late FakeSettingsStore store;
  late FakeShareService share;
  late FakeHapticsService haptics;
  late AppServices services;

  FolderGrant grantFor(StatusSource s) => FolderGrant(
    source: s,
    treeUri: 'content://tree/${s.id}',
    grantedAtMs: 1,
  );

  AppServices build({
    FakeStatusRepository? statusRepo,
    FakeSavedRepository? savedRepo,
    FakeShareService? shareService,
  }) {
    status = statusRepo ?? FakeStatusRepository();
    saved = savedRepo ?? FakeSavedRepository();
    share = shareService ?? FakeShareService();
    return AppServices.forTesting(
      statusRepository: status,
      savedRepository: saved,
      thumbnails: FakeThumbnailSource(),
      share: share,
      settingsStore: store,
      links: FakeLinkLauncher(),
      haptics: haptics,
      videoFactory: FakeVideoSessionFactory(),
    );
  }

  Future<void> giveGrants(List<StatusSource> sources) {
    return services.settings.update(
      (AppSettings s) => s.copyWith(
        grants: <StatusSource, FolderGrant>{
          for (final StatusSource src in sources) src: grantFor(src),
        },
      ),
    );
  }

  setUp(() {
    store = FakeSettingsStore();
    haptics = FakeHapticsService();
    services = build();
  });
  tearDown(() => services.dispose());

  test('exposes the contracts and the version it was given', () {
    expect(services.appVersion, '1.0.0 (1)');
    expect(services.statusRepository, same(status));
    expect(services.savedRepository, same(saved));
    expect(services.share, same(share));
    expect(services.haptics, same(haptics));
  });

  test('home and saved selection are separate instances', () {
    expect(identical(services.homeSelection, services.savedSelection), isFalse);
  });

  group('wiring', () {
    test('an access-lost list error triggers grant verification', () async {
      await giveGrants(<StatusSource>[StatusSource.standard]);
      await services.folderAccess.verifyAll();
      expect(
        services.folderAccess.value.statusOf(StatusSource.standard),
        AccessStatus.connected,
      );
      final int before = status.hasAccessCalls;

      status.lostAccess.add(StatusSource.standard);
      status.listErrors[StatusSource.standard] = const AppError(
        AppErrorKind.accessLost,
      );
      await services.statusList.refresh();
      await Future<void>.delayed(Duration.zero);

      expect(status.hasAccessCalls, greaterThan(before));
      expect(
        services.folderAccess.value.statusOf(StatusSource.standard),
        AccessStatus.needsRenewal,
      );
      expect(services.statusList.value.phase, ListPhase.error);
    });

    test('a failing save of settings produces exactly one sticky toast', () async {
      final List<ToastCode> shown = <ToastCode>[];
      services.toasts.addListener(() {
        final ToastMessage? message = services.toasts.value;
        if (message != null) {
          shown.add(message.code);
        }
      });
      await services.settings.load();
      store.failSave = true;

      await services.settings.update(
        (AppSettings s) => s.copyWith(themePreference: ThemePreference.dark),
      );
      await services.settings.update(
        (AppSettings s) => s.copyWith(themePreference: ThemePreference.light),
      );

      expect(shown, <ToastCode>[ToastCode.persistenceWarning]);
      expect(services.toasts.value?.sticky, isTrue);
    });

    test('after a successful save the warning can fire again later', () async {
      final List<ToastCode> shown = <ToastCode>[];
      services.toasts.addListener(() {
        final ToastMessage? message = services.toasts.value;
        if (message != null) {
          shown.add(message.code);
        }
      });
      await services.settings.load();
      store.failSave = true;
      await services.settings.update(
        (AppSettings s) => s.copyWith(themePreference: ThemePreference.dark),
      );
      store.failSave = false;
      await services.settings.update(
        (AppSettings s) => s.copyWith(themePreference: ThemePreference.light),
      );
      // Identical toasts inside one second are dropped on purpose, so wait for
      // that window to pass and clear the first sticky toast.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      services.toasts.dismiss();
      store.failSave = true;
      await services.settings.update(
        (AppSettings s) => s.copyWith(themePreference: ThemePreference.dark),
      );
      expect(
        shown.where((ToastCode c) => c == ToastCode.persistenceWarning),
        hasLength(2),
      );
    });

    test('a recovered store produces exactly one recovery toast', () async {
      final List<ToastCode> shown = <ToastCode>[];
      services.toasts.addListener(() {
        final ToastMessage? message = services.toasts.value;
        if (message != null) {
          shown.add(message.code);
        }
      });
      store.recovered = true;
      await services.settings.load();
      await services.settings.update(
        (AppSettings s) => s.copyWith(themePreference: ThemePreference.dark),
      );
      expect(shown, <ToastCode>[ToastCode.settingsRecovered]);
      expect(services.settings.value.recovered, isFalse);
    });

    test('a clean load produces no toast', () async {
      await services.settings.load();
      expect(services.toasts.value, isNull);
    });

    test('selection is pruned after a refresh removes items', () async {
      await giveGrants(<StatusSource>[StatusSource.standard]);
      final StatusItem a = statusItem('a.jpg');
      final StatusItem b = statusItem('b.jpg');
      status.itemsBySource[StatusSource.standard] = <StatusItem>[a, b];
      await services.statusList.refresh();
      services.homeSelection.selectAll(<String>[a.id, b.id]);
      expect(services.homeSelection.value.count, 2);

      status.itemsBySource[StatusSource.standard] = <StatusItem>[a];
      await services.statusList.refresh(silent: true);

      expect(services.homeSelection.value.ids, <String>{a.id});
    });

    test('selection mode ends when the list no longer holds any selected item', () async {
      await giveGrants(<StatusSource>[StatusSource.standard]);
      final StatusItem a = statusItem('a.jpg');
      status.itemsBySource[StatusSource.standard] = <StatusItem>[a];
      await services.statusList.refresh();
      services.homeSelection.toggle(a.id);
      status.itemsBySource[StatusSource.standard] = <StatusItem>[];
      await services.statusList.refresh(silent: true);
      expect(services.homeSelection.value.active, isFalse);
    });

    test('saved selection is pruned when the library changes', () async {
      final SavedItem x = savedItem('x.jpg');
      final SavedItem y = savedItem('y.jpg');
      services.savedLibrary.onSaved(<SavedItem>[x, y]);
      services.savedSelection.selectAll(<String>[x.id, y.id]);
      await services.savedLibrary.delete(<SavedItem>[x]);
      expect(services.savedSelection.value.ids, <String>{y.id});
    });

    test('changing the source clears the home selection', () async {
      await giveGrants(<StatusSource>[
        StatusSource.standard,
        StatusSource.business,
      ]);
      services.homeSelection.selectAll(<String>['a', 'b']);
      await services.source.select(StatusSource.business);
      expect(services.homeSelection.value.active, isFalse);
    });

    test('connecting a folder loads its list without a manual refresh', () async {
      await services.folderAccess.verifyAll();
      status.itemsBySource[StatusSource.standard] = <StatusItem>[
        statusItem('first.jpg'),
      ];
      final AppError? error = await services.folderAccess.connect(
        StatusSource.standard,
      );
      expect(error, isNull);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(services.statusList.value.phase, ListPhase.ready);
      expect(services.statusList.value.items, hasLength(1));
    });

    test('disconnecting the selected source empties its list', () async {
      await giveGrants(<StatusSource>[StatusSource.standard]);
      status.itemsBySource[StatusSource.standard] = <StatusItem>[
        statusItem('first.jpg'),
      ];
      await services.bootstrap();
      expect(services.statusList.value.items, hasLength(1));
      await services.folderAccess.disconnect(StatusSource.standard);
      await Future<void>.delayed(Duration.zero);
      expect(services.statusList.value.phase, ListPhase.idle);
      expect(services.statusList.value.items, isEmpty);
    });

    test('a successful save updates the library and shows one toast', () async {
      final List<ToastCode> shown = <ToastCode>[];
      services.toasts.addListener(() {
        final ToastMessage? message = services.toasts.value;
        if (message != null) {
          shown.add(message.code);
        }
      });
      await services.save.save(<StatusItem>[statusItem('a.jpg')]);
      expect(services.savedLibrary.value.names, <String>{'a.jpg'});
      expect(shown, <ToastCode>[ToastCode.saved]);
      expect(haptics.successCount, 1);
    });
  });

  group('bootstrap and refreshAll', () {
    test('bootstrap runs verify, list, saved library, then prune', () async {
      services.dispose();
      final List<String> log = <String>[];
      services = build(
        statusRepo: _LoggingStatusRepository(log),
        savedRepo: _LoggingSavedRepository(log),
        shareService: _LoggingShare(log),
      );
      await giveGrants(<StatusSource>[StatusSource.standard]);
      log.clear();

      await services.bootstrap();

      expect(
        log.where((String e) => e != 'verify' || log.indexOf(e) == log.indexOf('verify')),
        <String>['verify', 'list', 'saved', 'prune'],
      );
      expect(log.last, 'prune');
      expect(log.indexOf('verify'), lessThan(log.indexOf('list')));
      expect(log.indexOf('list'), lessThan(log.indexOf('saved')));
      expect(log.indexOf('saved'), lessThan(log.indexOf('prune')));
    });

    test('bootstrap with no grants leaves everything idle but still prunes', () async {
      await services.bootstrap();
      expect(services.statusList.value.phase, ListPhase.idle);
      expect(
        services.folderAccess.value.statusOf(StatusSource.standard),
        AccessStatus.notConnected,
      );
      expect(share.pruneCalls, 1);
      expect(services.savedLibrary.value.phase, ListPhase.ready);
    });

    test('bootstrap loads the list and the saved library', () async {
      await giveGrants(<StatusSource>[StatusSource.standard]);
      status.itemsBySource[StatusSource.standard] = <StatusItem>[
        statusItem('one.jpg'),
        statusItem('two.mp4', mime: 'video/mp4'),
      ];
      saved.items.add(savedItem('old.jpg'));
      await services.bootstrap();
      expect(services.statusList.value.phase, ListPhase.ready);
      expect(services.statusList.value.photos, hasLength(1));
      expect(services.statusList.value.videos, hasLength(1));
      expect(services.savedLibrary.value.names, <String>{'old.jpg'});
    });

    test('bootstrap lists exactly once at startup', () async {
      await giveGrants(<StatusSource>[StatusSource.standard]);
      await services.bootstrap();
      await Future<void>.delayed(Duration.zero);
      expect(status.listCalls, 1);
    });

    test('refreshAll re-verifies and keeps the old list while refreshing', () async {
      await giveGrants(<StatusSource>[StatusSource.standard]);
      status.itemsBySource[StatusSource.standard] = <StatusItem>[
        statusItem('one.jpg'),
      ];
      await services.bootstrap();

      status.itemsBySource[StatusSource.standard] = <StatusItem>[
        statusItem('one.jpg'),
        statusItem('two.jpg'),
      ];
      final Future<void> refresh = services.refreshAll();
      await Future<void>.delayed(Duration.zero);
      expect(services.statusList.value.items, isNotEmpty);
      await refresh;
      expect(services.statusList.value.items, hasLength(2));
      expect(status.hasAccessCalls, greaterThanOrEqualTo(2));
    });

    test('refreshAll notices lost access', () async {
      await giveGrants(<StatusSource>[StatusSource.standard]);
      await services.bootstrap();
      status.lostAccess.add(StatusSource.standard);
      await services.refreshAll();
      expect(
        services.folderAccess.value.statusOf(StatusSource.standard),
        AccessStatus.needsRenewal,
      );
    });
  });

  test('dispose can be called twice without error', () {
    services.dispose();
    services.dispose();
    expect(services.toasts.value, isNull);
  });
}
