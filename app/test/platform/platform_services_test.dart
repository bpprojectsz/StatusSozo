import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/viewable_media.dart';
import 'package:statussozo/core/result.dart';
import 'package:statussozo/platform/plus_share_service.dart';
import 'package:statussozo/platform/saf_channel.dart';
import 'package:statussozo/platform/system_haptics.dart';
import 'package:statussozo/platform/url_link_launcher.dart';

import '../fakes/fakes.dart';
import 'mock_saf.dart';

void main() {
  group('UrlLinkLauncher', () {
    late List<Uri> opened;
    late Set<String> refused;

    setUp(() {
      opened = <Uri>[];
      refused = <String>{};
    });

    UrlLinkLauncher launcher() => UrlLinkLauncher(
      opener: (Uri uri) async {
        opened.add(uri);
        return !refused.contains(uri.scheme);
      },
    );

    test('openUrl opens the uri', () async {
      expect(await launcher().openUrl(Uri.parse('https://example.com')), isTrue);
      expect(opened.single.toString(), 'https://example.com');
    });

    test('openUrl returns false when the opener throws', () async {
      final UrlLinkLauncher throwing = UrlLinkLauncher(
        opener: (Uri uri) async => throw StateError('no handler'),
      );
      expect(await throwing.openUrl(Uri.parse('https://x.y')), isFalse);
    });

    test('openUrl returns false when nothing handles the uri', () async {
      refused.add('https');
      expect(await launcher().openUrl(Uri.parse('https://x.y')), isFalse);
    });

    test('buildMailto encodes the subject and body', () {
      final Uri uri = UrlLinkLauncher.buildMailto(
        to: 'a@b.co',
        subject: 'Hi there',
        body: 'x&y\nz',
      );
      expect(uri.scheme, 'mailto');
      expect(uri.toString(), 'mailto:a@b.co?subject=Hi%20there&body=x%26y%0Az');
    });

    test('composeEmail opens a mailto uri', () async {
      expect(
        await launcher().composeEmail(to: 'a@b.co', subject: 's', body: 'b'),
        isTrue,
      );
      expect(opened.single.scheme, 'mailto');
    });

    test('openStoreListing tries the market uri first', () async {
      expect(await launcher().openStoreListing(), isTrue);
      expect(opened, hasLength(1));
      expect(
        opened.single.toString(),
        'market://details?id=${AppConfig.applicationId}',
      );
    });

    test('openStoreListing falls back to the https listing', () async {
      refused.add('market');
      expect(await launcher().openStoreListing(), isTrue);
      expect(opened, hasLength(2));
      expect(opened.last.toString(), AppConfig.storeListingUrl);
    });

    test('openStoreListing is false when both fail', () async {
      refused
        ..add('market')
        ..add('https');
      expect(await launcher().openStoreListing(), isFalse);
    });
  });

  group('PlusShareService', () {
    final MockSaf native = MockSaf();
    late List<List<XFile>> sharedBatches;

    setUp(() {
      native
        ..reset()
        ..install();
      sharedBatches = <List<XFile>>[];
    });
    tearDown(native.uninstall);

    PlusShareService service({bool failShare = false}) => PlusShareService(
      SafChannel(),
      sharer: (List<XFile> files) async {
        if (failShare) {
          throw StateError('sheet failed');
        }
        sharedBatches.add(files);
      },
    );

    test('copies each item to the cache, then shares the files', () async {
      native.responder = (MethodCall call) =>
          '/cache/share/${(call.arguments as Map<Object?, Object?>)['name']}';
      final Result<void> result = await service().share(<ViewableMedia>[
        statusItem('a.jpg'),
        statusItem('b.mp4', mime: 'video/mp4'),
      ]);
      expect(result.isOk, isTrue);
      expect(native.methods, <String>['copyToCache', 'copyToCache']);
      expect(sharedBatches.single.map((XFile f) => f.path), <String>[
        '/cache/share/a.jpg',
        '/cache/share/b.mp4',
      ]);
      expect(sharedBatches.single.map((XFile f) => f.mimeType), <String?>[
        'image/jpeg',
        'video/mp4',
      ]);
    });

    test('stops and returns the error when a copy fails', () async {
      native.responder = (MethodCall call) =>
          throw PlatformException(code: 'NOT_FOUND');
      final Result<void> result = await service().share(<ViewableMedia>[
        statusItem('a.jpg'),
        statusItem('b.jpg'),
      ]);
      expect(result.errorOrNull?.kind, AppErrorKind.notFound);
      expect(native.calls, hasLength(1));
      expect(sharedBatches, isEmpty);
    });

    test('returns an error when the share sheet throws', () async {
      native.responder = (MethodCall call) => '/cache/x';
      final Result<void> result = await service(failShare: true).share(
        <ViewableMedia>[statusItem('a.jpg')],
      );
      expect(result.errorOrNull?.kind, AppErrorKind.unexpected);
    });

    test('sharing nothing succeeds without touching native', () async {
      final Result<void> result = await service().share(<ViewableMedia>[]);
      expect(result.isOk, isTrue);
      expect(native.calls, isEmpty);
      expect(sharedBatches, isEmpty);
    });

    test('pruneCache sends the configured time to live', () async {
      native.responder = (MethodCall call) => 0;
      await service().pruneCache();
      expect(native.calls.single.method, 'pruneShareCache');
      expect(native.calls.single.arguments, <String, Object?>{
        'olderThanMs': AppConfig.shareCacheTtl.inMilliseconds,
      });
    });
  });

  group('SystemHaptics', () {
    final List<String> sent = <String>[];

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      sent.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall call,
          ) async {
            if (call.method == 'HapticFeedback.vibrate') {
              sent.add(call.arguments as String);
            }
            return null;
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('maps each call to the matching feedback type', () async {
      const SystemHaptics haptics = SystemHaptics();
      haptics.selection();
      haptics.light();
      haptics.success();
      await Future<void>.delayed(Duration.zero);
      expect(sent, <String>[
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
      ]);
    });
  });
}
