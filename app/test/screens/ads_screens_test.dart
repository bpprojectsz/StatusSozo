import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/contracts/consent_service.dart';
import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/screens/access_screen.dart';
import 'package:statussozo/screens/home_screen.dart';
import 'package:statussozo/screens/saved_screen.dart';
import 'package:statussozo/screens/settings_screen.dart';
import 'package:statussozo/screens/viewer_screen.dart';
import 'package:statussozo/widgets/media/status_tile.dart';
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
    testScreen('a batch save of three items shows one', (
      WidgetTester tester,
    ) async {
      await rig.primeIn(tester);
      await enableAds(tester);
      await pumpScreen(tester, const HomeScreen());
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byType(StatusTile).at(1));
      await tester.pump();
      await tester.tap(find.byType(StatusTile).at(2));
      await tester.pump();
      await tester.tap(find.text('Save 3'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(rig.adService.showCalls, 1);
    });

    testScreen('saving a single item shows none', (WidgetTester tester) async {
      await rig.primeIn(tester);
      await enableAds(tester);
      await pumpScreen(tester, const HomeScreen());
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Save 1'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(rig.adService.showCalls, 0);
    });

    testScreen('a batch save with ads off shows none', (
      WidgetTester tester,
    ) async {
      rig.consent.outcome = const ConsentOutcome(
        canRequestAds: false,
        privacyOptionsRequired: false,
      );
      await rig.primeIn(tester);
      await pumpScreen(tester, const HomeScreen());
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byType(StatusTile).at(1));
      await tester.pump();
      await tester.tap(find.text('Save 2'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(rig.adService.showCalls, 0);
    });

    testScreen('deleting from Saved shows one', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      rig.saved.items.addAll(<SavedItem>[
        savedItem('a.jpg', savedAtMs: 3),
        savedItem('b.jpg', savedAtMs: 2),
      ]);
      await enableAds(tester);
      await pumpScreen(tester, const SavedScreen());
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.bySemanticsLabel('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(rig.adService.showCalls, 1);
      handle.dispose();
    });

    testScreen('only every fifth viewer close shows one', (
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
      for (int i = 1; i <= 5; i++) {
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
        expect(
          rig.adService.showCalls,
          i < 5 ? 0 : 1,
          reason: 'after close $i',
        );
      }
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
