
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/result.dart';
import 'package:statussozo/platform/native_thumbnail_source.dart';
import 'package:statussozo/platform/saf_channel.dart';

import '../fakes/fakes.dart';
import 'mock_saf.dart';

void main() {
  final MockSaf native = MockSaf();
  late NativeThumbnailSource source;

  setUp(() {
    native
      ..reset()
      ..install();
    native.responder = (MethodCall call) => Uint8List.fromList(<int>[1, 2, 3]);
    source = NativeThumbnailSource(SafChannel(), capacity: 3);
  });
  tearDown(native.uninstall);

  test('asks the native side once per (uri, px)', () async {
    final Uint8List? first = await source.thumbnail(statusItem('a.jpg'), 256);
    final Uint8List? second = await source.thumbnail(statusItem('a.jpg'), 256);
    expect(native.calls, hasLength(1));
    expect(identical(first, second), isTrue);
  });

  test('a different px is a different entry', () async {
    await source.thumbnail(statusItem('a.jpg'), 256);
    await source.thumbnail(statusItem('a.jpg'), 128);
    expect(native.calls, hasLength(2));
  });

  test('sends uri, mime and px', () async {
    await source.thumbnail(
      statusItem('a.mp4', mime: 'video/mp4', uri: 'content://v'),
      256,
    );
    expect(native.calls.single.arguments, <String, Object?>{
      'uri': 'content://v',
      'mime': 'video/mp4',
      'px': 256,
    });
  });

  test('evicts the least recently used entry beyond capacity', () async {
    await source.thumbnail(statusItem('a.jpg'), 256);
    await source.thumbnail(statusItem('b.jpg'), 256);
    await source.thumbnail(statusItem('c.jpg'), 256);
    await source.thumbnail(statusItem('a.jpg'), 256); // refresh a
    await source.thumbnail(statusItem('d.jpg'), 256); // evicts b
    expect(source.cacheSize, 3);
    native.calls.clear();
    await source.thumbnail(statusItem('a.jpg'), 256);
    await source.thumbnail(statusItem('c.jpg'), 256);
    await source.thumbnail(statusItem('d.jpg'), 256);
    expect(native.calls, isEmpty);
    await source.thumbnail(statusItem('b.jpg'), 256);
    expect(native.calls, hasLength(1));
  });

  test('a failed decode is not cached, so it can be retried', () async {
    native.responder = (MethodCall call) => null;
    expect(await source.thumbnail(statusItem('a.jpg'), 256), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(source.cacheSize, 0);
    native.responder = (MethodCall call) => Uint8List.fromList(<int>[9]);
    expect(await source.thumbnail(statusItem('a.jpg'), 256), isNotNull);
    expect(native.calls, hasLength(2));
  });

  test('the default capacity comes from AppConfig', () {
    expect(AppConfig.thumbnailCacheEntries, 200);
  });

  group('readImage', () {
    test('requests the file with the configured byte limit', () async {
      native.responder = (MethodCall call) => Uint8List.fromList(<int>[5, 6]);
      final Result<Uint8List> result = await source.readImage(
        statusItem('a.jpg', uri: 'content://a'),
      );
      expect(native.calls.single.method, 'readBytes');
      expect(native.calls.single.arguments, <String, Object?>{
        'uri': 'content://a',
        'maxBytes': AppConfig.imageMaxBytes,
      });
      expect(result.valueOrNull, Uint8List.fromList(<int>[5, 6]));
    });

    test('refuses oversized files without calling native', () async {
      final Result<Uint8List> result = await source.readImage(
        statusItem('big.jpg', sizeBytes: AppConfig.imageMaxBytes + 1),
      );
      expect(result.errorOrNull?.kind, AppErrorKind.io);
      expect(result.errorOrNull?.detail, contains('TOO_LARGE'));
      expect(native.calls, isEmpty);
    });

    test('passes native errors through', () async {
      native.responder = (MethodCall call) =>
          throw PlatformException(code: 'NOT_FOUND');
      final Result<Uint8List> result = await source.readImage(
        statusItem('a.jpg'),
      );
      expect(result.errorOrNull?.kind, AppErrorKind.notFound);
    });
  });
}
