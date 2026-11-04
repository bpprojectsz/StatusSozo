import 'package:flutter/foundation.dart';

/// What the consent step decided.
@immutable
class ConsentOutcome {
  const ConsentOutcome({
    required this.canRequestAds,
    required this.privacyOptionsRequired,
  });

  /// Ads may be requested.
  final bool canRequestAds;

  /// The person must be able to reopen their privacy choices (EEA and UK).
  final bool privacyOptionsRequired;

  @override
  bool operator ==(Object other) =>
      other is ConsentOutcome &&
      other.canRequestAds == canRequestAds &&
      other.privacyOptionsRequired == privacyOptionsRequired;

  @override
  int get hashCode => Object.hash(canRequestAds, privacyOptionsRequired);
}

/// Port for the consent step. **No method may throw.** Any failure falls back
/// to the last known consent state and never blocks the app.
abstract interface class ConsentService {
  /// Updates consent information and shows Google's form when it is required.
  Future<ConsentOutcome> gather();

  /// Reopens the privacy choices form, then reports the new state.
  Future<ConsentOutcome> showPrivacyOptions();
}
