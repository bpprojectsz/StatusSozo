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
      expect(policy.allows(InterstitialTrigger.batchSave, items: 1), isFalse);
      expect(policy.allows(InterstitialTrigger.batchSave, items: 2), isTrue);
    });
  });

  group('actions that need one item', () {
    for (final InterstitialTrigger t in <InterstitialTrigger>[
      InterstitialTrigger.viewerSave,
      InterstitialTrigger.savedDelete,
      InterstitialTrigger.viewerDelete,
    ]) {
      test('$t needs at least one item', () {
        expect(policy.allows(t, items: 0), isFalse);
        expect(policy.allows(t, items: 1), isTrue);
      });
    }
  });

  group('viewer close', () {
    test('qualifies on every fifth close only', () {
      for (int i = 1; i <= 4; i++) {
        expect(
          policy.allows(InterstitialTrigger.viewerClose),
          isFalse,
          reason: 'close $i',
        );
      }
      expect(policy.allows(InterstitialTrigger.viewerClose), isTrue);
    });

    test('the count restarts after an interstitial is shown', () {
      for (int i = 0; i < 5; i++) {
        policy.allows(InterstitialTrigger.viewerClose);
      }
      policy.markShown();
      now += const Duration(minutes: 10).inMilliseconds;
      expect(policy.allows(InterstitialTrigger.viewerClose), isFalse);
    });

    test('a close blocked by the spacing still counts toward the next', () {
      policy.markShown();
      for (int i = 0; i < 5; i++) {
        expect(policy.allows(InterstitialTrigger.viewerClose), isFalse);
      }
      now += const Duration(minutes: 8).inMilliseconds;
      expect(policy.allows(InterstitialTrigger.viewerClose), isTrue);
    });
  });

  group('spacing', () {
    test('waits at least seven minutes between interstitials', () {
      policy.markShown();
      now += const Duration(minutes: 6, seconds: 59).inMilliseconds;
      expect(policy.allows(InterstitialTrigger.batchSave, items: 3), isFalse);
      now += const Duration(seconds: 1).inMilliseconds;
      expect(policy.allows(InterstitialTrigger.batchSave, items: 3), isTrue);
    });

    test('every trigger shares the same spacing', () {
      policy.markShown();
      now += const Duration(minutes: 3).inMilliseconds;
      for (final InterstitialTrigger t in <InterstitialTrigger>[
        InterstitialTrigger.viewerSave,
        InterstitialTrigger.savedDelete,
        InterstitialTrigger.viewerDelete,
      ]) {
        expect(policy.allows(t, items: 1), isFalse, reason: '$t');
      }
    });

    test('there is no daily limit', () {
      for (int i = 0; i < 100; i++) {
        expect(
          policy.allows(InterstitialTrigger.batchSave, items: 3),
          isTrue,
          reason: 'ad ${i + 1}',
        );
        policy.markShown();
        now += const Duration(minutes: 7).inMilliseconds;
      }
    });

    test('the first interstitial of a session is not delayed', () {
      expect(policy.allows(InterstitialTrigger.batchSave, items: 2), isTrue);
    });
  });

  test('dayKey is a zero-padded local date', () {
    expect(dayKey(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
    expect(dayKey(DateTime(2026, 11, 30)), '2026-11-30');
  });
}
