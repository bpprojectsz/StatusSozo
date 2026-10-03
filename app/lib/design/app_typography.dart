import 'dart:ui' show FontFeature, FontVariation;

import 'package:flutter/material.dart';
import 'package:statussozo/design/app_colors.dart';

/// The only place text styles exist.
///
/// Fonts are bundled assets. Display uses Manrope, everything else Inter.
/// Weights are applied through [FontVariation] with [FontWeight] as fallback.
@immutable
class AppTextStyles extends ThemeExtension<AppTextStyles> {
  const AppTextStyles({
    required this.display,
    required this.headline,
    required this.wordmark,
    required this.title1,
    required this.title2,
    required this.callout,
    required this.footnote,
    required this.caption,
    required this.sectionHeader,
    required this.tabular,
    required this.body,
    required this.bodySecondary,
  });

  /// Builds the full set from a colour set.
  factory AppTextStyles.fromColors(AppColors colors) {
    return AppTextStyles(
      display: _style(
        family: _displayFamily,
        size: 34,
        weight: 700,
        height: 1.1,
        color: colors.textPrimary,
      ),
      headline: _style(
        family: _displayFamily,
        size: 28,
        weight: 600,
        height: 1.2,
        color: colors.textPrimary,
      ),
      wordmark: _style(
        family: _displayFamily,
        size: 20,
        weight: 800,
        height: 1.1,
        color: colors.textPrimary,
      ),
      title1: _style(
        family: _chromeFamily,
        size: 22,
        weight: 600,
        height: 1.3,
        color: colors.textPrimary,
      ),
      title2: _style(
        family: _chromeFamily,
        size: 17,
        weight: 600,
        height: 1.3,
        color: colors.textPrimary,
      ),
      callout: _style(
        family: _chromeFamily,
        size: 16,
        weight: 600,
        height: 1.4,
        color: colors.textPrimary,
      ),
      footnote: _style(
        family: _chromeFamily,
        size: 13,
        weight: 500,
        height: 1.4,
        color: colors.textSecondary,
      ),
      caption: _style(
        family: _chromeFamily,
        size: 12,
        weight: 500,
        height: 1.3,
        color: colors.textSecondary,
      ),
      sectionHeader: _style(
        family: _chromeFamily,
        size: 12,
        weight: 600,
        height: 1.3,
        color: colors.textTertiary,
        letterSpacing: 0.8,
      ),
      tabular: _style(
        family: _chromeFamily,
        size: 15,
        weight: 500,
        height: 1.3,
        color: colors.textPrimary,
        features: const <FontFeature>[FontFeature.tabularFigures()],
      ),
      body: _style(
        family: _chromeFamily,
        size: 17,
        weight: 400,
        height: 1.5,
        color: colors.textPrimary,
      ),
      bodySecondary: _style(
        family: _chromeFamily,
        size: 17,
        weight: 400,
        height: 1.5,
        color: colors.textSecondary,
      ),
    );
  }

  static const String _displayFamily = 'Manrope';
  static const String _chromeFamily = 'Inter';

  static TextStyle _style({
    required String family,
    required double size,
    required int weight,
    required double height,
    required Color color,
    double? letterSpacing,
    List<FontFeature>? features,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: <FontVariation>[FontVariation.weight(weight.toDouble())],
      height: height,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: features,
    );
  }

  /// Large titles.
  final TextStyle display;

  /// Hero headlines.
  final TextStyle headline;

  /// Brand wordmark. Used only on the Home nav bar.
  final TextStyle wordmark;

  /// Pushed-screen titles.
  final TextStyle title1;

  /// Row labels and sheet titles.
  final TextStyle title2;

  /// Buttons.
  final TextStyle callout;

  /// Chips and secondary lines.
  final TextStyle footnote;

  /// Badges.
  final TextStyle caption;

  /// Section headers. Callers uppercase the text.
  final TextStyle sectionHeader;

  /// Counts and video times, with tabular figures.
  final TextStyle tabular;

  /// Reading text.
  final TextStyle body;

  /// Reading text in the secondary colour.
  final TextStyle bodySecondary;

  /// Reads the active styles from the theme. Falls back to the light set.
  static AppTextStyles of(BuildContext context) =>
      Theme.of(context).extension<AppTextStyles>() ??
      AppTextStyles.fromColors(AppColors.light);

  @override
  AppTextStyles copyWith({
    TextStyle? display,
    TextStyle? headline,
    TextStyle? wordmark,
    TextStyle? title1,
    TextStyle? title2,
    TextStyle? callout,
    TextStyle? footnote,
    TextStyle? caption,
    TextStyle? sectionHeader,
    TextStyle? tabular,
    TextStyle? body,
    TextStyle? bodySecondary,
  }) {
    return AppTextStyles(
      display: display ?? this.display,
      headline: headline ?? this.headline,
      wordmark: wordmark ?? this.wordmark,
      title1: title1 ?? this.title1,
      title2: title2 ?? this.title2,
      callout: callout ?? this.callout,
      footnote: footnote ?? this.footnote,
      caption: caption ?? this.caption,
      sectionHeader: sectionHeader ?? this.sectionHeader,
      tabular: tabular ?? this.tabular,
      body: body ?? this.body,
      bodySecondary: bodySecondary ?? this.bodySecondary,
    );
  }

  @override
  AppTextStyles lerp(ThemeExtension<AppTextStyles>? other, double t) {
    if (other is! AppTextStyles) {
      return this;
    }
    return AppTextStyles(
      display: TextStyle.lerp(display, other.display, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
      wordmark: TextStyle.lerp(wordmark, other.wordmark, t)!,
      title1: TextStyle.lerp(title1, other.title1, t)!,
      title2: TextStyle.lerp(title2, other.title2, t)!,
      callout: TextStyle.lerp(callout, other.callout, t)!,
      footnote: TextStyle.lerp(footnote, other.footnote, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      sectionHeader: TextStyle.lerp(sectionHeader, other.sectionHeader, t)!,
      tabular: TextStyle.lerp(tabular, other.tabular, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodySecondary: TextStyle.lerp(bodySecondary, other.bodySecondary, t)!,
    );
  }
}
