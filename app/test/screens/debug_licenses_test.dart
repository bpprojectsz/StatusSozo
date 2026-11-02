import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/screens/debug_logs_screen.dart';
import 'package:statussozo/screens/licenses_screen.dart';
import 'package:statussozo/utils/app_log.dart';
import 'package:statussozo/widgets/primitives/primary_button.dart';

import '../widgets/harness.dart';
import 'screen_harness.dart';

Widget _launcher(Widget screen) {
  return Builder(
    builder: (BuildContext context) => PrimaryButton(
      label: 'Open',
      onPressed: () => Navigator.of(context).push(
        AppPageRoute<void>(builder: (_) => screen),
      ),
    ),
  );
}

void main() {
  late Rig rig;
  void testScreen(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => screenTest(description, () => rig, body);
  setUp(() {
    rig = Rig();
    AppLog.clear();
    LicenseRegistry.reset();
  });
  tearDown(() {
    rig.dispose();
    LicenseRegistry.reset();
  });

  Future<void> open(
    WidgetTester tester,
    Widget screen, {
    TextDirection direction = TextDirection.ltr,
    double scale = 1,
    bool settle = true,
  }) async {
    useSurface(tester, height: 1200);
    await tester.pumpWidget(
      screenApp(
        rig,
        _launcher(screen),
        direction: direction,
        textScale: scale,
      ),
    );
    await tester.tap(find.text('Open'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  group('DebugLogsScreen', () {
    testScreen('says so when nothing was logged', (WidgetTester tester) async {
      await open(tester, const DebugLogsScreen());
      expect(find.text('Nothing logged'), findsOneWidget);
    });

    testScreen('lists entries newest first', (WidgetTester tester) async {
      AppLog.info('t', 'first entry');
      AppLog.info('t', 'second entry');
      await open(tester, const DebugLogsScreen());
      final Offset first = tester.getTopLeft(find.textContaining('first entry'));
      final Offset second = tester.getTopLeft(
        find.textContaining('second entry'),
      );
      expect(second.dy, lessThan(first.dy));
    });

    testScreen('Send report opens an email with the log', (
      WidgetTester tester,
    ) async {
      AppLog.info('t', 'something happened');
      await open(tester, const DebugLogsScreen());
      await tester.tap(find.bySemanticsLabel('Send report'));
      await tester.pump();
      final email = rig.links.emails.single;
      expect(email.to, AppConfig.supportEmail);
      expect(email.body, contains('something happened'));
    });

    testScreen('Clear asks first and then empties the log', (
      WidgetTester tester,
    ) async {
      AppLog.info('t', 'to be removed');
      await open(tester, const DebugLogsScreen());
      await tester.tap(find.bySemanticsLabel('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Clear the log?'), findsOneWidget);
      expect(AppLog.count, 1);
      await tester.tap(find.text('Clear').last);
      await tester.pumpAndSettle();
      expect(AppLog.count, 0);
      expect(find.text('Nothing logged'), findsOneWidget);
    });

    testScreen('cancelling the confirmation keeps the log', (
      WidgetTester tester,
    ) async {
      AppLog.info('t', 'keep me');
      await open(tester, const DebugLogsScreen());
      await tester.tap(find.bySemanticsLabel('Clear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(AppLog.count, 1);
    });

    testScreen('renders in RTL at 2x text without overflow', (
      WidgetTester tester,
    ) async {
      AppLog.info('t', 'a fairly long line that has to wrap at large text sizes');
      await open(
        tester,
        const DebugLogsScreen(),
        direction: TextDirection.rtl,
        scale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('LicensesScreen', () {
    testScreen('lists the packages and opens one license', (
      WidgetTester tester,
    ) async {
      LicenseRegistry.addLicense(() async* {
        yield const LicenseEntryWithLineBreaks(<String>['pkg_b'], 'Licence text B');
        yield const LicenseEntryWithLineBreaks(<String>['pkg_a'], 'Licence text A');
      });
      await open(tester, const LicensesScreen());
      final Offset a = tester.getTopLeft(find.text('pkg_a'));
      final Offset b = tester.getTopLeft(find.text('pkg_b'));
      expect(a.dy, lessThan(b.dy));
      await tester.tap(find.text('pkg_a'));
      await tester.pumpAndSettle();
      expect(find.text('Licence text A'), findsOneWidget);
      expect(find.text('Licence text B'), findsNothing);
    });

    testScreen('says so when no licenses are available', (
      WidgetTester tester,
    ) async {
      await open(tester, const LicensesScreen());
      expect(find.text('No licenses found'), findsOneWidget);
    });

    testScreen('treats a failing license source as empty', (
      WidgetTester tester,
    ) async {
      LicenseRegistry.addLicense(
        () => Stream<LicenseEntry>.error(StateError('x')),
      );
      await open(tester, const LicensesScreen(), settle: false);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text('No licenses found'), findsOneWidget);
    });
  });
}
