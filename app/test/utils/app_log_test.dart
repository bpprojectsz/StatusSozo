import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/utils/app_log.dart';

void main() {
  setUp(AppLog.clear);

  test('starts empty', () {
    expect(AppLog.report(), isEmpty);
  });

  test('records level, tag and message', () {
    AppLog.info('saf', 'listed 3');
    AppLog.warn('saf', 'slow');
    AppLog.error('saf', 'failed', StateError('boom'));
    final List<String> lines = AppLog.report().split('\n');
    expect(lines, hasLength(3));
    expect(lines[0], contains('I/saf: listed 3'));
    expect(lines[1], contains('W/saf: slow'));
    expect(lines[2], contains('E/saf: failed | Bad state: boom'));
  });

  test('keeps only the last 50 lines', () {
    for (int i = 0; i < 80; i++) {
      AppLog.info('t', 'line $i');
    }
    final List<String> lines = AppLog.report().split('\n');
    expect(lines, hasLength(AppLog.capacity));
    expect(lines.first, contains('line 30'));
    expect(lines.last, contains('line 79'));
  });

  test('clear empties the buffer', () {
    AppLog.info('t', 'x');
    AppLog.clear();
    expect(AppLog.report(), isEmpty);
  });
}
