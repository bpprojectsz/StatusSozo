import 'package:flutter/foundation.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/providers/settings_provider.dart';

/// Which source is showing: one of them, or all of them together.
///
/// [value] is the last single source chosen. [showAll] says whether Home shows
/// every connected source together instead. Home only honours it while more
/// than one source is connected.
class SourceProvider extends ValueNotifier<StatusSource> {
  SourceProvider(this._settings)
    : _showAll = _settings.settings.viewAll,
      super(_settings.settings.lastSource) {
    _settings.addListener(_sync);
  }

  final SettingsProvider _settings;
  bool _showAll;

  /// True when Home shows every connected source together.
  bool get showAll => _showAll;

  void _sync() {
    final StatusSource next = _settings.settings.lastSource;
    final bool all = _settings.settings.viewAll;
    if (next != value) {
      value = next;
    }
    if (all != _showAll) {
      _showAll = all;
      notifyListeners();
    }
  }

  /// Selects [source] on its own. Notifies only on change and persists the
  /// choice.
  Future<void> select(StatusSource source) {
    if (source == value && !_showAll) {
      return Future<void>.value();
    }
    final bool wasAll = _showAll;
    _showAll = false;
    if (source != value) {
      value = source;
    } else if (wasAll) {
      notifyListeners();
    }
    return _settings.update(
      (AppSettings s) => s.copyWith(lastSource: source, viewAll: false),
    );
  }

  /// Shows every connected source together.
  Future<void> selectAll() {
    if (_showAll) {
      return Future<void>.value();
    }
    _showAll = true;
    notifyListeners();
    return _settings.update((AppSettings s) => s.copyWith(viewAll: true));
  }

  @override
  void dispose() {
    _settings.removeListener(_sync);
    super.dispose();
  }
}
