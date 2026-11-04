import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/contracts/consent_service.dart';
import 'package:statussozo/utils/app_log.dart';

/// Consent through Google's User Messaging Platform. A request that fails never
/// blocks the app: the last known consent state is used.
class UmpConsentService implements ConsentService {
  @override
  Future<ConsentOutcome> gather() async {
    try {
      final Completer<void> updated = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(
          consentDebugSettings: AppConfig.consentDebugEea
              ? ConsentDebugSettings(
                  debugGeography: DebugGeography.debugGeographyEea,
                )
              : null,
        ),
        () {
          if (!updated.isCompleted) {
            updated.complete();
          }
        },
        (FormError error) {
          AppLog.warn('consent', 'Consent update failed: ${error.message}');
          if (!updated.isCompleted) {
            updated.complete();
          }
        },
      );
      await updated.future.timeout(AppConfig.adInitTimeout);

      final Completer<void> shown = Completer<void>();
      unawaited(
        ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
          if (error != null) {
            AppLog.warn('consent', 'Consent form failed: ${error.message}');
          }
          if (!shown.isCompleted) {
            shown.complete();
          }
        }),
      );
      // No timeout: the person may take as long as they like.
      await shown.future;
    } on Object catch (error) {
      AppLog.warn('consent', 'Consent step failed, using the last state', error);
    }
    return _current();
  }

  @override
  Future<ConsentOutcome> showPrivacyOptions() async {
    try {
      final Completer<void> done = Completer<void>();
      unawaited(
        ConsentForm.showPrivacyOptionsForm((FormError? error) {
          if (error != null) {
            AppLog.warn('consent', 'Privacy options failed: ${error.message}');
          }
          if (!done.isCompleted) {
            done.complete();
          }
        }),
      );
      await done.future;
    } on Object catch (error) {
      AppLog.warn('consent', 'Privacy options could not open', error);
    }
    return _current();
  }

  Future<ConsentOutcome> _current() async {
    bool canRequest = false;
    bool optionsRequired = false;
    try {
      canRequest = await ConsentInformation.instance.canRequestAds();
      optionsRequired =
          await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } on Object catch (error) {
      AppLog.warn('consent', 'Could not read the consent state', error);
    }
    return ConsentOutcome(
      canRequestAds: canRequest,
      privacyOptionsRequired: optionsRequired,
    );
  }
}
