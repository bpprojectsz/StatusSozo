import 'package:flutter/foundation.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/models/folder_grant.dart';
import 'package:statussozo/core/models/json_fields.dart';
import 'package:statussozo/core/models/status_source.dart';

/// The user's theme choice.
enum ThemePreference { system, light, dark }

/// Everything that is persisted.
@immutable
class AppSettings {
  AppSettings({
    required this.schemaVersion,
    required this.themePreference,
    required this.languageCode,
    required this.lastSource,
    required Map<StatusSource, FolderGrant> grants,
  }) : grants = Map<StatusSource, FolderGrant>.unmodifiable(grants);

  /// Tolerant decoding: unknown enum values fall back to defaults and bad
  /// grant entries are dropped. Never throws.
  factory AppSettings.fromJson(Map<String, Object?> json) {
    final AppSettings defaults = AppSettings.defaults();

    ThemePreference theme = defaults.themePreference;
    final String? themeName = tryReadString(json, 'themePreference');
    for (final ThemePreference candidate in ThemePreference.values) {
      if (candidate.name == themeName) {
        theme = candidate;
      }
    }

    final String? language = tryReadString(json, 'languageCode');

    final Map<StatusSource, FolderGrant> grants =
        <StatusSource, FolderGrant>{};
    final Object? rawGrants = json['grants'];
    if (rawGrants is Map<Object?, Object?>) {
      for (final MapEntry<Object?, Object?> entry in rawGrants.entries) {
        final Object? key = entry.key;
        final Object? value = entry.value;
        if (key is! String || value is! Map<Object?, Object?>) {
          continue;
        }
        final StatusSource? source = StatusSource.fromId(key);
        if (source == null) {
          continue;
        }
        try {
          final FolderGrant grant = FolderGrant.fromJson(stringKeyed(value));
          if (grant.source == source) {
            grants[source] = grant;
          }
        } on FormatException {
          continue;
        }
      }
    }

    return AppSettings(
      schemaVersion:
          tryReadInt(json, 'schemaVersion') ?? defaults.schemaVersion,
      themePreference: theme,
      languageCode: (language == null || language.isEmpty) ? null : language,
      lastSource:
          StatusSource.fromId(tryReadString(json, 'lastSource')) ??
          defaults.lastSource,
      grants: grants,
    );
  }

  /// Factory settings for a first run or after recovery.
  factory AppSettings.defaults() {
    return AppSettings(
      schemaVersion: AppConfig.settingsSchemaVersion,
      themePreference: ThemePreference.system,
      languageCode: null,
      lastSource: StatusSource.standard,
      grants: const <StatusSource, FolderGrant>{},
    );
  }

  final int schemaVersion;
  final ThemePreference themePreference;

  /// Chosen language code, or null to follow the system.
  final String? languageCode;
  final StatusSource lastSource;

  /// Folder grants by source. Unmodifiable.
  final Map<StatusSource, FolderGrant> grants;

  /// Copies with changes. Pass [clearLanguage] to reset [languageCode] to null.
  AppSettings copyWith({
    int? schemaVersion,
    ThemePreference? themePreference,
    String? languageCode,
    bool clearLanguage = false,
    StatusSource? lastSource,
    Map<StatusSource, FolderGrant>? grants,
  }) {
    return AppSettings(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      themePreference: themePreference ?? this.themePreference,
      languageCode: clearLanguage ? null : (languageCode ?? this.languageCode),
      lastSource: lastSource ?? this.lastSource,
      grants: grants ?? this.grants,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'themePreference': themePreference.name,
    'languageCode': languageCode,
    'lastSource': lastSource.id,
    'grants': <String, Object?>{
      for (final MapEntry<StatusSource, FolderGrant> entry in grants.entries)
        entry.key.id: entry.value.toJson(),
    },
  };

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.schemaVersion == schemaVersion &&
      other.themePreference == themePreference &&
      other.languageCode == languageCode &&
      other.lastSource == lastSource &&
      mapEquals(other.grants, grants);

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    themePreference,
    languageCode,
    lastSource,
    Object.hashAllUnordered(
      grants.entries.map(
        (MapEntry<StatusSource, FolderGrant> e) => Object.hash(e.key, e.value),
      ),
    ),
  );
}
