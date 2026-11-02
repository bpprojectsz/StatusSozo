import 'package:flutter/foundation.dart';

/// Local-only diagnostics: a ring buffer of the last 50 lines. Nothing leaves
/// the device unless the person sends the "Report a problem" email.
abstract final class AppLog {
  static const int capacity = 50;

  static final List<String> _lines = <String>[];

  /// Bumped whenever the buffer changes, so screens can rebuild.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void info(String tag, String message, [Object? error]) =>
      _add('I', tag, message, error);

  static void warn(String tag, String message, [Object? error]) =>
      _add('W', tag, message, error);

  static void error(String tag, String message, [Object? error]) =>
      _add('E', tag, message, error);

  /// The buffered lines as text, oldest first.
  static String report() => _lines.join('\n');

  /// The buffered lines, oldest first.
  static List<String> get entries => List<String>.unmodifiable(_lines);

  /// How many lines are buffered.
  static int get count => _lines.length;

  /// Empties the buffer.
  static void clear() {
    _lines.clear();
    revision.value++;
  }

  static void _add(String level, String tag, String message, Object? error) {
    final String stamp = DateTime.now().toUtc().toIso8601String();
    final String suffix = error == null ? '' : ' | $error';
    final String line = '$stamp $level/$tag: $message$suffix';
    _lines.add(line);
    if (_lines.length > capacity) {
      _lines.removeRange(0, _lines.length - capacity);
    }
    revision.value++;
    if (kDebugMode) {
      debugPrint(line);
    }
  }
}
