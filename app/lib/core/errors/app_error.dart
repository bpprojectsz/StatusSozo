import 'package:flutter/foundation.dart';

/// Every failure the app distinguishes.
enum AppErrorKind {
  accessLost,
  wrongFolder,
  pickerCancelled,
  notFound,
  io,
  permissionLost,
  unsupported,
  persistence,
  unexpected,
}

/// Where an error surfaced.
enum ErrorScope { listLoad, userAction, startup }

/// How the UI presents an error.
enum ErrorTreatment {
  accessScreen,
  inlineError,
  emptyState,
  toast,
  stickyToast,
  fullScreen,
}

/// A typed failure. Messages shown to people are localisation keys resolved in
/// the UI, never English text from here. [detail] and [cause] are for logs.
@immutable
class AppError {
  const AppError(this.kind, {this.cause, this.detail});

  final AppErrorKind kind;
  final Object? cause;
  final String? detail;

  /// Whether the app can keep running after this error.
  bool get recoverable => switch (kind) {
    AppErrorKind.unsupported || AppErrorKind.unexpected => false,
    _ => true,
  };

  /// Whether repeating the same operation can succeed.
  bool get retriable => switch (kind) {
    AppErrorKind.wrongFolder ||
    AppErrorKind.pickerCancelled ||
    AppErrorKind.io => true,
    _ => false,
  };

  /// Whether the person caused it, as opposed to the system.
  bool get userCaused => switch (kind) {
    AppErrorKind.wrongFolder || AppErrorKind.pickerCancelled => true,
    _ => false,
  };

  @override
  String toString() =>
      'AppError(${kind.name}${detail == null ? '' : ': $detail'})';
}

/// Maps an error and the scope it surfaced in to its UI treatment.
///
/// Combinations the product never produces (for example a wrong folder while
/// loading a list) use the same treatment as a user action for that kind.
ErrorTreatment treatmentFor(AppError error, ErrorScope scope) {
  final bool action = scope == ErrorScope.userAction;
  switch (error.kind) {
    case AppErrorKind.accessLost:
      return action ? ErrorTreatment.toast : ErrorTreatment.accessScreen;
    case AppErrorKind.wrongFolder:
    case AppErrorKind.pickerCancelled:
      return ErrorTreatment.toast;
    case AppErrorKind.notFound:
      return action ? ErrorTreatment.toast : ErrorTreatment.emptyState;
    case AppErrorKind.io:
      return action ? ErrorTreatment.toast : ErrorTreatment.inlineError;
    case AppErrorKind.permissionLost:
      return scope == ErrorScope.listLoad
          ? ErrorTreatment.inlineError
          : ErrorTreatment.toast;
    case AppErrorKind.unsupported:
    case AppErrorKind.unexpected:
      return action ? ErrorTreatment.toast : ErrorTreatment.fullScreen;
    case AppErrorKind.persistence:
      return ErrorTreatment.stickyToast;
  }
}
