import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/widgets/feedback/empty_state.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/primitives/primary_button.dart';
import 'package:statussozo/widgets/primitives/secondary_button.dart';

/// The full-screen crash fallback. It depends on neither `AppScope` nor any
/// provider, because it can be built above the `MaterialApp`:
///
/// * colours fall back to the light set when the theme extension is missing;
/// * text falls back to three English strings when localisation is missing;
/// * it supplies its own direction and media query when none exist.
class ErrorFallbackScreen extends StatelessWidget {
  const ErrorFallbackScreen({
    required this.onRetry,
    required this.onReport,
    super.key,
  });

  final VoidCallback onRetry;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? l10n = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    final String title = l10n?.fallbackTitle ?? 'Something went wrong';
    final String message =
        l10n?.fallbackMessage ??
        'The app ran into a problem. You can try again or report it.';
    final String retry = l10n?.fallbackRetry ?? 'Try again';
    final String report = l10n?.fallbackReport ?? 'Report a problem';

    final AppColors colors = AppColors.of(context);
    final AppTextStyles styles = AppTextStyles.of(context);

    Widget content = ColoredBox(
      color: colors.bgPrimary,
      child: DefaultTextStyle(
        style: styles.body,
        child: SafeArea(
          child: StateLayout(
            icon: AppIcons.error,
            title: title,
            message: message,
            actions: <Widget>[
              PrimaryButton(label: retry, expand: false, onPressed: onRetry),
              SecondaryButton(
                label: report,
                expand: false,
                onPressed: onReport,
              ),
            ],
          ),
        ),
      ),
    );

    if (MediaQuery.maybeOf(context) == null) {
      content = MediaQuery(
        data: MediaQueryData.fromView(
          View.maybeOf(context) ??
              PlatformDispatcher.instance.views.first,
        ),
        child: content,
      );
    }
    if (Directionality.maybeOf(context) == null) {
      content = Directionality(
        textDirection: TextDirection.ltr,
        child: content,
      );
    }
    return content;
  }
}
