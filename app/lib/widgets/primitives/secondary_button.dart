import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/primitives/button_base.dart';

/// The one secondary action: same geometry, `accentSoft` fill, `accent` label.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final AppIconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    return AppButtonBase(
      label: label,
      onPressed: onPressed,
      icon: icon,
      loading: loading,
      expand: expand,
      background: colors.accentSoft,
      foreground: colors.accent,
    );
  }
}
