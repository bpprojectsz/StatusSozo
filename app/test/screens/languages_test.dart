import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/app/statussozo_app.dart';
import 'package:statussozo/core/models/app_language.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/screens/access_screen.dart';
import 'package:statussozo/screens/debug_logs_screen.dart';
import 'package:statussozo/screens/home_screen.dart';
import 'package:statussozo/screens/saved_screen.dart';
import 'package:statussozo/screens/settings_screen.dart';
import 'package:statussozo/utils/app_log.dart';

import '../widgets/harness.dart';
import 'screen_harness.dart';

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
    AppLog.clear();
  });
  tearDown(() {
    platform.uninstall();
    rig.dispose();
  });

  for (final AppLanguage language in AppLanguages.all) {
    for (final double scale in <double>[1, 2]) {
      testScreen(
        'every screen renders in ${language.code} at ${scale}x text',
        (WidgetTester tester) async {
          useSurface(tester, height: 2600);
          final Locale locale = Locale(language.code);
          await rig.primeIn(tester);
          AppLog.info('t', 'a log line to display');

          final List<Widget> screens = <Widget>[
            const AccessScreen(),
            const AccessScreen(mode: AccessMode.renewal),
            const HomeScreen(),
            const SavedScreen(),
            const SettingsScreen(),
            const DebugLogsScreen(),
          ];
          for (final Widget screen in screens) {
            await tester.pumpWidget(
              screenApp(rig, screen, locale: locale, textScale: scale),
            );
            await tester.pump(const Duration(milliseconds: 600));
            expect(
              tester.takeException(),
              isNull,
              reason: '${screen.runtimeType} in ${language.code}',
            );
            final BuildContext context = tester.element(
              find.byType(screen.runtimeType),
            );
            expect(
              AppLocalizations.of(context).localeName,
              language.code,
              reason: 'locale was not applied',
            );
            expect(
              Directionality.of(context),
              language.rtl ? TextDirection.rtl : TextDirection.ltr,
            );
          }
        },
      );
    }
  }

  group('the language row and sheet', () {
    Future<void> pumpSettings(WidgetTester tester) async {
      useSurface(tester, height: 2600);
      await tester.pumpWidget(screenApp(rig, const SettingsScreen()));
      await tester.pump();
    }

    testScreen('shows System default until a language is chosen', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      expect(find.text('System default'), findsOneWidget);
    });

    testScreen('the sheet lists System default and all 11 languages', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      await tester.tap(find.text('System default'));
      await tester.pumpAndSettle();
      for (final AppLanguage language in AppLanguages.all) {
        expect(find.text(language.nativeName), findsOneWidget);
      }
      expect(find.text('System default'), findsNWidgets(2));
    });

    testScreen('choosing a language applies it and updates the row', (
      WidgetTester tester,
    ) async {
      await pumpSettings(tester);
      await tester.tap(find.text('System default'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      expect(rig.services.locale.value, 'de');
      expect(find.text('Deutsch'), findsOneWidget);
    });

    testScreen('choosing System default clears the language', (
      WidgetTester tester,
    ) async {
      await rig.run(tester, () => rig.services.locale.setLanguage('fr'));
      await pumpSettings(tester);
      await tester.tap(find.text('Français'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('System default'));
      await tester.pumpAndSettle();
      expect(rig.services.locale.value, isNull);
    });
  });

  group('the app follows the chosen language', () {
    testScreen('the whole app switches language and direction', (
      WidgetTester tester,
    ) async {
      await rig.run(tester, rig.services.settings.load);
      await tester.pumpWidget(StatusSozoApp(services: rig.services));
      await tester.pump();
      expect(find.text('Connect your status folder'), findsOneWidget);

      await rig.run(tester, () => rig.services.locale.setLanguage('ar'));
      await tester.pumpAndSettle();
      final BuildContext context = tester.element(find.byType(AccessScreen));
      expect(AppLocalizations.of(context).localeName, 'ar');
      expect(Directionality.of(context), TextDirection.rtl);
      expect(find.text('Connect your status folder'), findsNothing);

      await rig.run(tester, () => rig.services.locale.setLanguage(null));
      await tester.pumpAndSettle();
      expect(find.text('Connect your status folder'), findsOneWidget);
    });
  });
}
