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
}
