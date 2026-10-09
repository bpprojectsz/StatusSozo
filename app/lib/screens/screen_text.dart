import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/contracts/link_launcher.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/providers/toast_provider.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/utils/app_log.dart';

/// The display name of a source.
String sourceName(AppLocalizations l10n, StatusSource source) =>
    switch (source) {
      StatusSource.standard => l10n.sourceStandard,
      StatusSource.business => l10n.sourceBusiness,
    };

/// The toast that best describes a failure.
ToastCode toastForError(AppErrorKind kind) => switch (kind) {
  AppErrorKind.accessLost => ToastCode.accessLost,
  AppErrorKind.wrongFolder => ToastCode.wrongFolder,
  AppErrorKind.pickerCancelled => ToastCode.pickerCancelled,
  AppErrorKind.notFound || AppErrorKind.io => ToastCode.ioError,
  AppErrorKind.permissionLost ||
  AppErrorKind.unsupported ||
  AppErrorKind.persistence ||
  AppErrorKind.unexpected => ToastCode.unexpected,
};

/// Opens an email draft to report a problem, with the local log attached to
/// the body. The log stays on the device unless the person sends the email.
Future<bool> composeReport({
  required LinkLauncher links,
  required AppLocalizations l10n,
  required String version,
}) {
  return links.composeEmail(
    to: AppConfig.supportEmail,
    subject: l10n.reportSubject(l10n.appName, version),
    body: '${l10n.reportBodyIntro}\n\n---\n${AppLog.report()}',
  );
}

/// Opens an email draft for feedback, prefilled with the app version and the
/// local log.
Future<bool> composeFeedback({
  required LinkLauncher links,
  required AppLocalizations l10n,
  required String version,
}) {
  return links.composeEmail(
    to: AppConfig.supportEmail,
    subject: l10n.feedbackSubject(l10n.appName, version),
    body: '${l10n.feedbackBodyIntro}\n\n---\n${AppLog.report()}',
  );
}
