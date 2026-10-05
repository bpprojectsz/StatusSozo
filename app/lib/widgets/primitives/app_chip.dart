import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/widgets/icons/app_icon.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/primitives/pressable.dart';

/// Visual tone of a chip. Tones also carry an icon, so colour is never the
/// only signal.
enum AppChipTone { neutral, success, warning }

/// The one chip: a pill on `bgTertiary` with an optional icon and a label.
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    super.key,
    this.icon,
    this.onPressed,
    this.tone = AppChipTone.neutral,
  });

  final String label;

  /// Defaults to a check for [AppChipTone.success] and a warning mark for
  /// [AppChipTone.warning].
  final AppIconData? icon;
  final VoidCallback? onPressed;
  final AppChipTone tone;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppTextStyles styles = AppTextStyles.of(context);

    final AppIconData? glyph = icon ?? switch (tone) {
      AppChipTone.success => AppIcons.check,
      AppChipTone.warning => AppIcons.warning,
      AppChipTone.neutral => null,
    };
    final Color glyphColor = switch (tone) {
      AppChipTone.success => colors.success,
      AppChipTone.warning => colors.warning,
      AppChipTone.neutral => colors.textSecondary,
    };

    final Widget chip = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgTertiary,
        borderRadius: AppRadii.pillRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + AppSpacing.xs,
          vertical: AppSpacing.sm - AppSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (glyph != null) ...<Widget>[
              AppIcon(glyph, size: AppSizes.iconChipGlyph, color: glyphColor),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                style: styles.footnote,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    if (onPressed == null) {
      return MergeSemantics(child: chip);
    }
    return Pressable(onPressed: onPressed, child: chip);
  }
}
