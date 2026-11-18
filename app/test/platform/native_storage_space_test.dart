import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/contracts/storage_space.dart';
import 'package:statussozo/platform/native_storage_space.dart';
import 'package:statussozo/platform/saf_channel.dart';

import 'mock_saf.dart';

void main() {
  late MockSaf native;

  setUp(() {
    native = MockSaf()..install();
  });
  tearDown(native.uninstall);

  test('the gallery is asked as "gallery" and the cache as "cache"', () async {
    native.responder = (MethodCall call) => 4096;
    final NativeStorageSpace space = NativeStorageSpace(SafChannel());
    expect(await space.freeBytes(StorageTarget.gallery), 4096);
    expect(await space.freeBytes(StorageTarget.cache), 4096);
    expect(
      native.calls.map((MethodCall c) => (c.arguments as Map<Object?, Object?>)['target']),
      <Object?>['gallery', 'cache'],
    );
  });

  test('an unreadable amount is null', () async {
    native.responder = (MethodCall call) => null;
    expect(
      await NativeStorageSpace(SafChannel()).freeBytes(StorageTarget.gallery),
      isNull,
    );
  });
}
