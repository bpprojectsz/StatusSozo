// A1 and A2: which language the whole app opens in, from the phone's language
// list (first install) and from a saved choice (restart).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/app/statussozo_app.dart';
import 'package:statussozo/core/models/app_language.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/screens/access_screen.dart';

import '../fakes/fakes.dart';
import '../screens/screen_harness.dart';

/// Opens the real app shell on a fresh install and reports what it shows.
Future<({String language, TextDirection direction})> _open(
  WidgetTester tester,
  Rig rig,
) async {
  await rig.run(tester, rig.services.settings.load);
  await tester.pumpWidget(StatusSozoApp(services: rig.services));
  await tester.pump();
  final BuildContext context = tester.element(find.byType(AccessScreen));
  return (
    language: AppLocalizations.of(context).localeName,
    direction: Directionality.of(context),
  );
}

Future<void> _close(WidgetTester tester, Rig rig) async {
  await tester.pumpWidget(const SizedBox());
  rig.dispose();
}

void main() {
  group('A1: first install follows the phone language list', () {
    // Each case: the phone's list, in order, and the language the app opens in.
    final Map<String, (List<Locale>, String)> cases =
        <String, (List<Locale>, String)>{
          for (final AppLanguage l in AppLanguages.all)
            'phone set to ${l.code}': (<Locale>[Locale(l.code)], l.code),
          'pt-BR': (<Locale>[const Locale('pt', 'BR')], 'pt'),
          'pt-PT': (<Locale>[const Locale('pt', 'PT')], 'pt'),
          'es-MX': (<Locale>[const Locale('es', 'MX')], 'es'),
          'zh-TW': (<Locale>[const Locale('zh', 'TW')], 'zh'),
          'zh-Hans-CN': (
            <Locale>[
              const Locale.fromSubtags(
                languageCode: 'zh',
                scriptCode: 'Hans',
                countryCode: 'CN',
              ),
            ],
            'zh',
          ),
          'en-GB': (<Locale>[const Locale('en', 'GB')], 'en'),
          'he-IL': (<Locale>[const Locale('he', 'IL')], 'he'),
          'ar-EG': (<Locale>[const Locale('ar', 'EG')], 'ar'),
          'an unsupported language': (<Locale>[const Locale('sw')], 'en'),
          'unsupported first, then French': (
            <Locale>[const Locale('sw'), const Locale('fr')],
            'fr',
          ),
          'unsupported twice, then Arabic': (
            <Locale>[const Locale('sw'), const Locale('xx'), const Locale('ar')],
            'ar',
          ),
          'German before French': (
            <Locale>[const Locale('de'), const Locale('fr')],
            'de',
          ),
        };

    cases.forEach((String name, (List<Locale>, String) c) {
      testWidgets('$name opens in ${c.$2}', (WidgetTester tester) async {
        tester.platformDispatcher.localesTestValue = c.$1;
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        final Rig rig = Rig();
        final ({String language, TextDirection direction}) shown = await _open(
          tester,
          rig,
        );
        expect(shown.language, c.$2);
        expect(
          shown.direction,
          AppLanguages.isRtl(c.$2) ? TextDirection.rtl : TextDirection.ltr,
        );
        await _close(tester, rig);
      });
    });
  });

  group('A2: a chosen language survives a restart', () {
    for (final AppLanguage language in AppLanguages.all) {
      testWidgets('${language.code} is still chosen after a restart', (
        WidgetTester tester,
      ) async {
        // The phone speaks something else, so only the saved choice can win.
        tester.platformDispatcher.localesTestValue = <Locale>[
          Locale(language.code == 'ja' ? 'de' : 'ja'),
        ];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);

        final FakeSettingsStore store = FakeSettingsStore();
        final Rig first = Rig(store: store);
        await first.run(tester, first.services.settings.load);
        await first.run(
          tester,
          () => first.services.locale.setLanguage(language.code),
        );
        expect(store.stored.languageCode, language.code);
        first.dispose();

        final Rig second = Rig(store: store);
        final ({String language, TextDirection direction}) shown = await _open(
          tester,
          second,
        );
        expect(shown.language, language.code);
        expect(
          shown.direction,
          language.rtl ? TextDirection.rtl : TextDirection.ltr,
        );
        await _close(tester, second);
      });
    }

    testWidgets('System default after a restart follows the phone again', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.localesTestValue = <Locale>[const Locale('fr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      final FakeSettingsStore store = FakeSettingsStore();
      final Rig first = Rig(store: store);
      await first.run(tester, first.services.settings.load);
      await first.run(tester, () => first.services.locale.setLanguage('ko'));
      await first.run(tester, () => first.services.locale.setLanguage(null));
      expect(store.stored.languageCode, isNull);
      first.dispose();

      final Rig second = Rig(store: store);
      final ({String language, TextDirection direction}) shown = await _open(
        tester,
        second,
      );
      expect(shown.language, 'fr');
      await _close(tester, second);
    });

    testWidgets('a chosen language beats the phone list', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.localesTestValue = <Locale>[const Locale('fr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final Rig rig = Rig();
      await rig.run(tester, rig.services.settings.load);
      await rig.run(tester, () => rig.services.locale.setLanguage('he'));
      await tester.pumpWidget(StatusSozoApp(services: rig.services));
      await tester.pump();
      final BuildContext context = tester.element(find.byType(AccessScreen));
      expect(AppLocalizations.of(context).localeName, 'he');
      expect(Directionality.of(context), TextDirection.rtl);
      await _close(tester, rig);
    });
  });
}
