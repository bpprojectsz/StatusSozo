import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/contracts/consent_service.dart';
import 'package:statussozo/core/services/consent_rules.dart';

void main() {
  test('follows the SDK when nothing went wrong', () {
    expect(
      consentOutcome(
        errored: false,
        canRequestAds: true,
        privacyOptionsRequired: false,
      ),
      const ConsentOutcome(canRequestAds: true, privacyOptionsRequired: false),
    );
    expect(
      consentOutcome(
        errored: false,
        canRequestAds: false,
        privacyOptionsRequired: true,
      ),
      const ConsentOutcome(canRequestAds: false, privacyOptionsRequired: true),
    );
  });

  test('still attempts ads when the consent step failed', () {
    final ConsentOutcome outcome = consentOutcome(
      errored: true,
      canRequestAds: false,
      privacyOptionsRequired: false,
    );
    expect(outcome.canRequestAds, isTrue);
  });

  test('a failed step keeps the privacy choices flag as read', () {
    final ConsentOutcome outcome = consentOutcome(
      errored: true,
      canRequestAds: false,
      privacyOptionsRequired: true,
    );
    expect(outcome.privacyOptionsRequired, isTrue);
  });

  test('a failed step is marked for one retry, a good one is not', () {
    expect(
      consentOutcome(
        errored: true,
        canRequestAds: false,
        privacyOptionsRequired: false,
      ).needsRetry,
      isTrue,
    );
    expect(
      consentOutcome(
        errored: false,
        canRequestAds: true,
        privacyOptionsRequired: false,
      ).needsRetry,
      isFalse,
    );
  });

  group('readConsentState', () {
    test('follows the SDK when both reads work', () async {
      final ConsentOutcome outcome = await readConsentState(
        errored: false,
        canRequestAds: () async => false,
        privacyOptionsRequired: () async => true,
      );
      expect(
        outcome,
        const ConsentOutcome(canRequestAds: false, privacyOptionsRequired: true),
      );
    });

    test('a throwing canRequestAds still asks for ads and retries later', () async {
      final List<String> logged = <String>[];
      final ConsentOutcome outcome = await readConsentState(
        errored: false,
        canRequestAds: () async => throw StateError('sdk'),
        privacyOptionsRequired: () async => false,
        onError: (String what, Object error) => logged.add(what),
      );
      expect(outcome.canRequestAds, isTrue);
      expect(outcome.needsRetry, isTrue);
      expect(logged, hasLength(1));
    });

    test('a throwing privacy read only hides the row', () async {
      final ConsentOutcome outcome = await readConsentState(
        errored: false,
        canRequestAds: () async => false,
        privacyOptionsRequired: () async => throw StateError('sdk'),
      );
      expect(outcome.canRequestAds, isFalse);
      expect(outcome.privacyOptionsRequired, isFalse);
      expect(outcome.needsRetry, isFalse);
    });

    test('an earlier failure in the step carries through', () async {
      final ConsentOutcome outcome = await readConsentState(
        errored: true,
        canRequestAds: () async => false,
        privacyOptionsRequired: () async => false,
      );
      expect(outcome.canRequestAds, isTrue);
      expect(outcome.needsRetry, isTrue);
    });

    test('both reads throwing never throws', () async {
      final ConsentOutcome outcome = await readConsentState(
        errored: false,
        canRequestAds: () async => throw StateError('a'),
        privacyOptionsRequired: () async => throw StateError('b'),
      );
      expect(outcome.canRequestAds, isTrue);
      expect(outcome.needsRetry, isTrue);
    });
  });
}
