import 'package:flutter/foundation.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/providers/settings_provider.dart';

/// The theme preference. Mapping to Flutter's `ThemeMode` happens in the app
/// layer, because `core/` may not import Material.
class ThemeProvider extends ValueNotifier<ThemePreference> {
  ThemeProvider(this._settings) : super(_settings.settings.themePreference) {
    _settings.addListener(_sync);
  }

  final SettingsProvider _settings;

  void _sync() {
    final ThemePreference next = _settings.settings.themePreference;
    if (next != value) {
      value = next;
    }
  }

  /// Applies the choice immediately and persists it.
  Future<void> setPreference(ThemePreference preference) {
    value = preference;
    return _settings.update(
      (AppSettings s) => s.copyWith(themePreference: preference),
    );
  }

  @override
  void dispose() {
    _settings.removeListener(_sync);
    super.dispose();
  }
}
