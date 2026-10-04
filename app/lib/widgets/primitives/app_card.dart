import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/widgets/icons/app_icon.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/primitives/pressable.dart';

/// The one card: `bgSecondary` fill, hairline border, radius 16, no elevation.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.onPressed,
    this.onLongPress,
    this.padding = const EdgeInsetsDirectional.all(AppSpacing.md),
  });

  /// The standard icon, label, value and chevron layout.
  AppCard.tile({
    required String label,
    super.key,
    AppIconData? icon,
    String? value,
    bool showChevron = false,
    this.onPressed,
  }) : onLongPress = null,
       padding = const EdgeInsetsDirectional.all(AppSpacing.md),
       child = _TileContent(
         icon: icon,
         label: label,
         value: value,
         showChevron: showChevron,
       );

  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(
          color: colors.borderSubtle,
          width: AppSizes.hairline,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onPressed == null && onLongPress == null) {
      return card;
    }
    return Pressable(
      fill: true,
      onPressed: onPressed,
      onLongPress: onLongPress,
      child: card,
    );
  }
}

class _TileContent extends StatelessWidget {
  const _TileContent({
    required this.label,
    required this.showChevron,
    this.icon,
    this.value,
  });

  final AppIconData? icon;
  final String label;
  final String? value;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppTextStyles styles = AppTextStyles.of(context);
    final AppIconData? leading = icon;
    final String? trailingValue = value;
    return Row(
      children: <Widget>[
        if (leading != null) ...<Widget>[
          AppIcon(leading, size: AppSizes.iconRowLeading),
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(child: Text(label, style: styles.title2)),
        if (trailingValue != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              trailingValue,
              style: styles.footnote,
              textAlign: TextAlign.end,
            ),
          ),
        ],
        if (showChevron) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          AppIcon(
            AppIcons.chevronForward,
            size: AppSizes.iconRowTrailing,
            color: colors.textTertiary,
            mirrorInRtl: true,
          ),
        ],
      ],
    );
  }
}
