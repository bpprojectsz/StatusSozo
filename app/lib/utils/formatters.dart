import 'package:intl/intl.dart';

const List<String> _sizeUnits = <String>['B', 'KB', 'MB', 'GB'];

/// Formats a byte count: `0 B`, `512 B`, `1 KB`, `1.5 MB`. Binary units, at
/// most one decimal, numbers formatted for [locale].
String formatFileSize(int bytes, String locale) {
  double value = bytes < 0 ? 0 : bytes.toDouble();
  int unit = 0;
  while (unit < _sizeUnits.length - 1 && (value * 10).round() / 10 >= 1024) {
    value /= 1024;
    unit++;
  }
  final NumberFormat format = unit == 0
      ? NumberFormat.decimalPattern(locale)
      : NumberFormat('#,##0.#', locale);
  return '${format.format(value)} ${_sizeUnits[unit]}';
}

/// Formats a duration as `m:ss` or `h:mm:ss`. Always plain digits so tabular
/// figures line up. Negative durations show as zero.
String formatDuration(Duration duration) {
  final int total = duration.isNegative ? 0 : duration.inSeconds;
  final int hours = total ~/ 3600;
  final int minutes = (total % 3600) ~/ 60;
  final int seconds = total % 60;
  final String ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    final String mm = minutes.toString().padLeft(2, '0');
    return '$hours:$mm:$ss';
  }
  return '$minutes:$ss';
}

/// Formats a count with the grouping used by [locale].
String formatCount(int count, String locale) =>
    NumberFormat.decimalPattern(locale).format(count);
