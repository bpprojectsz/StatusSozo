// Test helper: a full app shell (theme, localisation, AppScope, ToastHost)
// around a screen, built on the shared fakes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/app/app_scope.dart';
import 'package:statussozo/app/app_services.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/models/folder_grant.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/widgets/feedback/toast_host.dart';

import '../fakes/fakes.dart';

/// Everything a screen test needs: the fakes and the container built on them.
class Rig {
  Rig._({
    required this.status,
    required this.saved,
    required this.store,
    required this.thumbs,
    required this.share,
    required this.links,
    required this.haptics,
    required this.video,
    required this.services,
  });

  factory Rig() {
    final FakeStatusRepository status = FakeStatusRepository();
    final FakeSavedRepository saved = FakeSavedRepository();
    final FakeSettingsStore store = FakeSettingsStore();
    final FakeThumbnailSource thumbs = FakeThumbnailSource();
    final FakeShareService share = FakeShareService();
    final FakeLinkLauncher links = FakeLinkLauncher();
    final FakeHapticsService haptics = FakeHapticsService();
    final FakeVideoSessionFactory video = FakeVideoSessionFactory();
    return Rig._(
      status: status,
      saved: saved,
      store: store,
      thumbs: thumbs,
      share: share,
      links: links,
      haptics: haptics,
      video: video,
      services: AppServices.forTesting(
        statusRepository: status,
        savedRepository: saved,
        thumbnails: thumbs,
        share: share,
        settingsStore: store,
        links: links,
        haptics: haptics,
        videoFactory: video,
      ),
    );
  }

  final FakeStatusRepository status;
  final FakeSavedRepository saved;
  final FakeSettingsStore store;
  final FakeThumbnailSource thumbs;
  final FakeShareService share;
  final FakeLinkLauncher links;
  final FakeHapticsService haptics;
  final FakeVideoSessionFactory video;
  final AppServices services;

  /// Five items: three photos and two videos, newest first overall.
  static List<StatusItem> defaultItems() => <StatusItem>[
    statusItem('p1.jpg', modifiedMs: 300),
    statusItem('v1.mp4', mime: 'video/mp4', modifiedMs: 250),
    statusItem('p2.jpg', modifiedMs: 200),
    statusItem('p3.jpg', modifiedMs: 100),
    statusItem('v2.mp4', mime: 'video/mp4', modifiedMs: 50),
  ];

  /// Grants for [sources] and a full bootstrap, so lists are loaded.
  Future<void> prime({
    List<StatusSource> sources = const <StatusSource>[StatusSource.standard],
    List<StatusItem>? items,
  }) async {
    status.itemsBySource[StatusSource.standard] = items ?? defaultItems();
    await services.settings.load();
    await services.settings.update(
      (AppSettings s) => s.copyWith(
        grants: <StatusSource, FolderGrant>{
          for (final StatusSource src in sources)
            src: FolderGrant(
              source: src,
              treeUri: 'content://tree/${src.id}',
              grantedAtMs: 1,
            ),
        },
      ),
    );
    await services.bootstrap();
  }

  void dispose() => services.dispose();
}

Widget screenApp(
  Rig rig,
  Widget home, {
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (BuildContext context, Widget? app) {
      final MediaQueryData base = MediaQuery.of(context);
      return MediaQuery(
        data: base.copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: Directionality(
          textDirection: direction,
          child: AppScope(
            services: rig.services,
            child: ToastHost(provider: rig.services.toasts, child: app!),
          ),
        ),
      );
    },
    home: home,
  );
}

/// Records the system UI mode calls a screen makes.
class PlatformRecorder {
  final List<String> uiModes = <String>[];

  void install() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
            uiModes.add(call.arguments as String);
          }
          return null;
        });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  }
}
