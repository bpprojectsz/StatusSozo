import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/providers/settings_provider.dart';
import 'package:statussozo/core/providers/source_provider.dart';
import 'package:statussozo/core/providers/theme_provider.dart';

import '../../fakes/fakes.dart';

void main() {
  late FakeSettingsStore store;
  late SettingsProvider settings;

  setUp(() {
    store = FakeSettingsStore();
    settings = SettingsProvider(store);
  });
  tearDown(() => settings.dispose());

  group('SettingsProvider', () {
    test('starts with defaults and not loaded', () {
      expect(settings.value.loaded, isFalse);
      expect(settings.settings, AppSettings.defaults());
    });

    test('load success', () async {
      store.stored = AppSettings.defaults().copyWith(
        themePreference: ThemePreference.dark,
      );
      await settings.load();
      expect(settings.value.loaded, isTrue);
      expect(settings.settings.themePreference, ThemePreference.dark);
      expect(settings.value.persistenceWarning, isFalse);
      expect(settings.value.recovered, isFalse);
    });

    test('a corrupt store sets recovered, and it is consumed once', () async {
      store.recovered = true;
      await settings.load();
      expect(settings.value.recovered, isTrue);
      expect(settings.consumeRecovered(), isTrue);
      expect(settings.consumeRecovered(), isFalse);
      expect(settings.value.recovered, isFalse);
    });

    test('unavailable persistence at load sets the warning', () async {
      store.persistenceAvailable = false;
      await settings.load();
      expect(settings.value.persistenceWarning, isTrue);
    });

    test('update applies in memory before the write finishes', () async {
      await settings.load();
      store.delay = const Duration(milliseconds: 30);
      final Future<void> write = settings.update(
        (AppSettings s) => s.copyWith(themePreference: ThemePreference.light),
      );
      expect(settings.settings.themePreference, ThemePreference.light);
      expect(store.saves, isEmpty);
      await write;
      expect(store.saves, hasLength(1));
      expect(store.stored.themePreference, ThemePreference.light);
    });

    test('a failing save sets the warning and keeps the value', () async {
      await settings.load();
      store.failSave = true;
      await settings.update(
        (AppSettings s) => s.copyWith(themePreference: ThemePreference.dark),
      );
      expect(settings.value.persistenceWarning, isTrue);
      expect(settings.settings.themePreference, ThemePreference.dark);
      expect(store.saves, isEmpty);
    });

    test('a later successful save clears the warning', () async {
      await settings.load();
      store.failSave = true;
      await settings.update(
        (AppSettings s) => s.copyWith(themePreference: ThemePreference.dark),
      );
      store.failSave = false;
      await settings.update(
        (AppSettings s) => s.copyWith(themePreference: ThemePreference.light),
      );
      expect(settings.value.persistenceWarning, isFalse);
      expect(store.stored.themePreference, ThemePreference.light);
    });

    test('rapid updates are serialised and the last value wins', () async {
      await settings.load();
      store.delay = const Duration(milliseconds: 10);
      final Future<void> a = settings.update(
        (AppSettings s) => s.copyWith(themePreference: ThemePreference.dark),
      );
      final Future<void> b = settings.update(
        (AppSettings s) => s.copyWith(languageCode: 'fr'),
      );
      await Future.wait<void>(<Future<void>>[a, b]);
      expect(store.stored.themePreference, ThemePreference.dark);
      expect(store.stored.languageCode, 'fr');
    });

    test('notifies listeners on change', () async {
      int notifications = 0;
      settings.addListener(() => notifications++);
      await settings.load();
      expect(notifications, 1);
    });
  });

  group('ThemeProvider', () {
    late ThemeProvider theme;
    setUp(() => theme = ThemeProvider(settings));
    tearDown(() => theme.dispose());

    test('starts from settings', () {
      expect(theme.value, ThemePreference.system);
    });

    test('setPreference applies at once and persists', () async {
      final Future<void> write = theme.setPreference(ThemePreference.dark);
      expect(theme.value, ThemePreference.dark);
      await write;
      expect(store.stored.themePreference, ThemePreference.dark);
    });

    test('follows changes made to settings', () async {
      await settings.update(
        (AppSettings s) => s.copyWith(themePreference: ThemePreference.light),
      );
      expect(theme.value, ThemePreference.light);
    });

    test('follows a load', () async {
      store.stored = AppSettings.defaults().copyWith(
        themePreference: ThemePreference.dark,
      );
      await settings.load();
      expect(theme.value, ThemePreference.dark);
    });

    test('exposes every preference', () {
      expect(ThemePreference.values, hasLength(3));
    });
  });

  group('SourceProvider', () {
    late SourceProvider source;
    setUp(() => source = SourceProvider(settings));
    tearDown(() => source.dispose());

    test('starts from settings', () {
      expect(source.value, StatusSource.standard);
    });

    test('select notifies only on change', () async {
      int notifications = 0;
      source.addListener(() => notifications++);
      await source.select(StatusSource.standard);
      expect(notifications, 0);
      await source.select(StatusSource.business);
      expect(notifications, 1);
      await source.select(StatusSource.business);
      expect(notifications, 1);
    });

    test('select persists', () async {
      await source.select(StatusSource.business);
      expect(store.stored.lastSource, StatusSource.business);
    });

    test('follows changes made to settings', () async {
      await settings.update(
        (AppSettings s) => s.copyWith(lastSource: StatusSource.business),
      );
      expect(source.value, StatusSource.business);
    });
  });
}
