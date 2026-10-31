import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:statussozo/app/app_services.dart';
import 'package:statussozo/utils/app_log.dart';

/// Re-verifies grants and silently refreshes lists every time the app returns
/// to the foreground.
class LifecycleRefresher with WidgetsBindingObserver {
  LifecycleRefresher(this._services);

  final AppServices _services;
  bool _started = false;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    if (!_started) {
      return;
    }
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    try {
      await _services.refreshAll();
    } on Object catch (error) {
      AppLog.error('lifecycle', 'Resume refresh failed', error);
    }
  }
}
