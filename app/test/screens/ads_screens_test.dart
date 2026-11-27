import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/contracts/consent_service.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/screens/access_screen.dart';
import 'package:statussozo/screens/home_screen.dart';
import 'package:statussozo/screens/saved_screen.dart';
import 'package:statussozo/screens/settings_screen.dart';
import 'package:statussozo/screens/viewer_screen.dart';
import 'package:statussozo/widgets/media/status_tile.dart';
import 'package:statussozo/widgets/primitives/nav_icon_button.dart';
import 'package:statussozo/widgets/primitives/primary_button.dart';

import '../fakes/fakes.dart';
import '../widgets/harness.dart';
import 'screen_harness.dart';

Widget _launcher(Widget Function() screen) {
  return Builder(
    builder: (BuildContext context) => PrimaryButton(
      label: 'Open',
      onPressed: () => Navigator.of(context).push(
        AppPageRoute<void>(builder: (_) => screen()),
      ),
    ),
  );
}

void main() {
  late Rig rig;
  late PlatformRecorder platform;
  void testScreen(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => screenTest(description, () => rig, body);

  setUp(() {
    rig = Rig();
    platform = PlatformRecorder()..install();
  });
  tearDown(() {
    platform.uninstall();
    rig.dispose();
  });

  final Finder banner = find.byKey(const ValueKey<String>('fake-banner'));

  Future<void> enableAds(WidgetTester tester) =>
      rig.run(tester, rig.services.ads.start);

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    double height = 2600,
  }) async {
    useSurface(tester, height: height);
    await tester.pumpWidget(screenApp(rig, screen));
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('banners', () {
    testScreen('Home shows a banner once ads are on', (
      WidgetTester tester,
    ) async {
      await rig.primeIn(tester);
      await enableAds(tester);
      await pumpScreen(tester, const HomeScreen());
      expect(banner, findsOneWidget);
    });

    testScreen('Home has no ad slot while ads are off', (
      WidgetTester tester,
    ) async {
      rig.consent.outcome = const ConsentOutcome(
        canRequestAds: false,
        privacyOptionsRequired: false,
      );
      await rig.primeIn(tester);
      await pumpScreen(tester, const HomeScreen());
      expect(banner, findsNothing);
      expect(rig.adService.banners, isEmpty);
    });

    testScreen('Saved shows a banner', (WidgetTester tester) async {
      await enableAds(tester);
      await pumpScreen(tester, const SavedScreen());
      expect(banner, findsOneWidget);
    });

    testScreen('Settings shows a banner', (WidgetTester tester) async {
      await enableAds(tester);
      await pumpScreen(tester, const SettingsScreen());
      expect(banner, findsOneWidget);
    });

    testScreen('the access screen never shows an ad', (
      WidgetTester tester,
    ) async {
      await enableAds(tester);
      await pumpScreen(tester, const AccessScreen());
      expect(banner, findsNothing);
      expect(rig.adService.banners, isEmpty);
    });

    testScreen('the viewer shows a banner with a clear gap under Save', (
      WidgetTester tester,
    ) async {
      await enableAds(tester);
      await pumpScreen(
        tester,
        _launcher(
          () => ViewerScreen(
            items: Rig.defaultItems(),
            initialIndex: 0,
            mode: ViewerMode.status,
          ),
        ),
        height: 1200,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(banner, findsOneWidget);
      final double saveBottom = tester
          .getBottomLeft(find.byType(PrimaryButton).last)
          .dy;
      final double adTop = tester.getTopLeft(banner).dy;
      expect(adTop - saveBottom, greaterThanOrEqualTo(AppSpacing.lg));
    });
  });

  group('interstitials', () {
    /// One action short of the target, so the next counted action is the seventh.
    Future<void> arm(WidgetTester tester) => rig.run(
      tester,
      () => rig.services.settings.update(
        (AppSettings s) => s.copyWith(adTally: 6),
      ),
    );

    /// Lets the two second pause pass and the ad run.
    Future<void> afterPause(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
    }

    int tally() => rig.services.settings.settings.adTally;

    Future<void> selectAndSave(WidgetTester tester, int tiles) async {
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      for (int i = 1; i < tiles; i++) {
        await tester.tap(find.byType(StatusTile).at(i));
        await tester.pump();
      }
      await tester.tap(find.text('Save $tiles'));
      await tester.pump();
      await tester.pump();
    }

    testScreen('the seventh counted action shows one, after a pause', (
      WidgetTester tester,
    ) async {
      await rig.primeIn(tester);
      await enableAds(tester);
      await arm(tester);
      await pumpScreen(tester, const HomeScreen());
      await selectAndSave(tester, 3);
      await tester.pump(const Duration(milliseconds: 400));
      expect(rig.adService.showCalls, 0);
      await afterPause(tester);
      expect(rig.adService.showCalls, 1);
      expect(tally(), 0);
    });

    testScreen('a save of one item counts as one action', (
      WidgetTester tester,
    ) async {
      await rig.primeIn(tester);
      await enableAds(tester);
      await pumpScreen(tester, const HomeScreen());
      await selectAndSave(tester, 1);
      await afterPause(tester);
      expect(tally(), 1);
      expect(rig.adService.showCalls, 0);
    });

    testScreen('a batch of three is still one action', (
      WidgetTester tester,
    ) async {
      await rig.primeIn(tester);
      await enableAds(tester);
      await pumpScreen(tester, const HomeScreen());
      await selectAndSave(tester, 3);
      await afterPause(tester);
      expect(tally(), 1);
    });

    testScreen('with ads off nothing is counted and nothing shows', (
      WidgetTester tester,
    ) async {
      rig.consent.outcome = const ConsentOutcome(
        canRequestAds: false,
        privacyOptionsRequired: false,
      );
      await rig.primeIn(tester);
      await arm(tester);
      await pumpScreen(tester, const HomeScreen());
      await selectAndSave(tester, 2);
      await afterPause(tester);
      expect(tally(), 6);
      expect(rig.adService.showCalls, 0);
    });

    testScreen('opening Saved from Home counts', (WidgetTester tester) async {
      await rig.primeIn(tester);
      await enableAds(tester);
      await arm(tester);
      await pumpScreen(tester, const HomeScreen());
      await tester.tap(find.byType(NavIconButton).at(2));
      await tester.pumpAndSettle();
      await afterPause(tester);
      expect(rig.adService.showCalls, 1);
    });

    testScreen('leaving Saved counts', (WidgetTester tester) async {
      await enableAds(tester);
      await arm(tester);
      await pumpScreen(
        tester,
        _launcher(() => const SavedScreen()),
        height: 1200,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await afterPause(tester);
      expect(rig.adService.showCalls, 1);
    });

    testScreen('leaving Settings counts', (WidgetTester tester) async {
      await enableAds(tester);
      await arm(tester);
      await pumpScreen(
        tester,
        _launcher(() => const SettingsScreen()),
        height: 1200,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await afterPause(tester);
      expect(rig.adService.showCalls, 1);
    });

    testScreen('clearing temporary files counts', (WidgetTester tester) async {
      rig.share.cacheBytes = 4 * 1024 * 1024;
      await enableAds(tester);
      await arm(tester);
      await pumpScreen(tester, const SettingsScreen());
      await tester.tap(find.text('Clear'));
      await tester.pump();
      await tester.pump();
      await afterPause(tester);
      expect(rig.adService.showCalls, 1);
    });

    testScreen('deleting from Saved counts', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      rig.saved.items.addAll(<SavedItem>[
        savedItem('a.jpg', savedAtMs: 3),
        savedItem('b.jpg', savedAtMs: 2),
      ]);
      await enableAds(tester);
      await arm(tester);
      await pumpScreen(tester, const SavedScreen());
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.bySemanticsLabel('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await afterPause(tester);
      expect(rig.adService.showCalls, 1);
      handle.dispose();
    });

    testScreen('saving a photo in the viewer counts', (
      WidgetTester tester,
    ) async {
      await enableAds(tester);
      await arm(tester);
      await pumpScreen(
        tester,
        _launcher(
          () => ViewerScreen(
            items: <StatusItem>[statusItem('p1.jpg', modifiedMs: 5)],
            initialIndex: 0,
            mode: ViewerMode.status,
          ),
        ),
        height: 1200,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();
      await afterPause(tester);
      expect(rig.adService.showCalls, 1);
    });

    testScreen('deleting in the Saved viewer counts', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<SavedItem> saved = <SavedItem>[
        savedItem('a.jpg', savedAtMs: 3),
        savedItem('b.jpg', savedAtMs: 2),
      ];
      rig.saved.items.addAll(saved);
      await enableAds(tester);
      await arm(tester);
      await pumpScreen(
        tester,
        _launcher(
          () => ViewerScreen(
            items: List<SavedItem>.of(saved),
            initialIndex: 0,
            mode: ViewerMode.saved,
          ),
        ),
        height: 1200,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      await afterPause(tester);
      expect(rig.adService.showCalls, 1);
      handle.dispose();
    });

    testScreen('closing the viewer counts', (WidgetTester tester) async {
      await enableAds(tester);
      await arm(tester);
      await pumpScreen(
        tester,
        _launcher(
          () => ViewerScreen(
            items: Rig.defaultItems(),
            initialIndex: 0,
            mode: ViewerMode.status,
          ),
        ),
        height: 1200,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await afterPause(tester);
      expect(rig.adService.showCalls, 1);
    });

    testScreen('swiping in the viewer counts but never shows the ad', (
      WidgetTester tester,
    ) async {
      await enableAds(tester);
      await arm(tester);
      await pumpScreen(
        tester,
        _launcher(
          () => ViewerScreen(
            items: <StatusItem>[
              statusItem('p1.jpg', modifiedMs: 5),
              statusItem('p2.jpg', modifiedMs: 4),
            ],
            initialIndex: 0,
            mode: ViewerMode.status,
          ),
        ),
        height: 1200,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      await afterPause(tester);
      expect(tally(), 7);
      expect(rig.services.settings.settings.adPending, isTrue);
      expect(rig.adService.showCalls, 0);
    });

    testScreen('the ad never appears over an open sheet', (
      WidgetTester tester,
    ) async {
      await rig.primeIn(tester);
      await enableAds(tester);
      await arm(tester);
      await pumpScreen(tester, const HomeScreen());
      await selectAndSave(tester, 2);
      // Open the Theme sheet during the pause.
      await tester.tap(find.byType(NavIconButton).at(0), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      await afterPause(tester);
      expect(rig.adService.showCalls, 0);
      expect(rig.services.settings.settings.adPending, isTrue);
    });
  });

  group('Settings rows for ads', () {
    testScreen('Remove ads is shown as Coming soon and is not tappable', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const SettingsScreen());
      expect(find.text('PRO'), findsOneWidget);
      expect(find.text('Remove ads'), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);
      await tester.tap(find.text('Remove ads'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testScreen('Privacy choices is hidden when not required', (
      WidgetTester tester,
    ) async {
      await enableAds(tester);
      await pumpScreen(tester, const SettingsScreen());
      expect(find.text('Privacy choices'), findsNothing);
    });

    testScreen('Privacy choices appears when required and reopens the form', (
      WidgetTester tester,
    ) async {
      rig.consent.outcome = const ConsentOutcome(
        canRequestAds: true,
        privacyOptionsRequired: true,
      );
      await enableAds(tester);
      await pumpScreen(tester, const SettingsScreen());
      expect(find.text('Privacy choices'), findsOneWidget);
      await tester.tap(find.text('Privacy choices'));
      await tester.pump();
      await tester.pump();
      expect(rig.consent.privacyCalls, 1);
    });
  });
}
