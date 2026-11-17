import 'package:statussozo/core/contracts/consent_service.dart';

/// Decides whether ads may be requested after the consent step.
///
/// Google's guidance is to ask the SDK whether ads can be requested, and to
/// **still attempt ads when the consent step itself fails**. The SDK then uses
/// the consent status from the previous session and Google decides what, if
/// anything, it serves. After a person declines, Google may still serve limited
/// ads, so a decline is never decided here.
///
/// A failed step is also marked [ConsentOutcome.needsRetry], so the step runs
/// once more on the next foreground.
ConsentOutcome consentOutcome({
  required bool errored,
  required bool canRequestAds,
  required bool privacyOptionsRequired,
}) {
  return ConsentOutcome(
    canRequestAds: errored || canRequestAds,
    privacyOptionsRequired: privacyOptionsRequired,
    needsRetry: errored,
  );
}

/// Reads the consent state from the SDK without ever throwing.
///
/// If asking whether ads can be requested throws, that counts as a failed
/// step: ads are still requested (Google's advice), the problem is reported
/// through [onError], and the step is retried once later. A failure to read
/// the privacy-choices flag only hides that row; it never affects ads.
Future<ConsentOutcome> readConsentState({
  required bool errored,
  required Future<bool> Function() canRequestAds,
  required Future<bool> Function() privacyOptionsRequired,
  void Function(String what, Object error)? onError,
}) async {
  bool failed = errored;
  bool canRequest = false;
  bool optionsRequired = false;
  try {
    canRequest = await canRequestAds();
  } on Object catch (error) {
    failed = true;
    onError?.call('Could not ask whether ads can be requested', error);
  }
  try {
    optionsRequired = await privacyOptionsRequired();
  } on Object catch (error) {
    onError?.call('Could not read the privacy choices requirement', error);
  }
  return consentOutcome(
    errored: failed,
    canRequestAds: canRequest,
    privacyOptionsRequired: optionsRequired,
  );
}
