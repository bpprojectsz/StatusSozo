import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/folder_grant.dart';
import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/result.dart';
import 'package:statussozo/platform/media_store_saved_repository.dart';
import 'package:statussozo/platform/saf_channel.dart';
import 'package:statussozo/platform/saf_status_repository.dart';

import '../fakes/fakes.dart';
import 'mock_saf.dart';

void main() {
  final MockSaf native = MockSaf();
  late SafChannel channel;

  setUp(() {
    native
      ..reset()
      ..install();
    channel = SafChannel();
  });
  tearDown(native.uninstall);

  Map<String, Object?> row(String name, String mime) => <String, Object?>{
    'uri': 'content://x/$name',
    'name': name,
    'mime': mime,
    'size': 10,
    'modified': 20,
  };

  group('SafStatusRepository.pickFolder', () {
    late SafStatusRepository repository;
    setUp(() => repository = SafStatusRepository(channel, nowMs: () => 12345));

    test('starts the picker at the source folder', () async {
      native.responder = (MethodCall call) => null;
      await repository.pickFolder(StatusSource.business);
      expect(native.calls.single.arguments, <String, Object?>{
        'initialUri': StatusSource.business.initialTreeUri,
      });
    });

    test('accepts a folder named .Statuses', () async {
      native.responder = (MethodCall call) => <String, Object?>{
        'uri': 'content://tree/ok',
        'name': AppConfig.statusFolderName,
      };
      final Result<FolderGrant> result = await repository.pickFolder(
        StatusSource.standard,
      );
      final FolderGrant? grant = result.valueOrNull;
      expect(grant?.source, StatusSource.standard);
      expect(grant?.treeUri, 'content://tree/ok');
      expect(grant?.grantedAtMs, 12345);
      expect(native.methods, <String>['pickFolder']);
    });

    test('releases and rejects any other folder', () async {
      native.responder = (MethodCall call) => call.method == 'pickFolder'
          ? <String, Object?>{'uri': 'content://tree/bad', 'name': 'Downloads'}
          : null;
      final Result<FolderGrant> result = await repository.pickFolder(
        StatusSource.standard,
      );
      expect(result.errorOrNull?.kind, AppErrorKind.wrongFolder);
      expect(native.methods, <String>['pickFolder', 'releaseFolder']);
      expect(native.calls.last.arguments, <String, Object?>{
        'uri': 'content://tree/bad',
      });
    });

    test('a cancelled picker is pickerCancelled', () async {
      native.responder = (MethodCall call) => null;
      final Result<FolderGrant> result = await repository.pickFolder(
        StatusSource.standard,
      );
      expect(result.errorOrNull?.kind, AppErrorKind.pickerCancelled);
      expect(native.methods, <String>['pickFolder']);
    });

    test('a native failure is passed through', () async {
      native.responder = (MethodCall call) =>
          throw PlatformException(code: 'IO');
      final Result<FolderGrant> result = await repository.pickFolder(
        StatusSource.standard,
      );
      expect(result.errorOrNull?.kind, AppErrorKind.io);
    });
  });

  group('SafStatusRepository access and listing', () {
    const FolderGrant grant = FolderGrant(
      source: StatusSource.standard,
      treeUri: 'content://tree/1',
      grantedAtMs: 1,
    );
    late SafStatusRepository repository;
    setUp(() => repository = SafStatusRepository(channel));

    test('hasAccess and release use the tree uri', () async {
      native.responder = (MethodCall call) => true;
      expect(await repository.hasAccess(grant), isTrue);
      await repository.release(grant);
      expect(native.methods, <String>['hasAccess', 'releaseFolder']);
      expect(native.calls[0].arguments, <String, Object?>{
        'uri': 'content://tree/1',
      });
      expect(native.calls[1].arguments, <String, Object?>{
        'uri': 'content://tree/1',
      });
    });

    test('list maps rows to items', () async {
      native.responder = (MethodCall call) => <Object?>[
        row('a.jpg', 'image/jpeg'),
        row('b.mp4', 'video/mp4'),
      ];
      final Result<List<StatusItem>> result = await repository.list(grant);
      final List<StatusItem> items = result.valueOrNull!;
      expect(items.map((StatusItem i) => i.name), <String>['a.jpg', 'b.mp4']);
      expect(items.first.sizeBytes, 10);
      expect(items.first.modifiedMs, 20);
    });

    test('list drops unsupported mime types and malformed rows', () async {
      native.responder = (MethodCall call) => <Object?>[
        row('a.jpg', 'image/jpeg'),
        row('notes.txt', 'text/plain'),
        row('doc.pdf', 'application/pdf'),
        <String, Object?>{'name': 'no-uri.jpg', 'mime': 'image/jpeg'},
        <String, Object?>{
          'uri': 'content://x/bad',
          'name': 'bad.jpg',
          'mime': 'image/jpeg',
          'size': 'huge',
          'modified': 1,
        },
      ];
      final Result<List<StatusItem>> result = await repository.list(grant);
      expect(result.valueOrNull!.map((StatusItem i) => i.name), <String>[
        'a.jpg',
      ]);
    });

    test('list passes errors through', () async {
      native.responder = (MethodCall call) =>
          throw PlatformException(code: 'ACCESS_LOST');
      final Result<List<StatusItem>> result = await repository.list(grant);
      expect(result.errorOrNull?.kind, AppErrorKind.accessLost);
    });
  });

  group('MediaStoreSavedRepository', () {
    late MediaStoreSavedRepository repository;
    setUp(() => repository = MediaStoreSavedRepository(channel));

    test('save sends the item and the configured subfolder', () async {
      native.responder = (MethodCall call) => <String, Object?>{
        'uri': 'content://media/1',
        'name': 'a.jpg',
        'mime': 'image/jpeg',
        'size': 10,
        'added': 777,
      };
      final Result<SavedItem> result = await repository.save(
        statusItem('a.jpg', uri: 'content://status/a'),
      );
      expect(native.calls.single.method, 'saveToGallery');
      expect(native.calls.single.arguments, <String, Object?>{
        'uri': 'content://status/a',
        'name': 'a.jpg',
        'mime': 'image/jpeg',
        'subfolder': AppConfig.saveSubfolder,
      });
      expect(result.valueOrNull?.uri, 'content://media/1');
      expect(result.valueOrNull?.savedAtMs, 777);
    });

    test('save passes native errors through', () async {
      native.responder = (MethodCall call) =>
          throw PlatformException(code: 'IO');
      final Result<SavedItem> result = await repository.save(
        statusItem('a.jpg'),
      );
      expect(result.errorOrNull?.kind, AppErrorKind.io);
    });

    test('save with a malformed reply is unexpected', () async {
      native.responder = (MethodCall call) => <String, Object?>{'uri': 'x'};
      final Result<SavedItem> result = await repository.save(
        statusItem('a.jpg'),
      );
      expect(result.errorOrNull?.kind, AppErrorKind.unexpected);
    });

    test('list maps rows and drops bad ones', () async {
      native.responder = (MethodCall call) => <Object?>[
        <String, Object?>{
          'uri': 'content://media/1',
          'name': 'a.jpg',
          'mime': 'image/jpeg',
          'size': 1,
          'added': 2,
        },
        <String, Object?>{
          'uri': 'content://media/2',
          'name': 'x.bin',
          'mime': 'application/octet-stream',
          'size': 1,
          'added': 2,
        },
      ];
      final Result<List<SavedItem>> result = await repository.list();
      expect(native.calls.single.arguments, <String, Object?>{
        'subfolder': AppConfig.saveSubfolder,
      });
      expect(result.valueOrNull!.map((SavedItem i) => i.name), <String>[
        'a.jpg',
      ]);
    });

    test('list passes errors through', () async {
      native.responder = (MethodCall call) =>
          throw PlatformException(code: 'IO');
      final Result<List<SavedItem>> result = await repository.list();
      expect(result.errorOrNull?.kind, AppErrorKind.io);
    });

    test('delete succeeds when the native side deleted the row', () async {
      native.responder = (MethodCall call) => true;
      final Result<void> result = await repository.delete(savedItem('a.jpg'));
      expect(result.isOk, isTrue);
      expect(native.calls.single.method, 'deleteSaved');
    });

    test('delete reports notFound when nothing was deleted', () async {
      native.responder = (MethodCall call) => false;
      final Result<void> result = await repository.delete(savedItem('a.jpg'));
      expect(result.errorOrNull?.kind, AppErrorKind.notFound);
    });

    test('delete maps PERMISSION_LOST to permissionLost', () async {
      native.responder = (MethodCall call) =>
          throw PlatformException(code: 'PERMISSION_LOST');
      final Result<void> result = await repository.delete(savedItem('a.jpg'));
      expect(result.errorOrNull?.kind, AppErrorKind.permissionLost);
    });
  });
}
