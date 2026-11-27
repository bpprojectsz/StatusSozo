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
    this.reviewSaves = 0,
    this.reviewDays = 0,
    this.reviewLastDay,
    this.reviewAskCount = 0,
    this.reviewLastAskedMs,
    this.viewAll = true,
    this.adTally = 0,
    this.adPending = false,
    this.adLastShownMs,
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
      reviewSaves: tryReadInt(json, 'reviewSaves') ?? 0,
      reviewDays: tryReadInt(json, 'reviewDays') ?? 0,
      reviewLastDay: tryReadString(json, 'reviewLastDay'),
      // Settings from before the cooldowns kept a single yes or no.
      reviewAskCount:
          tryReadInt(json, 'reviewAskCount') ??
          (json['reviewAsked'] == true ? 1 : 0),
      reviewLastAskedMs: tryReadInt(json, 'reviewLastAskedMs'),
      viewAll: json['viewAll'] is bool ? json['viewAll']! as bool : true,
      adTally: (tryReadInt(json, 'adTally') ?? 0).clamp(0, 1000000),
      adPending: json['adPending'] is bool
          ? json['adPending']! as bool
          : false,
      adLastShownMs: tryReadInt(json, 'adLastShownMs'),
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

  /// Items saved so far, counted toward the review prompt.
  final int reviewSaves;

  /// Different days on which something was saved.
  final int reviewDays;

  /// The last day (yyyy-MM-dd) a save was counted.
  final String? reviewLastDay;

  /// How many times the review prompt has been requested.
  final int reviewAskCount;

  /// When it was last requested (epoch milliseconds), or null if never or not
  /// known.
  final int? reviewLastAskedMs;

  /// Home shows every connected source together instead of one at a time.
  final bool viewAll;

  /// Counted actions since the last full-screen ad (the single app-wide tally).
  final int adTally;

  /// The tally reached its target and an ad is waiting for its turn.
  final bool adPending;

  /// When the last full-screen ad was shown (epoch milliseconds), or null.
  final int? adLastShownMs;

  /// Copies with changes. Pass [clearLanguage] to reset [languageCode] to null.
  AppSettings copyWith({
    int? schemaVersion,
    ThemePreference? themePreference,
    String? languageCode,
    bool clearLanguage = false,
    StatusSource? lastSource,
    Map<StatusSource, FolderGrant>? grants,
    int? reviewSaves,
    int? reviewDays,
    String? reviewLastDay,
    int? reviewAskCount,
    int? reviewLastAskedMs,
    bool? viewAll,
    int? adTally,
    bool? adPending,
    int? adLastShownMs,
  }) {
    return AppSettings(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      themePreference: themePreference ?? this.themePreference,
      languageCode: clearLanguage ? null : (languageCode ?? this.languageCode),
      lastSource: lastSource ?? this.lastSource,
      grants: grants ?? this.grants,
      reviewSaves: reviewSaves ?? this.reviewSaves,
      reviewDays: reviewDays ?? this.reviewDays,
      reviewLastDay: reviewLastDay ?? this.reviewLastDay,
      reviewAskCount: reviewAskCount ?? this.reviewAskCount,
      reviewLastAskedMs: reviewLastAskedMs ?? this.reviewLastAskedMs,
      viewAll: viewAll ?? this.viewAll,
      adTally: adTally ?? this.adTally,
      adPending: adPending ?? this.adPending,
      adLastShownMs: adLastShownMs ?? this.adLastShownMs,
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
    'reviewSaves': reviewSaves,
    'reviewDays': reviewDays,
    'reviewLastDay': reviewLastDay,
    'reviewAskCount': reviewAskCount,
    'reviewLastAskedMs': reviewLastAskedMs,
    'viewAll': viewAll,
    'adTally': adTally,
    'adPending': adPending,
    'adLastShownMs': adLastShownMs,
  };

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.schemaVersion == schemaVersion &&
      other.themePreference == themePreference &&
      other.languageCode == languageCode &&
      other.lastSource == lastSource &&
      other.reviewSaves == reviewSaves &&
      other.reviewDays == reviewDays &&
      other.reviewLastDay == reviewLastDay &&
      other.reviewAskCount == reviewAskCount &&
      other.reviewLastAskedMs == reviewLastAskedMs &&
      other.viewAll == viewAll &&
      other.adTally == adTally &&
      other.adPending == adPending &&
      other.adLastShownMs == adLastShownMs &&
      mapEquals(other.grants, grants);

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    themePreference,
    languageCode,
    lastSource,
    reviewSaves,
    reviewDays,
    reviewLastDay,
    reviewAskCount,
    reviewLastAskedMs,
    viewAll,
    adTally,
    adPending,
    adLastShownMs,
    Object.hashAllUnordered(
      grants.entries.map(
        (MapEntry<StatusSource, FolderGrant> e) => Object.hash(e.key, e.value),
      ),
    ),
  );
}
