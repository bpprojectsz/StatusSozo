import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/models/folder_grant.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/services/settings_codec.dart';

void main() {
  const FolderGrant grant = FolderGrant(
    source: StatusSource.standard,
    treeUri: 'content://tree/s',
    grantedAtMs: 7,
  );

  test('encode stamps the current schema version', () {
    final String encoded = SettingsCodec.encode(
      AppSettings.defaults().copyWith(schemaVersion: 99),
    );
    final Object? json = jsonDecode(encoded);
    expect(json, isA<Map<String, dynamic>>());
    expect(
      (json! as Map<String, dynamic>)['schemaVersion'],
      AppConfig.settingsSchemaVersion,
    );
  });

  test('round trip keeps every field', () {
    final AppSettings original = AppSettings.defaults().copyWith(
      themePreference: ThemePreference.dark,
      languageCode: 'ja',
      lastSource: StatusSource.business,
      grants: <StatusSource, FolderGrant>{StatusSource.standard: grant},
    );
    final DecodedSettings decoded = SettingsCodec.decode(
      SettingsCodec.encode(original),
    );
    expect(decoded.recovered, isFalse);
    expect(decoded.settings, original);
  });

  test('null input gives defaults and is not a recovery', () {
    final DecodedSettings decoded = SettingsCodec.decode(null);
    expect(decoded.settings, AppSettings.defaults());
    expect(decoded.recovered, isFalse);
  });

  group('corrupt input gives defaults and recovered = true', () {
    const Map<String, String> cases = <String, String>{
      'invalid JSON': '{not json',
      'empty string': '',
      'a list': '[1, 2, 3]',
      'a string': '"hello"',
      'a number': '42',
      'a map without a version': '{"themePreference":"dark"}',
      'a non-numeric version': '{"schemaVersion":"one"}',
      'a negative version': '{"schemaVersion":-1}',
    };
    cases.forEach((String name, String raw) {
      test(name, () {
        final DecodedSettings decoded = SettingsCodec.decode(raw);
        expect(decoded.recovered, isTrue);
        expect(decoded.settings, AppSettings.defaults());
      });
    });
  });

  test('a newer version is read leniently and stamped current', () {
    final String raw = jsonEncode(<String, Object?>{
      'schemaVersion': 99,
      'themePreference': 'dark',
      'someFutureField': <String, Object?>{'a': 1},
    });
    final DecodedSettings decoded = SettingsCodec.decode(raw);
    expect(decoded.recovered, isFalse);
    expect(decoded.settings.themePreference, ThemePreference.dark);
    expect(decoded.settings.schemaVersion, AppConfig.settingsSchemaVersion);
  });

  test('grant entries with a bad source are dropped', () {
    final String raw = jsonEncode(<String, Object?>{
      'schemaVersion': AppConfig.settingsSchemaVersion,
      'grants': <String, Object?>{
        'standard': grant.toJson(),
        'business': <String, Object?>{
          'source': 'mars',
          'treeUri': 'u',
          'grantedAt': 1,
        },
      },
    });
    final DecodedSettings decoded = SettingsCodec.decode(raw);
    expect(decoded.recovered, isFalse);
    expect(decoded.settings.grants.keys, <StatusSource>[StatusSource.standard]);
  });

  group('migrations', () {
    test('the shipped table is empty for version 1', () {
      expect(SettingsCodec.migrations, isEmpty);
      expect(AppConfig.settingsSchemaVersion, 1);
    });

    test('an older version with no migration still decodes', () {
      final DecodedSettings decoded = SettingsCodec.decode(
        '{"schemaVersion":0,"themePreference":"light"}',
      );
      expect(decoded.recovered, isFalse);
      expect(decoded.settings.themePreference, ThemePreference.light);
      expect(decoded.settings.schemaVersion, AppConfig.settingsSchemaVersion);
    });

    test('an older version runs its migration', () {
      int calls = 0;
      final DecodedSettings decoded = SettingsCodec.decode(
        '{"schemaVersion":0,"theme":"dark"}',
        migrations: <int, SettingsMigration>{
          0: (Map<String, Object?> json) {
            calls++;
            return <String, Object?>{...json, 'themePreference': json['theme']};
          },
        },
      );
      expect(calls, 1);
      expect(decoded.settings.themePreference, ThemePreference.dark);
    });

    test('a current version does not run migrations', () {
      int calls = 0;
      SettingsCodec.decode(
        SettingsCodec.encode(AppSettings.defaults()),
        migrations: <int, SettingsMigration>{
          0: (Map<String, Object?> json) {
            calls++;
            return json;
          },
        },
      );
      expect(calls, 0);
    });
  });
}
