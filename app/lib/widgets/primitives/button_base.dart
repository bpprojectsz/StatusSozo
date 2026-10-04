import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/widgets/icons/app_icon.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/primitives/loading_indicator.dart';
import 'package:statussozo/widgets/primitives/pressable.dart';

/// Shared geometry of the two button types: filled, height 52, radius 12,
/// press scale 0.97, disabled at 40%. Not used directly by screens.
class AppButtonBase extends StatelessWidget {
  const AppButtonBase({
    required this.label,
    required this.onPressed,
    required this.background,
    required this.foreground,
    super.key,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final AppIconData? icon;

  /// Swaps the label for the loading indicator and blocks taps.
  final bool loading;

  /// Fills the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles styles = AppTextStyles.of(context);
    final AppIconData? glyph = icon;

    final Widget content = loading
        ? AppLoadingIndicator(color: foreground)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (glyph != null) ...<Widget>[
                AppIcon(
                  glyph,
                  size: AppSizes.iconChipGlyph,
                  color: foreground,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: styles.callout.copyWith(color: foreground),
                ),
              ),
            ],
          );

    final Widget body = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.buttonRadius,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.buttonHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Center(
            widthFactor: expand ? null : 1,
            heightFactor: 1,
            child: content,
          ),
        ),
      ),
    );

    return Pressable(
      fill: expand,
      scaleOnPress: true,
      semanticLabel: label,
      enabled: onPressed != null || loading,
      onPressed: loading ? null : onPressed,
      child: body,
    );
  }
}
