import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';

/// The only widget that draws icons. Every icon uses the same stroke width so
/// it has the same visual weight as the text beside it.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = AppSizes.iconNav,
    this.color,
    this.semanticLabel,
    this.mirrorInRtl = false,
  });

  final AppIconData icon;
  final double size;

  /// Defaults to the primary text colour.
  final Color? color;

  /// When null the icon is decorative and hidden from screen readers.
  final String? semanticLabel;

  /// Flips the glyph under right-to-left layouts (back, chevrons, play).
  final bool mirrorInRtl;

  @override
  Widget build(BuildContext context) {
    final Color resolved = color ?? AppColors.of(context).textPrimary;
    Widget glyph = HugeIcon(
      icon: icon,
      size: size,
      color: resolved,
      strokeWidth: AppSizes.iconStroke,
    );
    if (mirrorInRtl && Directionality.of(context) == TextDirection.rtl) {
      glyph = Transform.flip(flipX: true, child: glyph);
    }
    final String? label = semanticLabel;
    if (label == null) {
      return ExcludeSemantics(child: glyph);
    }
    return Semantics(
      label: label,
      image: true,
      excludeSemantics: true,
      child: glyph,
    );
  }
}
