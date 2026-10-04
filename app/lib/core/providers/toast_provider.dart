import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:statussozo/core/app_config.dart';

enum ToastKind { success, info, warning, error }

/// Every message the app can toast. The UI turns a code into localised text;
/// providers never hold display text.
enum ToastCode {
  saved,
  savedPartial,
  alreadySaved,
  saveFailed,
  deleted,
  deleteFailed,
  shareFailed,
  folderConnected,
  folderDisconnected,
  wrongFolder,
  pickerCancelled,
  accessLost,
  settingsRecovered,
  persistenceWarning,
  linkFailed,
  ioError,
  unexpected,
}

@immutable
class ToastMessage {
  const ToastMessage({
    required this.id,
    required this.kind,
    required this.code,
    this.count,
    this.secondCount,
    this.sticky = false,
    this.retry,
  });

  final int id;
  final ToastKind kind;
  final ToastCode code;

  /// The main number, for plurals.
  final int? count;

  /// A second number, for example how many failed in a partial save.
  final int? secondCount;

  /// A sticky toast stays until dismissed.
  final bool sticky;

  /// Shown as a Retry action when present.
  final VoidCallback? retry;
}

/// The kind a code uses when the caller does not choose one.
ToastKind defaultToastKind(ToastCode code) => switch (code) {
  ToastCode.saved ||
  ToastCode.deleted ||
  ToastCode.folderConnected => ToastKind.success,
  ToastCode.alreadySaved ||
  ToastCode.folderDisconnected ||
  ToastCode.pickerCancelled => ToastKind.info,
  ToastCode.savedPartial ||
  ToastCode.accessLost ||
  ToastCode.settingsRecovered ||
  ToastCode.persistenceWarning => ToastKind.warning,
  ToastCode.saveFailed ||
  ToastCode.deleteFailed ||
  ToastCode.shareFailed ||
  ToastCode.wrongFolder ||
  ToastCode.linkFailed ||
  ToastCode.ioError ||
  ToastCode.unexpected => ToastKind.error,
};

/// A queue of toast messages. One is visible at a time ([value]); it
/// auto-dismisses after [AppConfig.toastDuration] unless sticky; an identical
/// message within one second is dropped. A new message replaces a visible
/// sticky one, and the sticky one returns afterwards.
class ToastProvider extends ValueNotifier<ToastMessage?> {
  ToastProvider() : super(null);

  static const int maxQueue = 4;
  static const Duration duplicateWindow = Duration(seconds: 1);

  final List<ToastMessage> _queue = <ToastMessage>[];
  Timer? _dismissTimer;
  Timer? _duplicateTimer;
  String? _recentKey;
  int _nextId = 1;

  /// Shows a message, queues it, or drops it as a duplicate.
  void show(
    ToastCode code, {
    ToastKind? kind,
    int? count,
    int? secondCount,
    bool sticky = false,
    VoidCallback? retry,
  }) {
    final ToastKind resolved = kind ?? defaultToastKind(code);
    final String key = '${code.name}|${resolved.name}|$count|$secondCount';
    if (key == _recentKey) {
      return;
    }
    _recentKey = key;
    _duplicateTimer?.cancel();
    _duplicateTimer = Timer(duplicateWindow, () => _recentKey = null);

    final ToastMessage message = ToastMessage(
      id: _nextId++,
      kind: resolved,
      code: code,
      count: count,
      secondCount: secondCount,
      sticky: sticky,
      retry: retry,
    );

    final ToastMessage? current = value;
    if (current == null) {
      _display(message);
    } else if (current.sticky) {
      _queue.insert(0, current);
      _display(message);
    } else {
      _queue.add(message);
      while (_queue.length > maxQueue) {
        _queue.removeAt(0);
      }
    }
  }

  /// Dismisses the visible toast and shows the next one. When [id] is given,
  /// does nothing unless that message is the visible one.
  void dismiss({int? id}) {
    final ToastMessage? current = value;
    if (current == null || (id != null && current.id != id)) {
      return;
    }
    _dismissTimer?.cancel();
    if (_queue.isEmpty) {
      value = null;
    } else {
      _display(_queue.removeAt(0));
    }
  }

  void _display(ToastMessage message) {
    _dismissTimer?.cancel();
    value = message;
    if (!message.sticky) {
      final int id = message.id;
      _dismissTimer = Timer(AppConfig.toastDuration, () => dismiss(id: id));
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _duplicateTimer?.cancel();
    super.dispose();
  }
}
