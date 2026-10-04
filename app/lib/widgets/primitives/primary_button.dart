import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/primitives/button_base.dart';

/// The one primary action: filled `accent`, `accentOn` label, never outlined.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
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
      background: colors.accent,
      foreground: colors.accentOn,
    );
  }
}
