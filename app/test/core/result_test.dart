import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/result.dart';

void main() {
  const AppError failure = AppError(AppErrorKind.io, detail: 'x');

  test('Ok exposes its value', () {
    const Result<int> result = Ok<int>(4);
    expect(result.isOk, isTrue);
    expect(result.valueOrNull, 4);
    expect(result.errorOrNull, isNull);
  });

  test('Err exposes its error', () {
    const Result<int> result = Err<int>(failure);
    expect(result.isOk, isFalse);
    expect(result.valueOrNull, isNull);
    expect(result.errorOrNull, same(failure));
  });

  test('when folds both cases', () {
    const Result<int> good = Ok<int>(2);
    const Result<int> bad = Err<int>(failure);
    expect(good.when(ok: (int v) => 'ok $v', err: (AppError e) => 'err'), 'ok 2');
    expect(
      bad.when(ok: (int v) => 'ok', err: (AppError e) => 'err ${e.kind.name}'),
      'err io',
    );
  });

  test('map transforms success and passes failure through', () {
    const Result<int> good = Ok<int>(2);
    const Result<int> bad = Err<int>(failure);
    expect(good.map((int v) => v * 10).valueOrNull, 20);
    expect(bad.map((int v) => v * 10).errorOrNull, same(failure));
  });

  test('a void result works', () {
    const Result<void> result = Ok<void>(null);
    expect(result.isOk, isTrue);
  });
}
