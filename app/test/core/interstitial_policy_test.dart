import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/services/interstitial_policy.dart';

void main() {
  int now = 1000000;
  late InterstitialPolicy policy;

  setUp(() {
    now = 1000000;
    policy = InterstitialPolicy(nowMs: () => now);
  });

  group('batch save', () {
    test('needs at least two items', () {
      expect(
        policy.allows(InterstitialTrigger.batchSave, items: 1, shownToday: 0),
        isFalse,
      );
      expect(
        policy.allows(InterstitialTrigger.batchSave, items: 2, shownToday: 0),
        isTrue,
      );
    });
  });

  group('saved delete', () {
    test('needs at least one item', () {
      expect(
        policy.allows(InterstitialTrigger.savedDelete, items: 0, shownToday: 0),
        isFalse,
      );
      expect(
        policy.allows(InterstitialTrigger.savedDelete, items: 1, shownToday: 0),
        isTrue,
      );
    });
  });

  group('viewer close', () {
    test('qualifies on every fifth close only', () {
      for (int i = 1; i <= 4; i++) {
        expect(
          policy.allows(InterstitialTrigger.viewerClose, shownToday: 0),
          isFalse,
          reason: 'close $i',
        );
      }
      expect(
        policy.allows(InterstitialTrigger.viewerClose, shownToday: 0),
        isTrue,
      );
    });

    test('the count restarts after an interstitial is shown', () {
      for (int i = 0; i < 5; i++) {
        policy.allows(InterstitialTrigger.viewerClose, shownToday: 0);
      }
      policy.markShown();
      now += const Duration(minutes: 10).inMilliseconds;
      expect(
        policy.allows(InterstitialTrigger.viewerClose, shownToday: 1),
        isFalse,
      );
    });

    test('a close blocked by the spacing still counts toward the next', () {
      policy.markShown();
      for (int i = 0; i < 5; i++) {
        expect(
          policy.allows(InterstitialTrigger.viewerClose, shownToday: 1),
          isFalse,
        );
      }
      now += const Duration(minutes: 4).inMilliseconds;
      expect(
        policy.allows(InterstitialTrigger.viewerClose, shownToday: 1),
        isTrue,
      );
    });
  });

  group('spacing and daily limit', () {
    test('waits at least three minutes between interstitials', () {
      policy.markShown();
      now += const Duration(minutes: 2, seconds: 59).inMilliseconds;
      expect(
        policy.allows(InterstitialTrigger.batchSave, items: 3, shownToday: 1),
        isFalse,
      );
      now += const Duration(seconds: 1).inMilliseconds;
      expect(
        policy.allows(InterstitialTrigger.batchSave, items: 3, shownToday: 1),
        isTrue,
      );
    });

    test('stops at the daily maximum', () {
      expect(
        policy.allows(InterstitialTrigger.batchSave, items: 3, shownToday: 5),
        isTrue,
      );
      expect(
        policy.allows(InterstitialTrigger.batchSave, items: 3, shownToday: 6),
        isFalse,
      );
    });

    test('the first interstitial of a session is not delayed', () {
      expect(
        policy.allows(InterstitialTrigger.batchSave, items: 2, shownToday: 0),
        isTrue,
      );
    });
  });

  test('dayKey is a zero-padded local date', () {
    expect(dayKey(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
    expect(dayKey(DateTime(2026, 11, 30)), '2026-11-30');
  });
}
