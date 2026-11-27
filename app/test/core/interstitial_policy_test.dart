import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/services/interstitial_policy.dart';

void main() {
  const InterstitialPolicy policy = InterstitialPolicy();
  const int minute = 60 * 1000;
  const int start = 1000000000000;

  /// Counts [n] firing actions one after the other and returns the last state.
  AdDecision count(
    int n, {
    InterstitialState state = const InterstitialState(),
    int nowMs = start,
    AdAction action = AdAction.viewerClosed,
    int? lastFailedMs,
  }) {
    AdDecision decision = AdDecision(state: state, attempt: false);
    for (int i = 0; i < n; i++) {
      decision = policy.onAction(
        action,
        decision.state,
        nowMs: nowMs,
        lastFailedMs: lastFailedMs,
      );
    }
    return decision;
  }

  test('the settings are seven actions, seven minutes, a two second pause', () {
    expect(AppConfig.actionsPerInterstitial, 7);
    expect(AppConfig.interstitialMinGap, const Duration(minutes: 7));
    expect(AppConfig.interstitialHold, const Duration(seconds: 2));
    expect(AppConfig.interstitialRetryAfterFailure, const Duration(seconds: 60));
    expect(policy.actionsPerAd, 7);
    expect(policy.minGap, const Duration(minutes: 7));
  });

  group('one tally for the whole app', () {
    test('every counted action adds one, whatever its kind', () {
      InterstitialState state = const InterstitialState();
      int expected = 0;
      for (final AdAction action in AdAction.values.take(6)) {
        state = policy.onAction(action, state, nowMs: start).state;
        expected++;
        expect(state.tally, expected, reason: action.name);
      }
      expect(state.pending, isFalse);
    });

    test('there is no per-action rule: six of one kind are just six', () {
      final AdDecision d = count(6, action: AdAction.viewerClosed);
      expect(d.state.tally, 6);
      expect(d.state.pending, isFalse);
      expect(d.attempt, isFalse);
    });

    test('the seventh makes the ad pending', () {
      final AdDecision d = count(7);
      expect(d.state.tally, 7);
      expect(d.state.pending, isTrue);
    });

    test('the seventh fires itself when the gap has already passed', () {
      expect(count(6).attempt, isFalse);
      expect(count(7).attempt, isTrue);
    });
  });

  group('pending', () {
    test('the tally stops while an ad is pending', () {
      final AdDecision d = count(
        10,
        state: const InterstitialState(lastShownMs: start - 1 * minute),
      );
      expect(d.state.tally, 7);
      expect(d.state.pending, isTrue);
    });

    test('inside the gap nothing fires, and the pending ad is kept', () {
      final InterstitialState shown = policy.shown(start);
      final AdDecision d = count(
        20,
        state: shown,
        nowMs: start + 3 * minute,
      );
      expect(d.state.pending, isTrue);
      expect(d.attempt, isFalse);
    });

    test('the first counted action after the gap fires it', () {
      final InterstitialState shown = policy.shown(start);
      AdDecision d = count(7, state: shown, nowMs: start + 3 * minute);
      expect(d.attempt, isFalse);
      d = policy.onAction(
        AdAction.deleteSaved,
        d.state,
        nowMs: start + 7 * minute,
      );
      expect(d.attempt, isTrue);
    });

    test('the gap is exactly seven minutes', () {
      final InterstitialState shown = policy.shown(start);
      final InterstitialState pending = InterstitialState(
        tally: 7,
        pending: true,
        lastShownMs: shown.lastShownMs,
      );
      expect(
        policy
            .onAction(AdAction.viewerClosed, pending, nowMs: start + 7 * minute - 1)
            .attempt,
        isFalse,
      );
      expect(
        policy
            .onAction(AdAction.viewerClosed, pending, nowMs: start + 7 * minute)
            .attempt,
        isTrue,
      );
    });

    test('showing resets the tally and starts the gap again', () {
      final InterstitialState after = policy.shown(start + 99);
      expect(after.tally, 0);
      expect(after.pending, isFalse);
      expect(after.lastShownMs, start + 99);
    });

    test('there is no daily limit: any number of cycles', () {
      InterstitialState state = const InterstitialState();
      int now = start;
      int shown = 0;
      for (int i = 0; i < 200; i++) {
        now += 8 * minute;
        final AdDecision d = count(7, state: state, nowMs: now);
        state = d.state;
        if (d.attempt) {
          shown++;
          state = policy.shown(now);
        }
      }
      expect(shown, 200);
    });
  });

  group('swiping counts but never fires', () {
    test('it adds to the tally', () {
      final AdDecision d = count(3, action: AdAction.viewerSwipe);
      expect(d.state.tally, 3);
    });

    test('the swipe that reaches seven makes the ad pending without firing it', () {
      final AdDecision d = count(
        1,
        state: const InterstitialState(tally: 6),
        action: AdAction.viewerSwipe,
      );
      expect(d.state.pending, isTrue);
      expect(d.attempt, isFalse);
    });

    test('a pending ad waits through swipes and fires on the next other action', () {
      InterstitialState state = const InterstitialState(tally: 7, pending: true);
      for (int i = 0; i < 10; i++) {
        final AdDecision d = policy.onAction(
          AdAction.viewerSwipe,
          state,
          nowMs: start,
        );
        expect(d.attempt, isFalse);
        state = d.state;
      }
      expect(
        policy.onAction(AdAction.videoEnded, state, nowMs: start).attempt,
        isTrue,
      );
    });

    test('only swiping is excluded', () {
      for (final AdAction action in AdAction.values) {
        expect(action.mayShowAd, action != AdAction.viewerSwipe, reason: action.name);
      }
    });
  });

  group('a failed attempt', () {
    const InterstitialState pending = InterstitialState(
      tally: 7,
      pending: true,
    );

    test('waits sixty seconds before the next one', () {
      expect(
        policy
            .onAction(AdAction.viewerClosed, pending, nowMs: start + 59 * 1000, lastFailedMs: start)
            .attempt,
        isFalse,
      );
      expect(
        policy
            .onAction(AdAction.viewerClosed, pending, nowMs: start + 60 * 1000, lastFailedMs: start)
            .attempt,
        isTrue,
      );
    });

    test('keeps the ad pending and the tally where it was', () {
      final AdDecision d = policy.onAction(
        AdAction.viewerClosed,
        pending,
        nowMs: start + 1000,
        lastFailedMs: start,
      );
      expect(d.state, pending);
    });
  });

  group('the state', () {
    test('equality and hash use every field', () {
      const InterstitialState a = InterstitialState(tally: 2, lastShownMs: 5);
      const InterstitialState b = InterstitialState(tally: 2, lastShownMs: 5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const InterstitialState(tally: 3, lastShownMs: 5)));
      expect(a, isNot(const InterstitialState(tally: 2, pending: true, lastShownMs: 5)));
      expect(a, isNot(const InterstitialState(tally: 2, lastShownMs: 6)));
    });
  });

  group('dayKey', () {
    test('is year-month-day with zero padding', () {
      expect(dayKey(DateTime(2026, 3, 9, 23, 59)), '2026-03-09');
    });
  });
}
