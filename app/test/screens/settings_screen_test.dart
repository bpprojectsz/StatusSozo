import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/providers/toast_provider.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/screens/settings_screen.dart';
import 'package:statussozo/widgets/primitives/primary_button.dart';
import 'package:statussozo/widgets/primitives/segmented_tabs.dart';

import '../widgets/harness.dart';
import 'screen_harness.dart';

Widget _launcher() {
  return Builder(
    builder: (BuildContext context) => PrimaryButton(
      label: 'Open',
      onPressed: () => Navigator.of(context).push(
        AppPageRoute<void>(builder: (_) => const SettingsScreen()),
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
  setUp(() => rig = Rig());
  tearDown(() => rig.dispose());

  Future<void> pumpSettings(
    WidgetTester tester, {
    TextDirection direction = TextDirection.ltr,
    bool dark = false,
    double scale = 1,
  }) async {
    useSurface(tester, height: 1200);
    await tester.pumpWidget(
      screenApp(
        rig,
        _launcher(),
        direction: direction,
        dark: dark,
        textScale: scale,
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  group('layout', () {
    testScreen('shows every section header in uppercase', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      for (final String header in <String>[
        'APPEARANCE',
        'FOLDERS',
        'SUPPORT',
        'ABOUT',
      ]) {
        expect(find.text(header), findsOneWidget);
      }
      expect(find.text('Settings'), findsOneWidget);
    });

    for (final bool dark in <bool>[false, true]) {
      for (final TextDirection direction in TextDirection.values) {
        testScreen(
          '${dark ? 'dark' : 'light'} ${direction.name} at 2x text',
          (WidgetTester tester) async {
            await pumpSettings(tester, direction: direction, dark: dark, scale: 2);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testScreen('back returns to the previous screen', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSettings(tester);
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsNothing);
      handle.dispose();
    });
  });

  group('appearance', () {
    testScreen('changing the theme applies it and persists it', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      expect(rig.services.theme.value, ThemePreference.system);
      await tester.tap(find.text('Dark'));
      await tester.pump();
      expect(rig.services.theme.value, ThemePreference.dark);
      await tester.pump(const Duration(milliseconds: 300));
      expect(rig.store.stored.themePreference, ThemePreference.dark);

      await tester.tap(find.text('Light'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(rig.store.stored.themePreference, ThemePreference.light);
    });

    testScreen('the selected segment follows the current theme', (
      WidgetTester tester,
    ) async {
      await rig.run(tester, () => rig.services.theme.setPreference(ThemePreference.dark));
      await pumpSettings(tester);
      final SegmentedTabs<ThemePreference> tabs = tester
          .widget<SegmentedTabs<ThemePreference>>(
            find.byType(SegmentedTabs<ThemePreference>),
          );
      expect(tabs.value, ThemePreference.dark);
    });
  });

  group('folders', () {
    testScreen('shows each source with its connection state', (
      WidgetTester tester,
    ) async {
      await rig.primeIn(tester);
      await pumpSettings(tester);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Not connected'), findsOneWidget);
    });

    testScreen('a source whose access was lost says so', (
      WidgetTester tester,
    ) async {
      await rig.primeIn(tester);
      rig.status.lostAccess.add(StatusSource.standard);
      await rig.run(tester, () => rig.services.folderAccess.verifyAll());
      await pumpSettings(tester);
      expect(find.text('Access needs to be renewed'), findsOneWidget);
    });

    testScreen('a connected folder offers Choose again and Disconnect', (
      WidgetTester tester,
    ) async {
      await rig.primeIn(tester);
      await pumpSettings(tester);
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();
      expect(find.text('Choose folder again'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
    });

    testScreen('an unconnected folder offers only Choose again', (
      WidgetTester tester,
    ) async {
      await rig.primeIn(tester);
      await pumpSettings(tester);
      await tester.tap(find.text('Business'));
      await tester.pumpAndSettle();
      expect(find.text('Choose folder again'), findsOneWidget);
      expect(find.text('Disconnect'), findsNothing);
    });

    testScreen('Disconnect releases the grant and says so', (
      WidgetTester tester,
    ) async {
      await rig.primeIn(tester);
      await pumpSettings(tester);
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
      expect(rig.status.released, hasLength(1));
      expect(rig.services.settings.settings.grants, isEmpty);
      expect(rig.services.toasts.value?.code, ToastCode.folderDisconnected);
      expect(find.text('Not connected'), findsNWidgets(2));
    });

    testScreen('Choose folder again opens the connect screen', (
      WidgetTester tester,
    ) async {
      await rig.primeIn(tester);
      await pumpSettings(tester);
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose folder again'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the folder again'), findsOneWidget);
    });
  });

  group('support and about', () {
    testScreen('Rate the app opens the store listing', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      await tester.tap(find.text('Rate the app'));
      await tester.pump();
      expect(rig.links.storeListingOpened, 1);
    });

    testScreen('Send feedback prefills the version and the local log', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      await tester.tap(find.text('Send feedback'));
      await tester.pump();
      final email = rig.links.emails.single;
      expect(email.to, AppConfig.supportEmail);
      expect(email.subject, 'StatusSozo feedback (1.0.0 (1))');
      expect(email.body, startsWith('Write your feedback above this line.'));
      expect(email.body, contains('---'));
    });

    testScreen('Privacy policy opens the policy page', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      await tester.tap(find.text('Privacy policy'));
      await tester.pump();
      expect(rig.links.opened.single.toString(), AppConfig.privacyUrl);
    });

    testScreen('a link that cannot be opened shows a toast', (
      WidgetTester tester,
    ) async {
      rig.links.succeed = false;
      await pumpSettings(tester);
      await tester.tap(find.text('Privacy policy'));
      await tester.pump();
      await tester.pump();
      expect(rig.services.toasts.value?.code, ToastCode.linkFailed);
    });

    testScreen('shows the version and the unaffiliated disclaimer', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      expect(find.text('Version'), findsOneWidget);
      expect(find.text('1.0.0 (1)'), findsOneWidget);
      expect(
        find.text(
          'StatusSozo is an independent app and is not affiliated with or endorsed by any messaging service. Only save and share content you have the right to use.',
        ),
        findsOneWidget,
      );
    });
  });
}
