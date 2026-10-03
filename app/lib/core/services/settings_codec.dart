import 'dart:convert';

import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/models/json_fields.dart';

/// Upgrades stored JSON from one schema version to the next.
typedef SettingsMigration = Map<String, Object?> Function(
  Map<String, Object?> json,
);

/// The outcome of [SettingsCodec.decode].
class DecodedSettings {
  const DecodedSettings({required this.settings, required this.recovered});

  final AppSettings settings;

  /// True when the stored data was unreadable and defaults were used.
  final bool recovered;
}

/// Versioned persistence logic.
///
/// * No stored value: defaults, not recovered.
/// * Invalid JSON, wrong shape or a missing or invalid version: defaults,
///   recovered.
/// * Older version: upgraded step by step through the migration table.
/// * Newer version: known fields are read, unknown fields are ignored, and
///   the result is stamped with the current version.
abstract final class SettingsCodec {
  /// Migrations keyed by the version they upgrade from. Empty for version 1;
  /// the structure exists so the first schema change is a one-line addition.
  static const Map<int, SettingsMigration> migrations =
      <int, SettingsMigration>{};

  static String encode(AppSettings settings) {
    return jsonEncode(
      settings
          .copyWith(schemaVersion: AppConfig.settingsSchemaVersion)
          .toJson(),
    );
  }

  static DecodedSettings decode(
    String? raw, {
    Map<int, SettingsMigration> migrations = SettingsCodec.migrations,
  }) {
    if (raw == null) {
      return DecodedSettings(settings: AppSettings.defaults(), recovered: false);
    }
    final DecodedSettings recoveredDefaults = DecodedSettings(
      settings: AppSettings.defaults(),
      recovered: true,
    );

    final Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } on FormatException {
      return recoveredDefaults;
    }
    if (parsed is! Map<Object?, Object?>) {
      return recoveredDefaults;
    }

    Map<String, Object?> json = stringKeyed(parsed);
    int version = tryReadInt(json, 'schemaVersion') ?? -1;
    if (version < 0) {
      return recoveredDefaults;
    }

    const int current = AppConfig.settingsSchemaVersion;
    while (version < current) {
      final SettingsMigration? migrate = migrations[version];
      if (migrate != null) {
        json = migrate(json);
      }
      version++;
    }

    final AppSettings settings = AppSettings.fromJson(
      json,
    ).copyWith(schemaVersion: current);
    return DecodedSettings(settings: settings, recovered: false);
  }
}
