import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/models/app_language.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/providers/locale_provider.dart';
import 'package:statussozo/core/providers/settings_provider.dart';

import '../../fakes/fakes.dart';

void main() {
  late FakeSettingsStore store;
  late SettingsProvider settings;
  late LocaleProvider locale;

  setUp(() async {
    store = FakeSettingsStore();
    settings = SettingsProvider(store);
    await settings.load();
    locale = LocaleProvider(settings);
  });
  tearDown(() {
    locale.dispose();
    settings.dispose();
  });

  test('follows the system by default', () {
    expect(locale.value, isNull);
  });

  test('a chosen language applies at once and is saved', () async {
    await locale.setLanguage('de');
    expect(locale.value, 'de');
    expect(settings.settings.languageCode, 'de');
    expect(store.saves.last.languageCode, 'de');
  });

  test('choosing System default clears the saved language', () async {
    await locale.setLanguage('fr');
    await locale.setLanguage(null);
    expect(locale.value, isNull);
    expect(settings.settings.languageCode, isNull);
    expect(store.saves.last.languageCode, isNull);
  });

  test('a language the app does not have is ignored', () async {
    await locale.setLanguage('xx');
    expect(locale.value, isNull);
    expect(settings.settings.languageCode, isNull);
  });

  test('a stored unsupported language is treated as System default', () async {
    final FakeSettingsStore other = FakeSettingsStore()
      ..stored = AppSettings.defaults().copyWith(languageCode: 'xx');
    final SettingsProvider s = SettingsProvider(other);
    await s.load();
    final LocaleProvider p = LocaleProvider(s);
    expect(p.value, isNull);
    p.dispose();
    s.dispose();
  });

  test('a stored supported language is restored', () async {
    final FakeSettingsStore other = FakeSettingsStore()
      ..stored = AppSettings.defaults().copyWith(languageCode: 'ja');
    final SettingsProvider s = SettingsProvider(other);
    await s.load();
    final LocaleProvider p = LocaleProvider(s);
    expect(p.value, 'ja');
    p.dispose();
    s.dispose();
  });

  test('changes made elsewhere in settings are followed', () async {
    await settings.update((AppSettings s) => s.copyWith(languageCode: 'ko'));
    expect(locale.value, 'ko');
  });

  test('the language list has the 11 languages and marks Arabic and Hebrew', () {
    expect(AppLanguages.codes, <String>[
      'en',
      'es',
      'fr',
      'de',
      'pt',
      'ar',
      'hi',
      'ja',
      'ko',
      'zh',
      'he',
    ]);
    expect(AppLanguages.isRtl('ar'), isTrue);
    expect(AppLanguages.isRtl('he'), isTrue);
    expect(AppLanguages.isRtl('en'), isFalse);
    expect(AppLanguages.isRtl(null), isFalse);
    expect(AppLanguages.byCode('xx'), isNull);
  });
}
