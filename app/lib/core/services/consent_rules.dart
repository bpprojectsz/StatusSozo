import 'package:statussozo/core/contracts/consent_service.dart';

/// Decides whether ads may be requested after the consent step.
///
/// Google's guidance is to ask the SDK whether ads can be requested, and to
/// **still attempt ads when the consent step itself fails**. The SDK then uses
/// the consent status from the previous session and Google decides what, if
/// anything, it serves. After a person declines, Google may still serve limited
/// ads, so a decline is never decided here.
ConsentOutcome consentOutcome({
  required bool errored,
  required bool canRequestAds,
  required bool privacyOptionsRequired,
}) {
  return ConsentOutcome(
    canRequestAds: errored || canRequestAds,
    privacyOptionsRequired: privacyOptionsRequired,
  );
}
