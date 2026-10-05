import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/widgets/icons/app_icon.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/primitives/secondary_button.dart';

/// The centred layout shared by empty and error views: a 72 px `bgTertiary`
/// circle holding a 40 px icon, a title, a message and optional actions. It
/// scrolls only when the text is too large to fit.
class StateLayout extends StatelessWidget {
  const StateLayout({
    required this.icon,
    required this.title,
    super.key,
    this.message,
    this.actions = const <Widget>[],
    this.compact = false,
  });

  final AppIconData icon;
  final String title;
  final String? message;
  final List<Widget> actions;

  /// Uses less padding, for inline use inside a larger screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppTextStyles styles = AppTextStyles.of(context);
    final String? body = message;
    final double padding = compact ? AppSpacing.md : AppSpacing.xl;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      width: AppSizes.emptyStateCircle,
                      height: AppSizes.emptyStateCircle,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.bgTertiary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: AppIcon(
                            icon,
                            size: AppSizes.iconHero,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: styles.title2,
                      ),
                    ),
                    if (body != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: styles.bodySecondary,
                      ),
                    ],
                    for (final Widget action in actions) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      action,
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// An empty view: icon, title, message and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    super.key,
    this.icon = AppIcons.image,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final AppIconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final String? label = actionLabel;
    return StateLayout(
      icon: icon,
      title: title,
      message: message,
      actions: <Widget>[
        if (label != null && onAction != null)
          SecondaryButton(label: label, expand: false, onPressed: onAction),
      ],
    );
  }
}
