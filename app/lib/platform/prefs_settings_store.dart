import 'package:shared_preferences/shared_preferences.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/contracts/settings_store.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/services/settings_codec.dart';
import 'package:statussozo/utils/app_log.dart';

/// [SettingsStore] over `shared_preferences`: one JSON string under one key.
class PrefsSettingsStore implements SettingsStore {
  PrefsSettingsStore({Future<SharedPreferences> Function()? prefsProvider})
    : _prefsProvider = prefsProvider ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefsProvider;

  @override
  Future<StoredSettings> load() async {
    try {
      final SharedPreferences prefs = await _prefsProvider();
      final Object? raw = prefs.get(AppConfig.settingsPrefsKey);
      if (raw != null && raw is! String) {
        AppLog.warn('settings', 'stored value has the wrong type');
        return StoredSettings(
          settings: AppSettings.defaults(),
          recovered: true,
        );
      }
      final DecodedSettings decoded = SettingsCodec.decode(raw as String?);
      return StoredSettings(
        settings: decoded.settings,
        recovered: decoded.recovered,
      );
    } on Object catch (error) {
      AppLog.error('settings', 'could not read settings', error);
      return StoredSettings(
        settings: AppSettings.defaults(),
        persistenceAvailable: false,
      );
    }
  }

  @override
  Future<bool> save(AppSettings settings) async {
    try {
      final SharedPreferences prefs = await _prefsProvider();
      return await prefs.setString(
        AppConfig.settingsPrefsKey,
        SettingsCodec.encode(settings),
      );
    } on Object catch (error) {
      AppLog.error('settings', 'could not save settings', error);
      return false;
    }
  }
}
