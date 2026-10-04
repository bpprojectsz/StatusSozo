import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';

/// Inset grouped list: one card shell with hairline dividers between rows,
/// inset on the start edge to line up with the label text. This is the
/// settings-app look.
class AppGroup extends StatelessWidget {
  const AppGroup({
    required this.children,
    super.key,
    this.dividerInset = defaultDividerInset,
  });

  final List<Widget> children;

  /// Start inset of the dividers. Use [AppSpacing.md] for rows without icons.
  final double dividerInset;

  /// Aligns dividers with the label of an icon row.
  static const double defaultDividerInset =
      AppSpacing.md + AppSizes.iconRowLeading + AppSpacing.md;

  /// Key on each divider, for tests.
  static const ValueKey<String> dividerKey = ValueKey<String>('appGroupDivider');

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final List<Widget> stacked = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        stacked.add(
          Padding(
            padding: EdgeInsetsDirectional.only(start: dividerInset),
            child: SizedBox(
              key: dividerKey,
              height: AppSizes.hairline,
              width: double.infinity,
              child: ColoredBox(color: colors.borderSubtle),
            ),
          ),
        );
      }
      stacked.add(children[i]);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(
          color: colors.borderSubtle,
          width: AppSizes.hairline,
        ),
      ),
      child: ClipRRect(
        borderRadius: AppRadii.cardRadius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: stacked,
        ),
      ),
    );
  }
}
