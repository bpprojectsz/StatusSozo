import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/utils/formatters.dart';

void main() {
  group('formatFileSize', () {
    test('bytes', () {
      expect(formatFileSize(0, 'en'), '0 B');
      expect(formatFileSize(512, 'en'), '512 B');
      expect(formatFileSize(1023, 'en'), '1,023 B');
    });

    test('kilobytes', () {
      expect(formatFileSize(1024, 'en'), '1 KB');
      expect(formatFileSize(1536, 'en'), '1.5 KB');
    });

    test('megabytes and gigabytes', () {
      expect(formatFileSize(1572864, 'en'), '1.5 MB');
      expect(formatFileSize(5 * 1024 * 1024, 'en'), '5 MB');
      expect(formatFileSize(1073741824, 'en'), '1 GB');
    });

    test('rolls over instead of showing 1,024 KB', () {
      expect(formatFileSize(1048575, 'en'), '1 MB');
    });

    test('negative values show as zero', () {
      expect(formatFileSize(-5, 'en'), '0 B');
    });

    test('uses the locale decimal separator', () {
      expect(formatFileSize(1572864, 'de'), '1,5 MB');
      expect(formatFileSize(1572864, 'fr'), '1,5 MB');
    });
  });

  group('formatDuration', () {
    test('under a minute', () {
      expect(formatDuration(Duration.zero), '0:00');
      expect(formatDuration(const Duration(seconds: 9)), '0:09');
      expect(formatDuration(const Duration(seconds: 59)), '0:59');
    });

    test('minutes', () {
      expect(formatDuration(const Duration(seconds: 61)), '1:01');
      expect(formatDuration(const Duration(minutes: 12, seconds: 5)), '12:05');
    });

    test('over an hour', () {
      expect(formatDuration(const Duration(hours: 1)), '1:00:00');
      expect(
        formatDuration(const Duration(hours: 1, minutes: 2, seconds: 5)),
        '1:02:05',
      );
      expect(formatDuration(const Duration(minutes: 100)), '1:40:00');
    });

    test('negative durations show as zero', () {
      expect(formatDuration(const Duration(seconds: -4)), '0:00');
    });

    test('fractions of a second are dropped', () {
      expect(formatDuration(const Duration(milliseconds: 1999)), '0:01');
    });
  });

  group('formatCount', () {
    test('groups digits per locale', () {
      expect(formatCount(0, 'en'), '0');
      expect(formatCount(1234, 'en'), '1,234');
      expect(formatCount(1234567, 'en'), '1,234,567');
      expect(formatCount(1234, 'de'), '1.234');
    });
  });
}
