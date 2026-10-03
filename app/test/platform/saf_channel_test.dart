
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/result.dart';
import 'package:statussozo/platform/saf_channel.dart';

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

  Map<Object?, Object?> asWire(Map<String, Object?> map) =>
      Map<Object?, Object?>.of(map);

  group('wire format', () {
    test('uses the agreed channel name', () {
      expect(SafChannel.channelName, 'statussozo/saf');
    });

    test('pickFolder sends initialUri and parses the reply', () async {
      native.responder = (MethodCall call) =>
          <String, Object?>{'uri': 'content://tree/1', 'name': '.Statuses'};
      final Result<PickedFolder?> result = await channel.pickFolder(
        initialUri: 'content://start',
      );
      expect(native.calls.single.method, 'pickFolder');
      expect(native.calls.single.arguments, <String, Object?>{
        'initialUri': 'content://start',
      });
      final PickedFolder? folder = result.valueOrNull;
      expect(folder?.uri, 'content://tree/1');
      expect(folder?.name, '.Statuses');
    });

    test('pickFolder returns Ok(null) when cancelled', () async {
      native.responder = (MethodCall call) => null;
      final Result<PickedFolder?> result = await channel.pickFolder();
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isNull);
      expect(native.calls.single.arguments, <String, Object?>{
        'initialUri': null,
      });
    });

    test('hasAccess sends uri and returns the bool', () async {
      native.responder = (MethodCall call) => true;
      expect(await channel.hasAccess('content://t'), isTrue);
      expect(native.calls.single.method, 'hasAccess');
      expect(native.calls.single.arguments, <String, Object?>{
        'uri': 'content://t',
      });
      native.responder = (MethodCall call) => false;
      expect(await channel.hasAccess('content://t'), isFalse);
    });

    test('hasAccess is false when the native call fails', () async {
      native.responder = (MethodCall call) =>
          throw PlatformException(code: 'IO');
      expect(await channel.hasAccess('content://t'), isFalse);
    });

    test('releaseFolder sends uri and swallows errors', () async {
      native.responder = (MethodCall call) =>
          throw PlatformException(code: 'IO');
      await channel.releaseFolder('content://t');
      expect(native.calls.single.method, 'releaseFolder');
      expect(native.calls.single.arguments, <String, Object?>{
        'uri': 'content://t',
      });
    });

    test('listFolder sends uri and parses rows', () async {
      native.responder = (MethodCall call) => <Object?>[
        asWire(<String, Object?>{
          'uri': 'content://a',
          'name': 'a.jpg',
          'mime': 'image/jpeg',
          'size': 10,
          'modified': 20,
        }),
      ];
      final Result<List<Map<String, Object?>>> result = await channel
          .listFolder('content://t');
      expect(native.calls.single.method, 'listFolder');
      expect(native.calls.single.arguments, <String, Object?>{
        'uri': 'content://t',
      });
      expect(result.valueOrNull, hasLength(1));
      expect(result.valueOrNull!.single['name'], 'a.jpg');
      expect(result.valueOrNull!.single['size'], 10);
    });

    test('thumbnail sends uri, mime and px', () async {
      final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);
      native.responder = (MethodCall call) => bytes;
      final Uint8List? result = await channel.thumbnail(
        uri: 'content://a',
        mime: 'image/png',
        px: 256,
      );
      expect(native.calls.single.method, 'thumbnail');
      expect(native.calls.single.arguments, <String, Object?>{
        'uri': 'content://a',
        'mime': 'image/png',
        'px': 256,
      });
      expect(result, bytes);
    });

    test('thumbnail returns null when undecodable or on error', () async {
      native.responder = (MethodCall call) => null;
      expect(
        await channel.thumbnail(uri: 'u', mime: 'image/png', px: 1),
        isNull,
      );
      native.responder = (MethodCall call) =>
          throw PlatformException(code: 'IO');
      expect(
        await channel.thumbnail(uri: 'u', mime: 'image/png', px: 1),
        isNull,
      );
    });

    test('readBytes sends uri and maxBytes', () async {
      final Uint8List bytes = Uint8List.fromList(<int>[7, 8]);
      native.responder = (MethodCall call) => bytes;
      final Result<Uint8List> result = await channel.readBytes(
        uri: 'content://a',
        maxBytes: 1000,
      );
      expect(native.calls.single.method, 'readBytes');
      expect(native.calls.single.arguments, <String, Object?>{
        'uri': 'content://a',
        'maxBytes': 1000,
      });
      expect(result.valueOrNull, bytes);
    });

    test('saveToGallery sends all four arguments', () async {
      native.responder = (MethodCall call) => asWire(<String, Object?>{
        'uri': 'content://media/1',
        'name': 'a.jpg',
        'mime': 'image/jpeg',
        'size': 5,
        'added': 99,
      });
      final Result<Map<String, Object?>> result = await channel.saveToGallery(
        uri: 'content://a',
        name: 'a.jpg',
        mime: 'image/jpeg',
        subfolder: 'StatusSozo',
      );
      expect(native.calls.single.method, 'saveToGallery');
      expect(native.calls.single.arguments, <String, Object?>{
        'uri': 'content://a',
        'name': 'a.jpg',
        'mime': 'image/jpeg',
        'subfolder': 'StatusSozo',
      });
      expect(result.valueOrNull!['added'], 99);
    });

    test('listSaved sends subfolder', () async {
      native.responder = (MethodCall call) => <Object?>[];
      final Result<List<Map<String, Object?>>> result = await channel
          .listSaved('StatusSozo');
      expect(native.calls.single.method, 'listSaved');
      expect(native.calls.single.arguments, <String, Object?>{
        'subfolder': 'StatusSozo',
      });
      expect(result.valueOrNull, isEmpty);
    });

    test('deleteSaved sends uri and returns the bool', () async {
      native.responder = (MethodCall call) => true;
      final Result<bool> result = await channel.deleteSaved('content://m/1');
      expect(native.calls.single.method, 'deleteSaved');
      expect(native.calls.single.arguments, <String, Object?>{
        'uri': 'content://m/1',
      });
      expect(result.valueOrNull, isTrue);
    });

    test('copyToCache sends uri and name and returns the path', () async {
      native.responder = (MethodCall call) => '/cache/share/a.jpg';
      final Result<String> result = await channel.copyToCache(
        uri: 'content://a',
        name: 'a.jpg',
      );
      expect(native.calls.single.method, 'copyToCache');
      expect(native.calls.single.arguments, <String, Object?>{
        'uri': 'content://a',
        'name': 'a.jpg',
      });
      expect(result.valueOrNull, '/cache/share/a.jpg');
    });

    test('pruneShareCache sends olderThanMs and returns the count', () async {
      native.responder = (MethodCall call) => 4;
      expect(await channel.pruneShareCache(86400000), 4);
      expect(native.calls.single.method, 'pruneShareCache');
      expect(native.calls.single.arguments, <String, Object?>{
        'olderThanMs': 86400000,
      });
    });
  });

  group('native error codes', () {
    const Map<String, AppErrorKind> expected = <String, AppErrorKind>{
      'ACCESS_LOST': AppErrorKind.accessLost,
      'NOT_FOUND': AppErrorKind.notFound,
      'IO': AppErrorKind.io,
      'PERMISSION_LOST': AppErrorKind.permissionLost,
      'TOO_LARGE': AppErrorKind.io,
      'UNSUPPORTED': AppErrorKind.unsupported,
      'SOMETHING_ELSE': AppErrorKind.unexpected,
    };
    expected.forEach((String code, AppErrorKind kind) {
      test('$code becomes ${kind.name}', () async {
        native.responder = (MethodCall call) =>
            throw PlatformException(code: code, message: 'native said so');
        final Result<List<Map<String, Object?>>> result = await channel
            .listFolder('content://t');
        expect(result.errorOrNull?.kind, kind);
        expect(result.errorOrNull?.detail, contains(code));
      });
    });
  });

  group('failure containment', () {
    test('a missing native handler becomes unsupported', () async {
      native.uninstall();
      final Result<List<Map<String, Object?>>> result = await channel
          .listFolder('content://t');
      expect(result.errorOrNull?.kind, AppErrorKind.unsupported);
    });

    test('a malformed payload becomes unexpected', () async {
      native.responder = (MethodCall call) => 'not a list';
      final Result<List<Map<String, Object?>>> result = await channel
          .listFolder('content://t');
      expect(result.errorOrNull?.kind, AppErrorKind.unexpected);
    });

    test('a row that is not a map becomes unexpected', () async {
      native.responder = (MethodCall call) => <Object?>['oops'];
      final Result<List<Map<String, Object?>>> result = await channel
          .listFolder('content://t');
      expect(result.errorOrNull?.kind, AppErrorKind.unexpected);
    });

    test('a pick reply with missing fields becomes unexpected', () async {
      native.responder = (MethodCall call) => <String, Object?>{'uri': 'x'};
      final Result<PickedFolder?> result = await channel.pickFolder();
      expect(result.errorOrNull?.kind, AppErrorKind.unexpected);
    });

    test('readBytes with a non-bytes reply becomes unexpected', () async {
      native.responder = (MethodCall call) => 'text';
      final Result<Uint8List> result = await channel.readBytes(
        uri: 'u',
        maxBytes: 1,
      );
      expect(result.errorOrNull?.kind, AppErrorKind.unexpected);
    });
  });
}
