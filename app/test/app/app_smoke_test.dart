import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/app/app_gate.dart';
import 'package:statussozo/app/error_handling.dart';
import 'package:statussozo/app/statussozo_app.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/screens/access_screen.dart';
import 'package:statussozo/screens/error_fallback_screen.dart';
import 'package:statussozo/screens/home_screen.dart';
import 'package:statussozo/widgets/media/status_tile.dart';

import '../screens/screen_harness.dart';

void main() {
  late Rig rig;
  late PlatformRecorder platform;
  void testApp(
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

  testApp('no grants shows the access screen', (WidgetTester tester) async {
    await rig.run(tester, rig.services.settings.load);
    await tester.pumpWidget(StatusSozoApp(services: rig.services));
    await tester.pump();
    expect(find.byType(AccessScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Connect your status folder'), findsOneWidget);
  });

  testApp('a grant shows Home and its tiles', (WidgetTester tester) async {
    await rig.primeIn(tester);
    await tester.pumpWidget(StatusSozoApp(services: rig.services));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(StatusTile), findsNWidgets(3));
  });

  testApp('every grant lost shows the renewal screen', (
    WidgetTester tester,
  ) async {
    rig.status.lostAccess.add(StatusSource.standard);
    await rig.primeIn(tester);
    await tester.pumpWidget(StatusSozoApp(services: rig.services));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Access needs to be renewed'), findsOneWidget);
  });

  testApp('the theme switch cross-fades without error', (
    WidgetTester tester,
  ) async {
    await rig.primeIn(tester);
    await tester.pumpWidget(StatusSozoApp(services: rig.services));
    await tester.pump();
    await rig.run(
      tester,
      () => rig.services.theme.setPreference(ThemePreference.dark),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    final MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testApp('a resume refreshes the list', (WidgetTester tester) async {
    await rig.primeIn(tester);
    await tester.pumpWidget(StatusSozoApp(services: rig.services));
    await tester.pump();
    final int before = rig.status.listCalls;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 500));
    expect(rig.status.listCalls, greaterThan(before));
  });

  testApp('a thrown error shows the fallback, not a grey box', (
    WidgetTester tester,
  ) async {
    final void Function() restore = installGlobalErrorHandling(
      rig.services,
      useFallbackWidget: true,
    );
    try {
      await tester.pumpWidget(
        Builder(builder: (BuildContext context) => throw StateError('boom')),
      );
      expect(find.byType(ErrorFallbackScreen), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
    } finally {
      restore();
    }
  });

  testApp('the gate pumps in RTL without overflow', (
    WidgetTester tester,
  ) async {
    await rig.primeIn(tester);
    await tester.pumpWidget(
      screenApp(rig, const AppGate(), direction: TextDirection.rtl),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
