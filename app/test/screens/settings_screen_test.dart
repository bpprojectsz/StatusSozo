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
    testWidgets('shows every section header in uppercase', (
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
        testWidgets(
          '${dark ? 'dark' : 'light'} ${direction.name} at 2x text',
          (WidgetTester tester) async {
            await pumpSettings(tester, direction: direction, dark: dark, scale: 2);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('back returns to the previous screen', (
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
    testWidgets('changing the theme applies it and persists it', (
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

    testWidgets('the selected segment follows the current theme', (
      WidgetTester tester,
    ) async {
      await rig.services.theme.setPreference(ThemePreference.dark);
      await pumpSettings(tester);
      final SegmentedTabs<ThemePreference> tabs = tester
          .widget<SegmentedTabs<ThemePreference>>(
            find.byType(SegmentedTabs<ThemePreference>),
          );
      expect(tabs.value, ThemePreference.dark);
    });
  });

  group('folders', () {
    testWidgets('shows each source with its connection state', (
      WidgetTester tester,
    ) async {
      await rig.prime();
      await pumpSettings(tester);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Not connected'), findsOneWidget);
    });

    testWidgets('a source whose access was lost says so', (
      WidgetTester tester,
    ) async {
      await rig.prime();
      rig.status.lostAccess.add(StatusSource.standard);
      await rig.services.folderAccess.verifyAll();
      await pumpSettings(tester);
      expect(find.text('Access needs to be renewed'), findsOneWidget);
    });

    testWidgets('a connected folder offers Choose again and Disconnect', (
      WidgetTester tester,
    ) async {
      await rig.prime();
      await pumpSettings(tester);
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();
      expect(find.text('Choose folder again'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
    });

    testWidgets('an unconnected folder offers only Choose again', (
      WidgetTester tester,
    ) async {
      await rig.prime();
      await pumpSettings(tester);
      await tester.tap(find.text('Business'));
      await tester.pumpAndSettle();
      expect(find.text('Choose folder again'), findsOneWidget);
      expect(find.text('Disconnect'), findsNothing);
    });

    testWidgets('Disconnect releases the grant and says so', (
      WidgetTester tester,
    ) async {
      await rig.prime();
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

    testWidgets('Choose folder again opens the connect screen', (
      WidgetTester tester,
    ) async {
      await rig.prime();
      await pumpSettings(tester);
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose folder again'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the folder again'), findsOneWidget);
    });
  });

  group('support and about', () {
    testWidgets('Rate the app opens the store listing', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      await tester.tap(find.text('Rate the app'));
      await tester.pump();
      expect(rig.links.storeListingOpened, 1);
    });

    testWidgets('Send feedback prefills the version and the local log', (
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

    testWidgets('Privacy policy opens the policy page', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      await tester.tap(find.text('Privacy policy'));
      await tester.pump();
      expect(rig.links.opened.single.toString(), AppConfig.privacyUrl);
    });

    testWidgets('a link that cannot be opened shows a toast', (
      WidgetTester tester,
    ) async {
      rig.links.succeed = false;
      await pumpSettings(tester);
      await tester.tap(find.text('Privacy policy'));
      await tester.pump();
      await tester.pump();
      expect(rig.services.toasts.value?.code, ToastCode.linkFailed);
    });

    testWidgets('shows the version and the unaffiliated disclaimer', (
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
