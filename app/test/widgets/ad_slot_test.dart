import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/contracts/ad_service.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/widgets/ads/ad_slot.dart';

import '../fakes/fakes.dart';
import '../screens/screen_harness.dart';

void main() {
  late FakeAdService service;
  late ValueNotifier<bool> enabled;
  late Rig rig;

  setUp(() {
    service = FakeAdService();
    enabled = ValueNotifier<bool>(true);
    rig = Rig();
  });
  tearDown(() {
    enabled.dispose();
    rig.dispose();
  });

  Widget slot({double gap = AppSizes.adSlotGapAbove, bool safe = false}) =>
      Align(
        alignment: Alignment.bottomCenter,
        child: AdSlot(
          service: service,
          enabled: enabled,
          gapAbove: gap,
          safeBottom: safe,
        ),
      );

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(screenApp(rig, child));
    await tester.pump();
  }

  final Finder banner = find.byKey(const ValueKey<String>('fake-banner'));

  testWidgets('is zero height while ads are off', (WidgetTester tester) async {
    enabled.value = false;
    await pump(tester, slot());
    expect(banner, findsNothing);
    expect(tester.getSize(find.byType(AdSlot)), Size.zero);
    expect(service.banners, isEmpty);
  });

  testWidgets('asks for a banner as wide as the screen', (
    WidgetTester tester,
  ) async {
    await pump(tester, slot());
    expect(service.bannerWidths, <int>[800]);
  });

  testWidgets('shows the ad with the gap above and a hairline border', (
    WidgetTester tester,
  ) async {
    await pump(tester, slot());
    expect(banner, findsOneWidget);
    expect(
      tester.getSize(find.byType(AdSlot)).height,
      AppSizes.adSlotGapAbove + AppSizes.hairline + 50,
    );
  });

  testWidgets('has no gap, border or placeholder while the ad loads', (
    WidgetTester tester,
  ) async {
    service.banners.clear();
    await pump(tester, slot());
    service.banners.single.set(AdState.loading);
    await tester.pump();
    expect(banner, findsNothing);
    expect(tester.getSize(find.byType(AdSlot)), Size.zero);
  });

  testWidgets('collapses again when the ad fails', (
    WidgetTester tester,
  ) async {
    await pump(tester, slot());
    service.banners.single.set(AdState.failed);
    await tester.pump();
    expect(tester.getSize(find.byType(AdSlot)), Size.zero);
  });

  testWidgets('collapses while the keyboard is open', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(800, 600),
          viewInsets: EdgeInsets.only(bottom: 300),
        ),
        child: screenApp(rig, slot()),
      ),
    );
    await tester.pump();
    expect(tester.getSize(find.byType(AdSlot)), Size.zero);
  });

  testWidgets('a larger gap is honoured', (WidgetTester tester) async {
    await pump(tester, slot(gap: AppSpacing.lg));
    expect(
      tester.getSize(find.byType(AdSlot)).height,
      AppSpacing.lg + AppSizes.hairline + 50,
    );
  });

  testWidgets('announces itself as an advertisement', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pump(tester, slot());
    expect(find.bySemanticsLabel('Advertisement'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('releases the banner when ads are switched off', (
    WidgetTester tester,
  ) async {
    await pump(tester, slot());
    final FakeBanner first = service.banners.single;
    enabled.value = false;
    await tester.pump();
    expect(first.disposeCalls, 1);
    expect(tester.getSize(find.byType(AdSlot)), Size.zero);
    enabled.value = true;
    await tester.pump();
    expect(service.banners, hasLength(2));
  });

  testWidgets('releases the banner when the screen goes away', (
    WidgetTester tester,
  ) async {
    await pump(tester, slot());
    final FakeBanner first = service.banners.single;
    await tester.pumpWidget(screenApp(rig, const SizedBox()));
    await tester.pump();
    expect(first.disposeCalls, 1);
  });

  testWidgets('a covered screen keeps no banner, and gets one back', (
    WidgetTester tester,
  ) async {
    final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      screenApp(
        rig,
        Navigator(
          key: navigator,
          onGenerateRoute: (RouteSettings s) => MaterialPageRoute<void>(
            builder: (_) => Align(
              alignment: Alignment.bottomCenter,
              child: AdSlot(service: service, enabled: enabled),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final FakeBanner first = service.banners.single;
    expect(first.disposeCalls, 0);

    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const SizedBox()),
      ),
    );
    await tester.pumpAndSettle();
    expect(first.disposeCalls, 1);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(service.banners, hasLength(2));
    expect(banner, findsOneWidget);
  });

  testWidgets('asks for a new banner after resume when the last one failed', (
    WidgetTester tester,
  ) async {
    await pump(tester, slot());
    service.banners.single.set(AdState.failed);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.banners, hasLength(2));
  });
}
