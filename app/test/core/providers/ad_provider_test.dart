import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/contracts/consent_service.dart';
import 'package:statussozo/core/providers/ad_provider.dart';
import 'package:statussozo/core/providers/settings_provider.dart';
import 'package:statussozo/core/services/interstitial_policy.dart';

import '../../fakes/fakes.dart';

void main() {
  late FakeAdService ads;
  late FakeConsentService consent;
  late FakeSettingsStore store;
  late SettingsProvider settings;
  late DateTime clock;
  late AdProvider provider;

  AdProvider build() => AdProvider(
    ads: ads,
    consent: consent,
    settings: settings,
    policy: InterstitialPolicy(nowMs: () => clock.millisecondsSinceEpoch),
    now: () => clock,
  );

  setUp(() async {
    ads = FakeAdService();
    consent = FakeConsentService();
    store = FakeSettingsStore();
    settings = SettingsProvider(store);
    await settings.load();
    clock = DateTime(2026, 11, 3, 12);
    provider = build();
  });
  tearDown(() {
    provider.dispose();
    settings.dispose();
  });

  group('start', () {
    test('does nothing before it is called', () {
      expect(provider.value.phase, AdsPhase.idle);
      expect(consent.gatherCalls, 0);
      expect(ads.initialiseCalls, 0);
    });

    test('with consent it starts the SDK and loads an interstitial', () async {
      await provider.start();
      expect(provider.value.phase, AdsPhase.ready);
      expect(provider.enabled, isTrue);
      expect(ads.initialiseCalls, 1);
      expect(ads.loadCalls, 1);
    });

    test('without consent no ad request is ever made', () async {
      consent.outcome = const ConsentOutcome(
        canRequestAds: false,
        privacyOptionsRequired: true,
      );
      await provider.start();
      expect(provider.value.phase, AdsPhase.disabled);
      expect(provider.value.privacyOptionsRequired, isTrue);
      expect(provider.enabled, isFalse);
      expect(ads.initialiseCalls, 0);
      expect(ads.loadCalls, 0);
    });

    test('an SDK that does not start disables ads without throwing', () async {
      ads.failInitialise = true;
      await provider.start();
      expect(provider.value.phase, AdsPhase.disabled);
      expect(ads.loadCalls, 0);
    });

    test('a second start while one is running is ignored', () async {
      final Future<void> first = provider.start();
      final Future<void> second = provider.start();
      await Future.wait<void>(<Future<void>>[first, second]);
      expect(consent.gatherCalls, 1);
    });

    test('the privacy choices flag follows the consent outcome', () async {
      consent.outcome = const ConsentOutcome(
        canRequestAds: true,
        privacyOptionsRequired: true,
      );
      await provider.start();
      expect(provider.value.privacyOptionsRequired, isTrue);
    });
  });

  group('resume', () {
    test('tops up the interstitial when ads are running', () async {
      await provider.start();
      final int before = ads.loadCalls;
      await provider.onResumed();
      expect(ads.loadCalls, greaterThan(before));
    });

    test('looks at consent again when ads were off', () async {
      consent.outcome = const ConsentOutcome(
        canRequestAds: false,
        privacyOptionsRequired: false,
      );
      await provider.start();
      expect(provider.enabled, isFalse);

      consent.outcome = const ConsentOutcome(
        canRequestAds: true,
        privacyOptionsRequired: false,
      );
      await provider.onResumed();
      expect(provider.enabled, isTrue);
      expect(consent.gatherCalls, 2);
    });
  });

  group('privacy options', () {
    test('reopens the form and applies the new outcome', () async {
      consent.outcome = const ConsentOutcome(
        canRequestAds: true,
        privacyOptionsRequired: true,
      );
      await provider.start();
      consent.outcome = const ConsentOutcome(
        canRequestAds: false,
        privacyOptionsRequired: true,
      );
      await provider.showPrivacyOptions();
      expect(consent.privacyCalls, 1);
      expect(provider.enabled, isFalse);
    });
  });

  group('interstitials', () {
    Future<bool> batch() => provider.maybeShowInterstitial(
      InterstitialTrigger.batchSave,
      items: 3,
    );

    test('never before ads are ready', () async {
      expect(await batch(), isFalse);
      expect(ads.showCalls, 0);
    });

    test('never without consent', () async {
      consent.outcome = const ConsentOutcome(
        canRequestAds: false,
        privacyOptionsRequired: false,
      );
      await provider.start();
      expect(await batch(), isFalse);
      expect(ads.showCalls, 0);
    });

    test('shows when the rules allow, then records it', () async {
      await provider.start();
      expect(await batch(), isTrue);
      expect(ads.showCalls, 1);
      expect(settings.settings.interstitialDay, '2026-11-03');
      expect(settings.settings.interstitialsToday, 1);
      expect(store.saves.last.interstitialsToday, 1);
    });

    test('does not show when none is loaded yet and asks for one', () async {
      ads.loadMakesReady = false;
      await provider.start();
      final int before = ads.loadCalls;
      expect(await batch(), isFalse);
      expect(ads.loadCalls, greaterThan(before));
    });

    test('a batch of one item does not qualify', () async {
      await provider.start();
      expect(
        await provider.maybeShowInterstitial(
          InterstitialTrigger.batchSave,
          items: 1,
        ),
        isFalse,
      );
    });

    test('keeps five minutes between interstitials', () async {
      await provider.start();
      expect(await batch(), isTrue);
      clock = clock.add(const Duration(minutes: 3));
      expect(await batch(), isFalse);
      clock = clock.add(const Duration(minutes: 3));
      expect(await batch(), isTrue);
      expect(settings.settings.interstitialsToday, 2);
    });

    test('stops at the daily maximum and starts over the next day', () async {
      await provider.start();
      for (int i = 0; i < 21; i++) {
        clock = clock.add(const Duration(minutes: 6));
        expect(await batch(), isTrue, reason: 'ad ${i + 1}');
      }
      clock = clock.add(const Duration(minutes: 6));
      expect(await batch(), isFalse);
      expect(settings.settings.interstitialsToday, 21);

      clock = DateTime(2026, 11, 4, 9);
      expect(await batch(), isTrue);
      expect(settings.settings.interstitialDay, '2026-11-04');
      expect(settings.settings.interstitialsToday, 1);
    });

    test('a failed show records nothing', () async {
      await provider.start();
      ads.showResult = false;
      expect(await batch(), isFalse);
      expect(settings.settings.interstitialsToday, 0);
    });

    test('every fifth viewer close qualifies', () async {
      await provider.start();
      for (int i = 1; i <= 4; i++) {
        expect(
          await provider.maybeShowInterstitial(InterstitialTrigger.viewerClose),
          isFalse,
        );
      }
      expect(
        await provider.maybeShowInterstitial(InterstitialTrigger.viewerClose),
        isTrue,
      );
    });

    test('loads the next interstitial after one is shown', () async {
      await provider.start();
      final int before = ads.loadCalls;
      await batch();
      expect(ads.loadCalls, greaterThan(before));
    });
  });
}
