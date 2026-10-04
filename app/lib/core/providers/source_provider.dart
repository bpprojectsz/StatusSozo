import 'package:flutter/foundation.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/providers/settings_provider.dart';

/// Which source is showing.
class SourceProvider extends ValueNotifier<StatusSource> {
  SourceProvider(this._settings) : super(_settings.settings.lastSource) {
    _settings.addListener(_sync);
  }

  final SettingsProvider _settings;

  void _sync() {
    final StatusSource next = _settings.settings.lastSource;
    if (next != value) {
      value = next;
    }
  }

  /// Selects [source]. Notifies only on change and persists the choice.
  Future<void> select(StatusSource source) {
    if (source == value) {
      return Future<void>.value();
    }
    value = source;
    return _settings.update((AppSettings s) => s.copyWith(lastSource: source));
  }

  @override
  void dispose() {
    _settings.removeListener(_sync);
    super.dispose();
  }
}
