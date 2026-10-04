import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/widgets/icons/app_icon.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/primitives/pressable.dart';

/// A toolbar action: a 40 x 40 chip with a 22 px icon and a 48 px hit area.
/// No bare icon ever floats in a toolbar.
class NavIconButton extends StatelessWidget {
  const NavIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
    this.badge = false,
    this.mirrorInRtl = false,
  });

  final AppIconData icon;

  /// Required: the chip has no visible text.
  final String semanticLabel;
  final VoidCallback? onPressed;

  /// Shows a small dot at the top end corner.
  final bool badge;

  /// Flips the glyph under right-to-left layouts (for example back).
  final bool mirrorInRtl;

  static const double _badgeSize = 8;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return Pressable(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      child: SizedBox(
        width: AppSizes.iconChip,
        height: AppSizes.iconChip,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.bgSecondary,
                borderRadius: AppRadii.iconChipRadius,
                border: Border.all(
                  color: colors.borderSubtle,
                  width: AppSizes.hairline,
                ),
              ),
              child: Center(
                child: AppIcon(icon, mirrorInRtl: mirrorInRtl),
              ),
            ),
            if (badge)
              PositionedDirectional(
                top: AppSpacing.xs,
                end: AppSpacing.xs,
                child: SizedBox(
                  width: _badgeSize,
                  height: _badgeSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
