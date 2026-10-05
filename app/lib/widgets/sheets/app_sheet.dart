import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/primitives/app_group.dart';
import 'package:statussozo/widgets/primitives/app_row.dart';

/// One row of an action sheet.
class SheetAction {
  const SheetAction({
    required this.label,
    this.icon,
    this.subtitle,
    this.destructive = false,
    this.onSelected,
  });

  final AppIconData? icon;
  final String label;
  final String? subtitle;

  /// Uses the error colour on both icon and label.
  final bool destructive;

  /// Called after the sheet has closed. Null just closes the sheet.
  final VoidCallback? onSelected;
}

/// Shows a bottom sheet: a custom route (not the Material sheet) with a 55%
/// scrim, a 400 ms slide up, a 20 px top radius and safe-area padding. The
/// scrim tap and the back button dismiss it. Under reduce motion it appears
/// without movement.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  List<SheetAction> actions = const <SheetAction>[],
  Widget? content,
  bool showGrabber = true,
}) {
  final AppColors colors = AppColors.of(context);
  final AppLocalizations l10n = AppLocalizations.of(context);
  return Navigator.of(context).push<T>(
    _AppSheetRoute<T>(
      title: title,
      actions: actions,
      content: content,
      showGrabber: showGrabber,
      scrim: colors.scrim,
      dismissLabel: l10n.commonClose,
      reduceMotion: AppMotion.reduced(context),
    ),
  );
}

/// A ready confirmation sheet. Returns true only when the person confirms;
/// dismissing by scrim, back button or cancel returns false.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String cancelLabel,
  String? message,
  AppIconData? confirmIcon,
  bool destructive = true,
}) async {
  bool confirmed = false;
  final String? body = message;
  await showAppSheet<void>(
    context,
    title: title,
    content: body == null ? null : _SheetMessage(body),
    actions: <SheetAction>[
      SheetAction(
        icon: confirmIcon,
        label: confirmLabel,
        destructive: destructive,
        onSelected: () => confirmed = true,
      ),
      SheetAction(icon: AppIcons.close, label: cancelLabel),
    ],
  );
  return confirmed;
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.of(context).bodySecondary);
  }
}

class _AppSheetRoute<T> extends PopupRoute<T> {
  _AppSheetRoute({
    required this.title,
    required this.actions,
    required this.content,
    required this.showGrabber,
    required Color scrim,
    required String dismissLabel,
    required bool reduceMotion,
  }) : _scrim = scrim,
       _dismissLabel = dismissLabel,
       _reduceMotion = reduceMotion;

  final String title;
  final List<SheetAction> actions;
  final Widget? content;
  final bool showGrabber;
  final Color _scrim;
  final String _dismissLabel;
  final bool _reduceMotion;

  @override
  Color? get barrierColor => _scrim;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => _dismissLabel;

  @override
  Duration get transitionDuration =>
      _reduceMotion ? Duration.zero : AppMotion.sheet;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _SheetPage(
      title: title,
      actions: actions,
      content: content,
      showGrabber: showGrabber,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_reduceMotion) {
      return child;
    }
    return SlideTransition(
      position: animation.drive(
        Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).chain(CurveTween(curve: AppMotion.easeOut)),
      ),
      child: child,
    );
  }
}

class _SheetPage extends StatelessWidget {
  const _SheetPage({
    required this.title,
    required this.actions,
    required this.content,
    required this.showGrabber,
  });

  final String title;
  final List<SheetAction> actions;
  final Widget? content;
  final bool showGrabber;

  static const double _grabberWidth = 36;
  static const double _grabberHeight = 4;
  static const double _maxWidth = 560;
  static const double _maxHeightFactor = 0.9;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppTextStyles styles = AppTextStyles.of(context);
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final Widget? body = content;

    return Align(
      alignment: AlignmentDirectional.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: _maxWidth,
          maxHeight: screenHeight * _maxHeightFactor,
        ),
        child: DefaultTextStyle(
          style: styles.body,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.bgSecondary,
              borderRadius: AppRadii.sheetTopRadius,
              border: Border.all(
                color: colors.borderSubtle,
                width: AppSizes.hairline,
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (showGrabber)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: SizedBox(
                            width: _grabberWidth,
                            height: _grabberHeight,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.borderSubtle,
                                borderRadius: AppRadii.pillRadius,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Semantics(
                      header: true,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: AppSpacing.md,
                          end: AppSpacing.md,
                          top: AppSpacing.md,
                          bottom: AppSpacing.sm,
                        ),
                        child: Text(title, style: styles.title2),
                      ),
                    ),
                    if (body != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: AppSpacing.md,
                          end: AppSpacing.md,
                          bottom: AppSpacing.md,
                        ),
                        child: body,
                      ),
                    if (actions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: AppSpacing.md,
                          end: AppSpacing.md,
                          bottom: AppSpacing.md,
                        ),
                        child: AppGroup(
                          dividerInset: AppSpacing.md,
                          children: <Widget>[
                            for (final SheetAction action in actions)
                              AppRow(
                                icon: action.icon,
                                label: action.label,
                                secondary: action.subtitle,
                                destructive: action.destructive,
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  action.onSelected?.call();
                                },
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
