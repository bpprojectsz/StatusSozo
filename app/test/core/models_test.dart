import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/models/folder_grant.dart';
import 'package:statussozo/core/models/media_kind.dart';
import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/models/status_source.dart';

void main() {
  group('AppConfig', () {
    test('derived URLs', () {
      expect(AppConfig.privacyUrl, '${AppConfig.websiteBaseUrl}/privacy');
      expect(AppConfig.supportUrl, '${AppConfig.websiteBaseUrl}/support');
      expect(
        AppConfig.storeListingUrl,
        'https://play.google.com/store/apps/details?id=com.zdmgold.statussozo',
      );
      expect(AppConfig.websiteBaseUrl, startsWith('https://'));
    });

    test('values', () {
      expect(AppConfig.statusFolderName, '.Statuses');
      expect(AppConfig.thumbnailConcurrency, 3);
      expect(AppConfig.imageMaxBytes, 25 * 1024 * 1024);
      expect(AppConfig.shareCacheTtl, const Duration(hours: 24));
      expect(AppConfig.toastDuration, const Duration(seconds: 3));
      expect(AppConfig.settingsSchemaVersion, 1);
    });
  });

  group('MediaKind', () {
    test('fromMime', () {
      expect(MediaKind.fromMime('image/jpeg'), MediaKind.image);
      expect(MediaKind.fromMime('IMAGE/PNG'), MediaKind.image);
      expect(MediaKind.fromMime('video/mp4'), MediaKind.video);
      expect(MediaKind.fromMime('application/pdf'), isNull);
      expect(MediaKind.fromMime(''), isNull);
    });

    test('isVideo', () {
      expect(MediaKind.video.isVideo, isTrue);
      expect(MediaKind.image.isVideo, isFalse);
    });
  });

  group('StatusSource', () {
    test('fromId', () {
      expect(StatusSource.fromId('standard'), StatusSource.standard);
      expect(StatusSource.fromId('business'), StatusSource.business);
      expect(StatusSource.fromId('other'), isNull);
      expect(StatusSource.fromId(null), isNull);
    });

    test('folder paths and picker URI', () {
      expect(
        StatusSource.standard.relativeFolderPath,
        'Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
      );
      expect(
        StatusSource.business.relativeFolderPath,
        'Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses',
      );
      expect(
        StatusSource.standard.initialTreeUri,
        'content://com.android.externalstorage.documents/document/'
        'primary%3AAndroid%2Fmedia%2Fcom.whatsapp%2FWhatsApp%2FMedia%2F.Statuses',
      );
      expect(
        StatusSource.business.initialTreeUri,
        contains('WhatsApp%20Business'),
      );
    });
  });

  group('StatusItem', () {
    const StatusItem item = StatusItem(
      uri: 'content://a/1',
      name: 'one.jpg',
      mime: 'image/jpeg',
      sizeBytes: 1200,
      modifiedMs: 1700000000000,
    );

    test('json round trip', () {
      expect(StatusItem.fromJson(item.toJson()), item);
    });

    test('id kind and copyWith', () {
      expect(item.id, 'content://a/1');
      expect(item.kind, MediaKind.image);
      expect(item.copyWith(mime: 'video/mp4').kind, MediaKind.video);
      expect(item.copyWith(name: 'two.jpg').name, 'two.jpg');
      expect(item.copyWith(name: 'two.jpg').uri, item.uri);
    });

    test('equality and hash', () {
      final StatusItem same = item.copyWith();
      expect(same, item);
      expect(same.hashCode, item.hashCode);
      expect(item.copyWith(sizeBytes: 1), isNot(item));
    });

    test('fromJson rejects bad shapes', () {
      expect(
        () => StatusItem.fromJson(<String, Object?>{'uri': 1}),
        throwsFormatException,
      );
      expect(
        () => StatusItem.fromJson(<String, Object?>{
          'uri': 'u',
          'name': 'n',
          'mime': 'image/png',
          'size': 'big',
          'modified': 1,
        }),
        throwsFormatException,
      );
    });

    test('accepts integral doubles from the wire', () {
      final StatusItem parsed = StatusItem.fromJson(<String, Object?>{
        'uri': 'u',
        'name': 'n',
        'mime': 'image/png',
        'size': 12.0,
        'modified': 5.0,
      });
      expect(parsed.sizeBytes, 12);
      expect(parsed.modifiedMs, 5);
    });
  });

  group('SavedItem', () {
    const SavedItem item = SavedItem(
      uri: 'content://media/9',
      name: 'clip.mp4',
      mime: 'video/mp4',
      sizeBytes: 5000,
      savedAtMs: 1700000005000,
    );

    test('json round trip, id, kind', () {
      expect(SavedItem.fromJson(item.toJson()), item);
      expect(item.id, 'content://media/9');
      expect(item.kind, MediaKind.video);
    });

    test('copyWith, equality and hash', () {
      final SavedItem same = item.copyWith();
      expect(same, item);
      expect(same.hashCode, item.hashCode);
      expect(item.copyWith(savedAtMs: 1).savedAtMs, 1);
      expect(item.copyWith(savedAtMs: 1), isNot(item));
    });
  });

  group('FolderGrant', () {
    const FolderGrant grant = FolderGrant(
      source: StatusSource.business,
      treeUri: 'content://tree/x',
      grantedAtMs: 42,
    );

    test('json round trip', () {
      expect(FolderGrant.fromJson(grant.toJson()), grant);
    });

    test('copyWith, equality and hash', () {
      expect(grant.copyWith(), grant);
      expect(grant.copyWith().hashCode, grant.hashCode);
      expect(grant.copyWith(source: StatusSource.standard), isNot(grant));
    });

    test('unknown source is rejected', () {
      expect(
        () => FolderGrant.fromJson(<String, Object?>{
          'source': 'nope',
          'treeUri': 'u',
          'grantedAt': 1,
        }),
        throwsFormatException,
      );
    });
  });

  group('AppSettings', () {
    const FolderGrant standardGrant = FolderGrant(
      source: StatusSource.standard,
      treeUri: 'content://tree/s',
      grantedAtMs: 1,
    );

    test('defaults', () {
      final AppSettings d = AppSettings.defaults();
      expect(d.schemaVersion, AppConfig.settingsSchemaVersion);
      expect(d.themePreference, ThemePreference.system);
      expect(d.languageCode, isNull);
      expect(d.lastSource, StatusSource.standard);
      expect(d.grants, isEmpty);
    });

    test('json round trip', () {
      final AppSettings s = AppSettings.defaults().copyWith(
        themePreference: ThemePreference.dark,
        languageCode: 'fr',
        lastSource: StatusSource.business,
        grants: <StatusSource, FolderGrant>{
          StatusSource.standard: standardGrant,
        },
      );
      expect(AppSettings.fromJson(s.toJson()), s);
    });

    test('grants map is unmodifiable', () {
      final AppSettings s = AppSettings.defaults().copyWith(
        grants: <StatusSource, FolderGrant>{
          StatusSource.standard: standardGrant,
        },
      );
      expect(
        () => s.grants[StatusSource.business] = standardGrant,
        throwsUnsupportedError,
      );
    });

    test('copyWith can clear the language', () {
      final AppSettings s = AppSettings.defaults().copyWith(languageCode: 'de');
      expect(s.languageCode, 'de');
      expect(s.copyWith().languageCode, 'de');
      expect(s.copyWith(clearLanguage: true).languageCode, isNull);
    });

    test('equality and hash use map equality', () {
      final AppSettings a = AppSettings.defaults().copyWith(
        grants: <StatusSource, FolderGrant>{
          StatusSource.standard: standardGrant,
        },
      );
      final AppSettings b = AppSettings.defaults().copyWith(
        grants: <StatusSource, FolderGrant>{
          StatusSource.standard: standardGrant,
        },
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(AppSettings.defaults()));
    });

    test('fromJson tolerates garbage', () {
      final AppSettings s = AppSettings.fromJson(<String, Object?>{
        'schemaVersion': 'x',
        'themePreference': 'neon',
        'languageCode': 7,
        'lastSource': 'mars',
        'grants': 'not a map',
      });
      expect(s, AppSettings.defaults());
    });

    test('fromJson drops bad grant entries and keeps good ones', () {
      final AppSettings s = AppSettings.fromJson(<String, Object?>{
        'grants': <String, Object?>{
          'standard': standardGrant.toJson(),
          'business': <String, Object?>{'source': 'business'},
          'mars': standardGrant.toJson(),
          // Key and embedded source disagree.
          'other': <String, Object?>{
            'source': 'business',
            'treeUri': 'u',
            'grantedAt': 1,
          },
          7: 'nonsense',
        },
      });
      expect(s.grants.keys, <StatusSource>[StatusSource.standard]);
      expect(s.grants[StatusSource.standard], standardGrant);
    });

    test('an empty language code means follow the system', () {
      final AppSettings s = AppSettings.fromJson(<String, Object?>{
        'languageCode': '',
      });
      expect(s.languageCode, isNull);
    });

    test('keeps a newer schema version number it did not write', () {
      final AppSettings s = AppSettings.fromJson(<String, Object?>{
        'schemaVersion': 99,
      });
      expect(s.schemaVersion, 99);
    });
  });
}
