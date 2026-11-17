import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/providers/review_provider.dart';
import 'package:statussozo/core/providers/settings_provider.dart';

import '../../fakes/fakes.dart';

void main() {
  late FakeReviewService service;
  late FakeSettingsStore store;
  late SettingsProvider settings;
  late DateTime clock;
  late bool adBusy;
  late ReviewProvider review;

  setUp(() async {
    service = FakeReviewService();
    store = FakeSettingsStore();
    settings = SettingsProvider(store);
    await settings.load();
    clock = DateTime(2026, 11, 3, 12);
    adBusy = false;
    review = ReviewProvider(
      settings: settings,
      service: service,
      adBusy: () => adBusy,
      now: () => clock,
    );
  });
  tearDown(() => settings.dispose());

  void nextDay() => clock = clock.add(const Duration(days: 1));

  group('counting', () {
    test('counts saved items and different days', () async {
      await review.onSaved(3);
      await review.onSaved(2);
      expect(settings.settings.reviewSaves, 5);
      expect(settings.settings.reviewDays, 1);
      nextDay();
      await review.onSaved(1);
      expect(settings.settings.reviewSaves, 6);
      expect(settings.settings.reviewDays, 2);
      expect(settings.settings.reviewLastDay, '2026-11-04');
    });

    test('ignores a save of nothing', () async {
      await review.onSaved(0);
      await review.onSaved(-1);
      expect(settings.settings.reviewSaves, 0);
      expect(settings.settings.reviewDays, 0);
    });

    test('is saved to the store', () async {
      await review.onSaved(4);
      expect(store.saves.last.reviewSaves, 4);
    });
  });

  group('the first request', () {
    Future<void> reachThreshold() async {
      await review.onSaved(4);
      nextDay();
      await review.onSaved(3);
      nextDay();
      await review.onSaved(3);
    }

    test('not before ten saves', () async {
      await review.onSaved(4);
      nextDay();
      await review.onSaved(3);
      nextDay();
      await review.onSaved(2);
      expect(settings.settings.reviewSaves, 9);
      expect(service.requestCalls, 0);
    });

    test('not before three different days', () async {
      await review.onSaved(6);
      await review.onSaved(6);
      nextDay();
      await review.onSaved(6);
      expect(settings.settings.reviewSaves, 18);
      expect(settings.settings.reviewDays, 2);
      expect(service.requestCalls, 0);
    });

    test('asks once the thresholds are met', () async {
      await reachThreshold();
      expect(service.requestCalls, 1);
      expect(settings.settings.reviewAskCount, 1);
      expect(
        settings.settings.reviewLastAskedMs,
        clock.millisecondsSinceEpoch,
      );
    });

    test('does not ask while an ad is busy, and asks later', () async {
      adBusy = true;
      await reachThreshold();
      expect(service.requestCalls, 0);
      expect(settings.settings.reviewAskCount, 0);
      adBusy = false;
      await review.onSaved(1);
      expect(service.requestCalls, 1);
    });

    test('does not ask when the system cannot show it, and asks later', () async {
      service.available = false;
      await reachThreshold();
      expect(service.requestCalls, 0);
      expect(settings.settings.reviewAskCount, 0);
      service.available = true;
      await review.onSaved(1);
      expect(service.requestCalls, 1);
    });

    test('a failing prompt still counts as asked', () async {
      service.throwOnRequest = true;
      await reachThreshold();
      expect(service.requestCalls, 1);
      expect(settings.settings.reviewAskCount, 1);
      await review.onSaved(1);
      expect(service.requestCalls, 1);
    });
  });

  group('asking again: 30, then 90, then 180 days', () {
    Future<void> firstAsk() async {
      await review.onSaved(4);
      nextDay();
      await review.onSaved(3);
      nextDay();
      await review.onSaved(3);
      expect(service.requestCalls, 1);
    }

    void pass(int days) => clock = clock.add(Duration(days: days));

    test('the cooldown steps are 30, 90, then 180 for every later one', () {
      expect(ReviewProvider.cooldownAfter(0), Duration.zero);
      expect(ReviewProvider.cooldownAfter(1), const Duration(days: 30));
      expect(ReviewProvider.cooldownAfter(2), const Duration(days: 90));
      expect(ReviewProvider.cooldownAfter(3), const Duration(days: 180));
      expect(ReviewProvider.cooldownAfter(4), const Duration(days: 180));
      expect(ReviewProvider.cooldownAfter(40), const Duration(days: 180));
    });

    test('saving during the 30 days asks nothing', () async {
      await firstAsk();
      pass(29);
      await review.onSaved(5);
      expect(service.requestCalls, 1);
    });

    test('after 30 days a single save asks again, with no new threshold', () async {
      await firstAsk();
      pass(30);
      await review.onSaved(1);
      expect(service.requestCalls, 2);
      expect(settings.settings.reviewAskCount, 2);
    });

    test('the second wait is 90 days', () async {
      await firstAsk();
      pass(30);
      await review.onSaved(1);
      pass(89);
      await review.onSaved(1);
      expect(service.requestCalls, 2);
      pass(1);
      await review.onSaved(1);
      expect(service.requestCalls, 3);
    });

    test('every wait after that is 180 days', () async {
      await firstAsk();
      pass(30);
      await review.onSaved(1);
      pass(90);
      await review.onSaved(1);
      expect(service.requestCalls, 3);
      pass(179);
      await review.onSaved(1);
      expect(service.requestCalls, 3);
      pass(1);
      await review.onSaved(1);
      expect(service.requestCalls, 4);
      pass(180);
      await review.onSaved(1);
      expect(service.requestCalls, 5);
    });

    test('it never stops for good', () async {
      await firstAsk();
      for (int i = 0; i < 6; i++) {
        pass(180);
        await review.onSaved(1);
      }
      expect(service.requestCalls, 7);
    });

    test('a request only ever follows a save', () async {
      await firstAsk();
      pass(400);
      expect(service.requestCalls, 1);
    });

    test('a busy ad delays it until a later save', () async {
      await firstAsk();
      pass(30);
      adBusy = true;
      await review.onSaved(1);
      expect(service.requestCalls, 1);
      adBusy = false;
      await review.onSaved(1);
      expect(service.requestCalls, 2);
    });

    test('settings from before the cooldowns start the wait at the next save', () async {
      settings.dispose();
      final FakeSettingsStore old = FakeSettingsStore(
        initial: AppSettings.fromJson(<String, Object?>{
          'schemaVersion': 1,
          'reviewAsked': true,
        }),
      );
      settings = SettingsProvider(old);
      await settings.load();
      review = ReviewProvider(
        settings: settings,
        service: service,
        adBusy: () => adBusy,
        now: () => clock,
      );
      expect(settings.settings.reviewAskCount, 1);
      expect(settings.settings.reviewLastAskedMs, isNull);
      await review.onSaved(1);
      expect(service.requestCalls, 0);
      expect(
        settings.settings.reviewLastAskedMs,
        clock.millisecondsSinceEpoch,
      );
      pass(30);
      await review.onSaved(1);
      expect(service.requestCalls, 1);
    });
  });
}
