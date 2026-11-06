import 'package:flutter_test/flutter_test.dart';
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

  group('asking', () {
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
      expect(settings.settings.reviewAsked, isTrue);
    });

    test('never asks twice', () async {
      await reachThreshold();
      nextDay();
      await review.onSaved(5);
      nextDay();
      await review.onSaved(5);
      expect(service.requestCalls, 1);
    });

    test('does not ask while an ad is busy, and asks later', () async {
      adBusy = true;
      await reachThreshold();
      expect(service.requestCalls, 0);
      expect(settings.settings.reviewAsked, isFalse);
      adBusy = false;
      await review.onSaved(1);
      expect(service.requestCalls, 1);
    });

    test('does not ask when the system cannot show it, and asks later', () async {
      service.available = false;
      await reachThreshold();
      expect(service.requestCalls, 0);
      expect(settings.settings.reviewAsked, isFalse);
      service.available = true;
      await review.onSaved(1);
      expect(service.requestCalls, 1);
    });

    test('a failing prompt is still counted as asked', () async {
      service.throwOnRequest = true;
      await reachThreshold();
      expect(service.requestCalls, 1);
      expect(settings.settings.reviewAsked, isTrue);
      await review.onSaved(1);
      expect(service.requestCalls, 1);
    });
  });

  group('the switch', () {
    test('is on by default', () {
      expect(review.enabled, isTrue);
    });

    test('off means never asked, but saves are still counted', () async {
      await review.setEnabled(false);
      expect(review.enabled, isFalse);
      expect(store.saves.last.reviewPromptsEnabled, isFalse);
      await review.onSaved(4);
      nextDay();
      await review.onSaved(3);
      nextDay();
      await review.onSaved(3);
      expect(service.requestCalls, 0);
      expect(settings.settings.reviewSaves, 10);
    });

    test('turning it on lets the next save ask', () async {
      await review.setEnabled(false);
      await review.onSaved(4);
      nextDay();
      await review.onSaved(3);
      nextDay();
      await review.onSaved(3);
      await review.setEnabled(true);
      await review.onSaved(1);
      expect(service.requestCalls, 1);
    });
  });
}
