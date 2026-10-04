import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/models/folder_grant.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/providers/folder_access_provider.dart';
import 'package:statussozo/core/providers/settings_provider.dart';
import 'package:statussozo/core/providers/source_provider.dart';
import 'package:statussozo/core/result.dart';

import '../../fakes/fakes.dart';

void main() {
  late FakeStatusRepository repository;
  late FakeSettingsStore store;
  late SettingsProvider settings;
  late SourceProvider source;
  late FolderAccessProvider access;

  FolderGrant grantFor(StatusSource s, {String? uri}) => FolderGrant(
    source: s,
    treeUri: uri ?? 'content://tree/${s.id}',
    grantedAtMs: 1,
  );

  Future<void> giveGrants(List<FolderGrant> grants) {
    return settings.update(
      (AppSettings s) => s.copyWith(
        grants: <StatusSource, FolderGrant>{
          for (final FolderGrant g in grants) g.source: g,
        },
      ),
    );
  }

  setUp(() async {
    repository = FakeStatusRepository();
    store = FakeSettingsStore();
    settings = SettingsProvider(store);
    await settings.load();
    source = SourceProvider(settings);
    access = FolderAccessProvider(
      repository: repository,
      settings: settings,
      source: source,
    );
  });
  tearDown(() {
    access.dispose();
    source.dispose();
    settings.dispose();
  });

  test('starts unknown for every source', () {
    for (final StatusSource s in StatusSource.values) {
      expect(access.value.statusOf(s), AccessStatus.unknown);
    }
    expect(access.hasUsableSource, isFalse);
    expect(access.value.connecting, isNull);
  });

  group('verifyAll', () {
    test('no grants means not connected', () async {
      await access.verifyAll();
      for (final StatusSource s in StatusSource.values) {
        expect(access.value.statusOf(s), AccessStatus.notConnected);
      }
    });

    test('a working grant is connected', () async {
      await giveGrants(<FolderGrant>[grantFor(StatusSource.standard)]);
      await access.verifyAll();
      expect(
        access.value.statusOf(StatusSource.standard),
        AccessStatus.connected,
      );
      expect(
        access.value.statusOf(StatusSource.business),
        AccessStatus.notConnected,
      );
      expect(access.hasUsableSource, isTrue);
      expect(access.connectedSources, <StatusSource>[StatusSource.standard]);
    });

    test('a grant that no longer works needs renewal', () async {
      await giveGrants(<FolderGrant>[
        grantFor(StatusSource.standard),
        grantFor(StatusSource.business),
      ]);
      repository.lostAccess.add(StatusSource.business);
      await access.verifyAll();
      expect(
        access.value.statusOf(StatusSource.standard),
        AccessStatus.connected,
      );
      expect(
        access.value.statusOf(StatusSource.business),
        AccessStatus.needsRenewal,
      );
    });

    test('the latest verification wins when two overlap', () async {
      await giveGrants(<FolderGrant>[grantFor(StatusSource.standard)]);
      repository.delay = const Duration(milliseconds: 20);
      final Future<void> first = access.verifyAll();
      repository.lostAccess.add(StatusSource.standard);
      final Future<void> second = access.verifyAll();
      await Future.wait<void>(<Future<void>>[first, second]);
      expect(
        access.value.statusOf(StatusSource.standard),
        AccessStatus.needsRenewal,
      );
    });
  });

  group('connect', () {
    test('success stores the grant and marks the source connected', () async {
      final AppError? error = await access.connect(StatusSource.standard);
      expect(error, isNull);
      expect(
        access.value.statusOf(StatusSource.standard),
        AccessStatus.connected,
      );
      expect(access.value.connecting, isNull);
      expect(
        settings.settings.grants[StatusSource.standard]?.treeUri,
        'content://tree/standard',
      );
      await Future<void>.delayed(Duration.zero);
      expect(store.stored.grants.keys, <StatusSource>[StatusSource.standard]);
    });

    test('selects the source when the current one is not usable', () async {
      expect(source.value, StatusSource.standard);
      await access.connect(StatusSource.business);
      expect(source.value, StatusSource.business);
    });

    test('keeps the current source when it is already connected', () async {
      await access.connect(StatusSource.standard);
      await access.connect(StatusSource.business);
      expect(source.value, StatusSource.standard);
      expect(access.connectedSources, StatusSource.values);
    });

    test('a cancelled picker returns the error and changes nothing', () async {
      repository.pickResult = const Err<FolderGrant>(
        AppError(AppErrorKind.pickerCancelled),
      );
      final AppError? error = await access.connect(StatusSource.standard);
      expect(error?.kind, AppErrorKind.pickerCancelled);
      expect(access.value.connecting, isNull);
      expect(settings.settings.grants, isEmpty);
      expect(
        access.value.statusOf(StatusSource.standard),
        AccessStatus.unknown,
      );
    });

    test('a wrong folder returns the error', () async {
      repository.pickResult = const Err<FolderGrant>(
        AppError(AppErrorKind.wrongFolder),
      );
      final AppError? error = await access.connect(StatusSource.standard);
      expect(error?.kind, AppErrorKind.wrongFolder);
      expect(settings.settings.grants, isEmpty);
    });

    test('shows which source is connecting while the picker is open', () async {
      repository.delay = const Duration(milliseconds: 20);
      final Future<AppError?> pending = access.connect(StatusSource.business);
      expect(access.value.connecting, StatusSource.business);
      await pending;
      expect(access.value.connecting, isNull);
    });

    test('a second connect while one is open is ignored', () async {
      repository.delay = const Duration(milliseconds: 20);
      final Future<AppError?> first = access.connect(StatusSource.standard);
      final AppError? second = await access.connect(StatusSource.business);
      await first;
      expect(second, isNull);
      expect(repository.pickCalls, 1);
    });

    test('reconnecting with a new folder releases the old grant', () async {
      final FolderGrant old = grantFor(StatusSource.standard, uri: 'content://old');
      await giveGrants(<FolderGrant>[old]);
      repository.pickResult = Ok<FolderGrant>(
        grantFor(StatusSource.standard, uri: 'content://new'),
      );
      await access.connect(StatusSource.standard);
      expect(repository.released, <FolderGrant>[old]);
      expect(
        settings.settings.grants[StatusSource.standard]?.treeUri,
        'content://new',
      );
    });
  });

  group('disconnect', () {
    test('releases the grant, removes it and marks not connected', () async {
      await access.connect(StatusSource.standard);
      await access.disconnect(StatusSource.standard);
      expect(repository.released, hasLength(1));
      expect(settings.settings.grants, isEmpty);
      expect(
        access.value.statusOf(StatusSource.standard),
        AccessStatus.notConnected,
      );
    });

    test('switches the selected source to another connected one', () async {
      await access.connect(StatusSource.standard);
      await access.connect(StatusSource.business);
      expect(source.value, StatusSource.standard);
      await access.disconnect(StatusSource.standard);
      expect(source.value, StatusSource.business);
    });

    test('keeps the selection when the other source is not connected', () async {
      await access.connect(StatusSource.standard);
      await access.disconnect(StatusSource.standard);
      expect(source.value, StatusSource.standard);
    });

    test('does nothing for a source without a grant', () async {
      await access.disconnect(StatusSource.business);
      expect(repository.released, isEmpty);
    });
  });

  test('state equality ignores identity', () {
    expect(FolderAccessState.initial(), FolderAccessState.initial());
    expect(
      FolderAccessState.initial().hashCode,
      FolderAccessState.initial().hashCode,
    );
    expect(
      FolderAccessState.initial().copyWith(connecting: StatusSource.business),
      isNot(FolderAccessState.initial()),
    );
  });
}
