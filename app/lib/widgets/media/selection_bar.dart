import 'dart:ui' show Brightness;

import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/widgets/primitives/primary_button.dart';

/// The floating action pill shown in selection mode: one compact
/// [PrimaryButton] plus supplied action chips (Share, Delete).
///
/// It rises over 400 ms, ignores touches while hidden, uses the single
/// permitted shadow in light mode and a hairline border in dark mode.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    required this.visible,
    required this.primaryLabel,
    required this.onPrimary,
    super.key,
    this.actions = const <Widget>[],
  });

  final bool visible;
  final String primaryLabel;
  final VoidCallback? onPrimary;

  /// Usually `NavIconButton`s.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final Brightness brightness = Theme.of(context).brightness;
    final Duration duration = AppMotion.resolve(context, AppMotion.sheet);

    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 1.5),
          duration: duration,
          curve: AppMotion.easeOut,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: duration,
            curve: AppMotion.easeOut,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.gutter,
                end: AppSpacing.gutter,
                bottom: AppSpacing.md,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.bgSecondary,
                  borderRadius: AppRadii.pillRadius,
                  boxShadow: AppShadows.floatingBar(brightness),
                  border: brightness == Brightness.dark
                      ? Border.all(
                          color: colors.borderSubtle,
                          width: AppSizes.hairline,
                        )
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: PrimaryButton(
                          label: primaryLabel,
                          expand: false,
                          onPressed: onPrimary,
                        ),
                      ),
                      for (final Widget action in actions) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        action,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
