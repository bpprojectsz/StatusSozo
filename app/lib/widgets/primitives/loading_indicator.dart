import 'package:flutter/cupertino.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';

/// The one spinner: a `CupertinoActivityIndicator` tinted with a token.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key, this.color, this.radius = 10});

  /// Defaults to the secondary text colour.
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final Color resolved = color ?? AppColors.of(context).textSecondary;
    return Semantics(
      label: AppLocalizations.of(context).semLoading,
      child: CupertinoActivityIndicator(color: resolved, radius: radius),
    );
  }
}
