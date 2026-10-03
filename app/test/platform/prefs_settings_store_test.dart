import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/contracts/settings_store.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/models/folder_grant.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/platform/prefs_settings_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('first run returns defaults without a recovery', () async {
    final StoredSettings stored = await PrefsSettingsStore().load();
    expect(stored.settings, AppSettings.defaults());
    expect(stored.recovered, isFalse);
    expect(stored.persistenceAvailable, isTrue);
  });

  test('a saved value round-trips', () async {
    final PrefsSettingsStore store = PrefsSettingsStore();
    final AppSettings settings = AppSettings.defaults().copyWith(
      themePreference: ThemePreference.dark,
      languageCode: 'es',
      lastSource: StatusSource.business,
      grants: <StatusSource, FolderGrant>{
        StatusSource.standard: const FolderGrant(
          source: StatusSource.standard,
          treeUri: 'content://tree/s',
          grantedAtMs: 5,
        ),
      },
    );
    expect(await store.save(settings), isTrue);

    final StoredSettings loaded = await PrefsSettingsStore().load();
    expect(loaded.settings, settings);
    expect(loaded.recovered, isFalse);
    expect(loaded.persistenceAvailable, isTrue);
  });

  test('writes a single JSON string under the configured key', () async {
    await PrefsSettingsStore().save(AppSettings.defaults());
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), <String>{AppConfig.settingsPrefsKey});
    expect(prefs.getString(AppConfig.settingsPrefsKey), startsWith('{'));
  });

  test('a corrupt string is recovered to defaults', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConfig.settingsPrefsKey: '{definitely not json',
    });
    final StoredSettings stored = await PrefsSettingsStore().load();
    expect(stored.settings, AppSettings.defaults());
    expect(stored.recovered, isTrue);
    expect(stored.persistenceAvailable, isTrue);
  });

  test('a value of the wrong type is recovered to defaults', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConfig.settingsPrefsKey: 42,
    });
    final StoredSettings stored = await PrefsSettingsStore().load();
    expect(stored.settings, AppSettings.defaults());
    expect(stored.recovered, isTrue);
    expect(stored.persistenceAvailable, isTrue);
  });

  test('a throwing backend reports persistence as unavailable', () async {
    final PrefsSettingsStore store = PrefsSettingsStore(
      prefsProvider: () async => throw StateError('no disk'),
    );
    final StoredSettings stored = await store.load();
    expect(stored.settings, AppSettings.defaults());
    expect(stored.persistenceAvailable, isFalse);
    expect(stored.recovered, isFalse);
  });

  test('save returns false instead of throwing when the backend fails', () async {
    final PrefsSettingsStore store = PrefsSettingsStore(
      prefsProvider: () async => throw StateError('no disk'),
    );
    expect(await store.save(AppSettings.defaults()), isFalse);
  });
}
