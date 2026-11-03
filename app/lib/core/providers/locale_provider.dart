import 'package:flutter/foundation.dart';
import 'package:statussozo/core/models/app_language.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/providers/settings_provider.dart';

/// The language the person chose, as a language code. Null means follow the
/// system language. A stored code the app has no translation for is treated as
/// null, so a downgrade or a hand-edited file can never leave the app without
/// a language.
class LocaleProvider extends ValueNotifier<String?> {
  LocaleProvider(this._settings) : super(_valid(_settings.settings.languageCode)) {
    _settings.addListener(_sync);
  }

  final SettingsProvider _settings;

  static String? _valid(String? code) =>
      AppLanguages.byCode(code) == null ? null : code;

  void _sync() {
    final String? next = _valid(_settings.settings.languageCode);
    if (next != value) {
      value = next;
    }
  }

  /// Applies the choice immediately and persists it. Null follows the system.
  Future<void> setLanguage(String? code) {
    final String? next = _valid(code);
    value = next;
    return _settings.update(
      (AppSettings s) => next == null
          ? s.copyWith(clearLanguage: true)
          : s.copyWith(languageCode: next),
    );
  }

  @override
  void dispose() {
    _settings.removeListener(_sync);
    super.dispose();
  }
}
