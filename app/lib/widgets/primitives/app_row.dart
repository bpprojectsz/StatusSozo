import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/widgets/icons/app_icon.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/primitives/pressable.dart';

/// The one list row: leading icon, label, optional second line, trailing value
/// or chevron. Press feedback is a background tint, not opacity.
class AppRow extends StatelessWidget {
  const AppRow({
    required this.label,
    super.key,
    this.icon,
    this.secondary,
    this.trailing,
    this.showChevron = false,
    this.onPressed,
    this.destructive = false,
  });

  final AppIconData? icon;
  final String label;
  final String? secondary;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onPressed;

  /// Destructive rows use the error colour on both icon and label.
  final bool destructive;

  /// Gap between the leading icon and the label.
  static const double iconGap = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppTextStyles styles = AppTextStyles.of(context);
    final Color foreground = destructive ? colors.error : colors.textPrimary;
    final AppIconData? leading = icon;
    final String? second = secondary;
    final Widget? end = trailing;

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            AppIcon(
              leading,
              size: AppSizes.iconRowLeading,
              color: foreground,
            ),
            const SizedBox(width: iconGap),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: styles.title2.copyWith(color: foreground)),
                if (second != null) Text(second, style: styles.footnote),
              ],
            ),
          ),
          if (end != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            end,
          ] else if (showChevron) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            AppIcon(
              AppIcons.chevronForward,
              size: AppSizes.iconRowTrailing,
              color: colors.textTertiary,
              mirrorInRtl: true,
            ),
          ],
        ],
      ),
    );

    if (onPressed == null) {
      return MergeSemantics(child: content);
    }
    return Pressable(
      fill: true,
      pressedColor: colors.bgTertiary,
      onPressed: onPressed,
      child: content,
    );
  }
}
