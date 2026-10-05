import 'package:flutter/widgets.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/widgets/feedback/empty_state.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/primitives/primary_button.dart';
import 'package:statussozo/widgets/primitives/secondary_button.dart';

/// Localised title for an error kind. Kinds that only ever appear as toasts
/// use the generic "something went wrong" wording.
String errorTitle(AppLocalizations l10n, AppErrorKind kind) => switch (kind) {
  AppErrorKind.accessLost => l10n.errorAccessLostTitle,
  AppErrorKind.wrongFolder => l10n.errorWrongFolderTitle,
  AppErrorKind.notFound => l10n.errorNotFoundTitle,
  AppErrorKind.io => l10n.errorIoTitle,
  AppErrorKind.permissionLost => l10n.errorPermissionLostTitle,
  AppErrorKind.unsupported => l10n.errorUnsupportedTitle,
  AppErrorKind.pickerCancelled ||
  AppErrorKind.persistence ||
  AppErrorKind.unexpected => l10n.errorUnexpectedTitle,
};

/// Localised message for an error kind.
String errorMessage(AppLocalizations l10n, AppErrorKind kind) =>
    switch (kind) {
      AppErrorKind.accessLost => l10n.errorAccessLostMessage,
      AppErrorKind.wrongFolder => l10n.errorWrongFolderMessage,
      AppErrorKind.notFound => l10n.errorNotFoundMessage,
      AppErrorKind.io => l10n.errorIoMessage,
      AppErrorKind.permissionLost => l10n.errorPermissionLostMessage,
      AppErrorKind.unsupported => l10n.errorUnsupportedMessage,
      AppErrorKind.pickerCancelled ||
      AppErrorKind.persistence ||
      AppErrorKind.unexpected => l10n.errorUnexpectedMessage,
    };

/// The label of the primary action for an error kind, or null when the kind
/// has no action.
String? errorAction(AppLocalizations l10n, AppErrorKind kind) =>
    switch (kind) {
      AppErrorKind.accessLost => l10n.errorAccessLostAction,
      AppErrorKind.wrongFolder => l10n.errorWrongFolderAction,
      AppErrorKind.notFound => l10n.errorNotFoundAction,
      AppErrorKind.io => l10n.errorIoAction,
      AppErrorKind.permissionLost => null,
      AppErrorKind.unsupported => l10n.errorUnsupportedAction,
      AppErrorKind.pickerCancelled ||
      AppErrorKind.persistence ||
      AppErrorKind.unexpected => l10n.errorUnexpectedAction,
    };

AppIconData _iconFor(AppErrorKind kind) => switch (kind) {
  AppErrorKind.accessLost => AppIcons.folderLink,
  AppErrorKind.wrongFolder || AppErrorKind.notFound => AppIcons.folder,
  AppErrorKind.io ||
  AppErrorKind.permissionLost ||
  AppErrorKind.unsupported => AppIcons.warning,
  AppErrorKind.pickerCancelled ||
  AppErrorKind.persistence ||
  AppErrorKind.unexpected => AppIcons.error,
};

/// An error view, inline or full screen.
///
/// The primary action uses the label for the error kind (Reconnect, Choose
/// folder, Refresh, Try again) and calls [onRetry]; it is shown only when
/// [onRetry] is given and the kind has such an action. A kind with nothing to
/// retry (a file that cannot be changed) shows no action. "Report a problem"
/// is the primary action for unsupported devices and a second action for
/// unexpected errors, and calls [onReport].
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.error,
    super.key,
    this.onRetry,
    this.onReport,
    this.compact = false,
  });

  final AppError error;
  final VoidCallback? onRetry;
  final VoidCallback? onReport;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppErrorKind kind = error.kind;
    final String? action = errorAction(l10n, kind);
    final VoidCallback? retry = onRetry;
    final VoidCallback? report = onReport;

    final List<Widget> actions = <Widget>[];
    if (kind == AppErrorKind.unsupported) {
      if (action != null && report != null) {
        actions.add(
          PrimaryButton(label: action, expand: false, onPressed: report),
        );
      }
    } else {
      if (action != null && retry != null) {
        actions.add(
          PrimaryButton(label: action, expand: false, onPressed: retry),
        );
      }
      if (kind == AppErrorKind.unexpected && report != null) {
        actions.add(
          SecondaryButton(
            label: l10n.commonReport,
            expand: false,
            onPressed: report,
          ),
        );
      }
    }

    return StateLayout(
      icon: _iconFor(kind),
      title: errorTitle(l10n, kind),
      message: errorMessage(l10n, kind),
      actions: actions,
      compact: compact,
    );
  }
}
