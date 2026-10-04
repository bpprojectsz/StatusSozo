import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/utils/formatters.dart';

/// One segment of [SegmentedTabs].
class SegmentItem<T> {
  const SegmentItem({required this.value, required this.label, this.count});

  final T value;
  final String label;

  /// Optional count shown in tabular figures after the label.
  final int? count;
}

/// Tabs and segmented choice: a `bgTertiary` track with a sliding indicator.
/// The indicator moves over 200 ms (instantly under reduce motion) and uses
/// directional alignment, so it mirrors in right-to-left layouts.
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({
    required this.segments,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    super.key,
  });

  final List<SegmentItem<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final String semanticLabel;

  /// Gap above and below the track so the whole control is 48 px tall.
  static const double _trackInset =
      (AppSizes.touchTarget - AppSizes.segmentHeight) / 2;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppTextStyles styles = AppTextStyles.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final int count = segments.length;
    int selected = segments.indexWhere((SegmentItem<T> s) => s.value == value);
    if (selected < 0) {
      selected = 0;
    }
    final double alignment = count <= 1 ? -1 : -1 + 2 * selected / (count - 1);

    return Semantics(
      container: true,
      label: semanticLabel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: _trackInset),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.bgTertiary,
                    borderRadius: AppRadii.buttonRadius,
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(AppSpacing.xxs),
                    child: AnimatedAlign(
                      alignment: AlignmentDirectional(alignment, 0),
                      duration: AppMotion.resolve(context, AppMotion.tab),
                      curve: AppMotion.easeOut,
                      child: FractionallySizedBox(
                        widthFactor: 1 / count,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.bgSecondary,
                            borderRadius: BorderRadius.circular(
                              AppRadii.button - AppSpacing.xxs,
                            ),
                            border: Border.all(
                              color: colors.borderSubtle,
                              width: AppSizes.hairline,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: <Widget>[
                for (int i = 0; i < count; i++)
                  Expanded(
                    child: _Segment<T>(
                      item: segments[i],
                      selected: i == selected,
                      styles: styles,
                      colors: colors,
                      semanticText: segments[i].count == null
                          ? segments[i].label
                          : l10n.tabSemantics(
                              segments[i].label,
                              segments[i].count!,
                            ),
                      countText: segments[i].count == null
                          ? null
                          : formatCount(segments[i].count!, locale),
                      onTap: () => onChanged(segments[i].value),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.item,
    required this.selected,
    required this.styles,
    required this.colors,
    required this.semanticText,
    required this.countText,
    required this.onTap,
  });

  final SegmentItem<T> item;
  final bool selected;
  final AppTextStyles styles;
  final AppColors colors;
  final String semanticText;
  final String? countText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color text = selected ? colors.textPrimary : colors.textSecondary;
    final String? number = countText;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticText,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      item.label,
                      textAlign: TextAlign.center,
                      style: styles.footnote.copyWith(color: text),
                    ),
                  ),
                  if (number != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.xs),
                    Text(number, style: styles.tabular.copyWith(color: text)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
