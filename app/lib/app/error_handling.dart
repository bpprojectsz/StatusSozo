import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:statussozo/app/app_services.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/screens/error_fallback_screen.dart';
import 'package:statussozo/screens/screen_text.dart';
import 'package:statussozo/utils/app_log.dart';

/// Rebuilds the whole app tree. The crash fallback's "Try again" uses it.
abstract final class AppRestart {
  static final ValueNotifier<int> signal = ValueNotifier<int>(0);

  static void request() => signal.value++;
}

/// Runs [body] in a guarded zone so nothing escapes uncaught. Everything that
/// starts the app belongs inside [body].
void runGuarded(Future<void> Function() body) {
  runZonedGuarded<void>(
    () => unawaited(body()),
    (Object error, StackTrace stack) =>
        AppLog.error('zone', 'Uncaught error', error),
  );
}

/// Installs the global handlers and returns a function that restores the
/// previous ones.
///
/// * `FlutterError.onError` logs locally and keeps the default presentation
///   in debug builds.
/// * `PlatformDispatcher.onError` logs and marks the error handled.
/// * In release and profile builds (or when [useFallbackWidget] is true),
///   `ErrorWidget.builder` shows [ErrorFallbackScreen], never a grey box.
void Function() installGlobalErrorHandling(
  AppServices services, {
  bool? useFallbackWidget,
}) {
  final FlutterExceptionHandler? previousFlutter = FlutterError.onError;
  final ErrorWidgetBuilder previousBuilder = ErrorWidget.builder;
  final bool Function(Object, StackTrace)? previousPlatform =
      PlatformDispatcher.instance.onError;

  FlutterError.onError = (FlutterErrorDetails details) {
    AppLog.error('flutter', details.exceptionAsString(), details.exception);
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLog.error('platform', 'Unhandled error', error);
    return true;
  };
  if (useFallbackWidget ?? !kDebugMode) {
    ErrorWidget.builder = (FlutterErrorDetails details) => ErrorFallbackScreen(
      onRetry: AppRestart.request,
      onReport: () => unawaited(_report(services)),
    );
  }

  return () {
    FlutterError.onError = previousFlutter;
    ErrorWidget.builder = previousBuilder;
    PlatformDispatcher.instance.onError = previousPlatform;
  };
}

Future<void> _report(AppServices services) async {
  final AppLocalizations l10n = lookupAppLocalizations(
    PlatformDispatcher.instance.locale,
  );
  await composeReport(
    links: services.links,
    l10n: l10n,
    version: services.appVersion,
  );
}
