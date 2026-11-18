import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/contracts/storage_space.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/services/storage_check.dart';

import '../fakes/fakes.dart';

void main() {
  const int margin = AppConfig.lowStorageMarginBytes;
  late FakeStorageSpace storage;

  setUp(() => storage = FakeStorageSpace());

  Future<AppError?> check(int needed, {StorageTarget? target}) => lowStorageError(
    storage,
    target ?? StorageTarget.gallery,
    needed,
  );

  test('the margin is 50 MB', () {
    expect(margin, 50 * 1024 * 1024);
  });

  test('there is room when free space covers the need plus the margin', () async {
    storage.free = 1000 + margin;
    expect(await check(1000), isNull);
  });

  test('one byte short is low storage', () async {
    storage.free = 1000 + margin - 1;
    final AppError? error = await check(1000);
    expect(error?.kind, AppErrorKind.lowStorage);
    expect(error?.detail, contains('free'));
  });

  test('an unknown amount of free space never blocks', () async {
    storage.free = null;
    expect(await check(1 << 40), isNull);
  });

  test('a failing read never blocks', () async {
    storage.throwOnRead = true;
    expect(await check(1 << 40), isNull);
  });

  test('no storage port, or nothing to write, never blocks', () async {
    expect(await lowStorageError(null, StorageTarget.gallery, 1 << 40), isNull);
    storage.free = 0;
    expect(await check(0), isNull);
  });

  test('it asks about the target it was given', () async {
    await check(10, target: StorageTarget.cache);
    expect(storage.asked, <StorageTarget>[StorageTarget.cache]);
  });
}
