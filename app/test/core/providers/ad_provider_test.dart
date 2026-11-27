import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/contracts/consent_service.dart';
import 'package:statussozo/core/models/app_settings.dart';
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

  /// The pause before an ad. Tests open it by hand, or by default at once.
  bool holdOpensAtOnce = true;
  final List<Completer<void>> holds = <Completer<void>>[];

  Future<void> hold(Duration pause) {
    if (holdOpensAtOnce) {
      return Future<void>.value();
    }
    final Completer<void> c = Completer<void>();
    holds.add(c);
    return c.future;
  }

  AdProvider build() => AdProvider(
    ads: ads,
    consent: consent,
    policy: const InterstitialPolicy(),
    settings: settings,
    now: () => clock,
    delay: hold,
  );

  setUp(() async {
    ads = FakeAdService();
    consent = FakeConsentService();
    store = FakeSettingsStore();
    settings = SettingsProvider(store);
    await settings.load();
    clock = DateTime(2026, 11, 3, 12);
    holdOpensAtOnce = true;
    holds.clear();
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

  group('a failed consent step is retried once', () {
    const ConsentOutcome failed = ConsentOutcome(
      canRequestAds: true,
      privacyOptionsRequired: false,
      needsRetry: true,
    );
    const ConsentOutcome fine = ConsentOutcome(
      canRequestAds: true,
      privacyOptionsRequired: false,
    );

    test('ads still start while the step is failing', () async {
      consent.queue.add(failed);
      await provider.start();
      expect(provider.enabled, isTrue);
      expect(consent.gatherCalls, 1);
    });

    test('the next foreground runs the step once more', () async {
      consent.queue.add(failed);
      await provider.start();
      await provider.onResumed();
      expect(consent.gatherCalls, 2);
      expect(provider.enabled, isTrue);
    });

    test('it does not loop: later foregrounds do not run it again', () async {
      consent.queue
        ..add(failed)
        ..add(failed);
      await provider.start();
      await provider.onResumed();
      await provider.onResumed();
      await provider.onResumed();
      expect(consent.gatherCalls, 2);
    });

    test('the retry result is applied', () async {
      consent.queue
        ..add(failed)
        ..add(
          const ConsentOutcome(
            canRequestAds: false,
            privacyOptionsRequired: true,
          ),
        );
      await provider.start();
      expect(provider.enabled, isTrue);
      await provider.onResumed();
      expect(provider.enabled, isFalse);
      expect(provider.value.privacyOptionsRequired, isTrue);
    });

    test('a step that did not fail is never retried', () async {
      consent.queue.add(fine);
      await provider.start();
      await provider.onResumed();
      await provider.onResumed();
      expect(consent.gatherCalls, 1);
    });

    test('a launch that failed once has one retry, not one per failure', () async {
      consent.queue
        ..add(failed)
        ..add(fine);
      await provider.start();
      await provider.onResumed();
      await provider.onResumed();
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
    Future<void> act([AdAction action = AdAction.viewerClosed]) async {
      await provider.onAction(action);
      await pumpEventQueue();
    }

    Future<void> countUp(int n, [AdAction action = AdAction.viewerClosed]) async {
      for (int i = 0; i < n; i++) {
        await act(action);
      }
    }

    int tally() => settings.settings.adTally;
    bool pending() => settings.settings.adPending;

    test('nothing is counted before ads are ready', () async {
      await countUp(10);
      expect(tally(), 0);
      expect(ads.showCalls, 0);
    });

    test('nothing is counted without consent', () async {
      consent.outcome = const ConsentOutcome(
        canRequestAds: false,
        privacyOptionsRequired: false,
      );
      await provider.start();
      await countUp(10);
      expect(tally(), 0);
      expect(ads.showCalls, 0);
    });

    test('six actions count and show nothing', () async {
      await provider.start();
      await countUp(6);
      expect(tally(), 6);
      expect(pending(), isFalse);
      expect(ads.showCalls, 0);
    });

    test('the seventh shows an ad after the pause, and resets the tally', () async {
      await provider.start();
      await countUp(6);
      holdOpensAtOnce = false;
      await act();
      expect(pending(), isTrue);
      expect(tally(), 7);
      // The pause has not ended: nothing yet.
      expect(ads.showCalls, 0);
      holds.single.complete();
      await pumpEventQueue();
      expect(ads.showCalls, 1);
      expect(tally(), 0);
      expect(pending(), isFalse);
      expect(settings.settings.adLastShownMs, clock.millisecondsSinceEpoch);
      expect(provider.lastInterstitialAt, clock);
    });

    test('two actions during one pause make one attempt', () async {
      await provider.start();
      await countUp(6);
      holdOpensAtOnce = false;
      await act();
      await act();
      await act();
      expect(holds, hasLength(1));
      holds.single.complete();
      await pumpEventQueue();
      expect(ads.showCalls, 1);
    });

    test('inside the gap the ad stays pending and the tally stops', () async {
      await provider.start();
      await countUp(7);
      expect(ads.showCalls, 1);
      clock = clock.add(const Duration(minutes: 5));
      await countUp(12);
      expect(ads.showCalls, 1);
      expect(pending(), isTrue);
      expect(tally(), 7);
    });

    test('the first action after the gap shows the pending ad', () async {
      await provider.start();
      await countUp(7);
      clock = clock.add(const Duration(minutes: 5));
      await countUp(8);
      expect(ads.showCalls, 1);
      clock = clock.add(const Duration(minutes: 2));
      await act(AdAction.deleteSaved);
      expect(ads.showCalls, 2);
      expect(pending(), isFalse);
      expect(tally(), 0);
    });

    test('swiping counts and never shows the ad', () async {
      await provider.start();
      await countUp(7, AdAction.viewerSwipe);
      expect(tally(), 7);
      expect(pending(), isTrue);
      expect(ads.showCalls, 0);
      await act(AdAction.videoEnded);
      expect(ads.showCalls, 1);
    });

    test('there is no daily limit', () async {
      await provider.start();
      for (int i = 0; i < 40; i++) {
        clock = clock.add(const Duration(minutes: 8));
        await countUp(7);
        expect(ads.showCalls, i + 1, reason: 'ad ${i + 1}');
      }
    });

    test('with no ad loaded it asks for one and waits a minute before trying again', () async {
      ads.loadMakesReady = false;
      await provider.start();
      final int loadsAtStart = ads.loadCalls;
      await countUp(7);
      expect(ads.showCalls, 0);
      expect(ads.loadCalls, greaterThan(loadsAtStart));
      expect(pending(), isTrue);
      final int loadsAfterFail = ads.loadCalls;
      clock = clock.add(const Duration(seconds: 30));
      await act();
      expect(ads.loadCalls, loadsAfterFail);
      clock = clock.add(const Duration(seconds: 31));
      await act();
      expect(ads.loadCalls, greaterThan(loadsAfterFail));
    });

    test('an ad that fails to show keeps everything pending', () async {
      await provider.start();
      ads.showResult = false;
      await countUp(7);
      expect(ads.showCalls, 1);
      expect(pending(), isTrue);
      expect(tally(), 7);
      expect(provider.lastInterstitialAt, isNull);
      // Not again within a minute.
      ads.loadMakesReady = true;
      await act();
      expect(ads.showCalls, 1);
    });

    test('the tally survives a restart', () async {
      await provider.start();
      await countUp(5);
      provider.dispose();
      final SettingsProvider again = SettingsProvider(store);
      await again.load();
      provider = AdProvider(
        ads: ads,
        consent: consent,
        policy: const InterstitialPolicy(),
        settings: again,
        now: () => clock,
        delay: hold,
      );
      await provider.start();
      await countUp(2);
      expect(ads.showCalls, 1);
      again.dispose();
    });

    test('a pending ad and the last time survive a restart', () async {
      await provider.start();
      await countUp(7);
      clock = clock.add(const Duration(minutes: 1));
      await countUp(3);
      provider.dispose();
      final SettingsProvider again = SettingsProvider(store);
      await again.load();
      expect(again.settings.adPending, isTrue);
      expect(again.settings.adLastShownMs, isNotNull);
      again.dispose();
    });

    test('a guard that says no keeps the ad pending until the next action', () async {
      await provider.start();
      bool videoPlaying = true;
      provider.interruptionGuards.add(() => !videoPlaying);
      await countUp(7);
      expect(ads.showCalls, 0);
      expect(pending(), isTrue);
      videoPlaying = false;
      await act();
      expect(ads.showCalls, 1);
    });

    test('guards are checked after the pause, not before', () async {
      await provider.start();
      await countUp(6);
      bool sheetOpen = false;
      provider.interruptionGuards.add(() => !sheetOpen);
      holdOpensAtOnce = false;
      await act();
      sheetOpen = true;
      holds.single.complete();
      await pumpEventQueue();
      expect(ads.showCalls, 0);
      expect(pending(), isTrue);
    });

    test('never while the app is not in front', () async {
      await provider.start();
      provider.setForeground(foreground: false);
      await countUp(7);
      expect(ads.showCalls, 0);
      provider.setForeground(foreground: true);
      await act();
      expect(ads.showCalls, 1);
    });

    test('loads the next interstitial after one is shown', () async {
      await provider.start();
      final int before = ads.loadCalls;
      await countUp(7);
      expect(ads.loadCalls, greaterThan(before));
    });
  });
}
