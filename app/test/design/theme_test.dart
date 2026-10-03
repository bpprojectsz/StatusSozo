import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/design/design.dart';

void main() {
  group('AppTheme', () {
    test('light and dark build with both extensions', () {
      for (final ThemeData theme in <ThemeData>[
        AppTheme.light(),
        AppTheme.dark(),
      ]) {
        expect(theme.extension<AppColors>(), isNotNull);
        expect(theme.extension<AppTextStyles>(), isNotNull);
        expect(theme.useMaterial3, isTrue);
      }
    });

    test('brightness and scaffold colours come from tokens', () {
      final ThemeData light = AppTheme.light();
      final ThemeData dark = AppTheme.dark();
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.scaffoldBackgroundColor, AppColors.light.bgPrimary);
      expect(dark.scaffoldBackgroundColor, AppColors.dark.bgPrimary);
    });

    test('splash is disabled', () {
      expect(AppTheme.light().splashFactory, NoSplash.splashFactory);
      expect(AppTheme.dark().splashFactory, NoSplash.splashFactory);
    });
  });

  group('AppColors', () {
    test('lerp at 0 and 1 returns the endpoints', () {
      final AppColors atZero = AppColors.light.lerp(AppColors.dark, 0);
      final AppColors atOne = AppColors.light.lerp(AppColors.dark, 1);
      expect(atZero.bgPrimary, AppColors.light.bgPrimary);
      expect(atOne.bgPrimary, AppColors.dark.bgPrimary);
    });

    test('lerp at 0.5 gives intermediate values', () {
      final AppColors mid = AppColors.light.lerp(AppColors.dark, 0.5);
      expect(mid.bgPrimary, isNot(AppColors.light.bgPrimary));
      expect(mid.bgPrimary, isNot(AppColors.dark.bgPrimary));
      expect(
        mid.bgPrimary,
        Color.lerp(AppColors.light.bgPrimary, AppColors.dark.bgPrimary, 0.5),
      );
      expect(
        mid.textPrimary,
        Color.lerp(AppColors.light.textPrimary, AppColors.dark.textPrimary, 0.5),
      );
    });

    test('lerp with a foreign extension returns this', () {
      expect(AppColors.light.lerp(null, 0.5), same(AppColors.light));
    });

    test('copyWith replaces only the named field', () {
      final AppColors copy = AppColors.light.copyWith(
        accent: const Color(0xFF123456),
      );
      expect(copy.accent, const Color(0xFF123456));
      expect(copy.bgPrimary, AppColors.light.bgPrimary);
      expect(copy.textPrimary, AppColors.light.textPrimary);
    });

    test('scrim is black at 55 percent', () {
      expect(AppColors.light.scrim, const Color(0x8C000000));
      expect(AppColors.dark.scrim, const Color(0x8C000000));
      expect(AppColors.light.viewerBg, const Color(0xFF000000));
      expect(AppColors.light.onScrim, const Color(0xFFFFFFFF));
    });
  });

  group('AppTextStyles', () {
    final AppTextStyles styles = AppTextStyles.fromColors(AppColors.light);

    test('display roles use Manrope', () {
      expect(styles.display.fontFamily, 'Manrope');
      expect(styles.headline.fontFamily, 'Manrope');
      expect(styles.wordmark.fontFamily, 'Manrope');
    });

    test('chrome and body roles use Inter', () {
      for (final TextStyle s in <TextStyle>[
        styles.title1,
        styles.title2,
        styles.callout,
        styles.footnote,
        styles.caption,
        styles.sectionHeader,
        styles.tabular,
        styles.body,
        styles.bodySecondary,
      ]) {
        expect(s.fontFamily, 'Inter');
      }
    });

    test('sizes, weights and line heights match the specification', () {
      expect(styles.display.fontSize, 34);
      expect(styles.display.fontWeight, FontWeight.w700);
      expect(styles.display.height, 1.1);
      expect(styles.wordmark.fontWeight, FontWeight.w800);
      expect(styles.headline.fontWeight, FontWeight.w600);
      expect(styles.title1.fontSize, 22);
      expect(styles.title2.fontSize, 17);
      expect(styles.callout.fontSize, 16);
      expect(styles.footnote.fontSize, 13);
      expect(styles.caption.fontSize, 12);
      expect(styles.body.fontSize, 17);
      expect(styles.body.fontWeight, FontWeight.w400);
      expect(styles.body.height, 1.5);
    });

    test('section header has positive letter spacing', () {
      expect(styles.sectionHeader.letterSpacing, 0.8);
    });

    test('tabular style enables tabular figures', () {
      final List<FontFeature>? features = styles.tabular.fontFeatures;
      expect(features, isNotNull);
      expect(features, contains(const FontFeature.tabularFigures()));
    });

    test('variable weight axis matches the weight', () {
      final List<FontVariation>? variations = styles.display.fontVariations;
      expect(variations, isNotNull);
      expect(variations!.single.axis, 'wght');
      expect(variations.single.value, 700);
    });

    test('secondary body uses the secondary text colour', () {
      expect(styles.bodySecondary.color, AppColors.light.textSecondary);
      expect(styles.body.color, AppColors.light.textPrimary);
    });

    test('lerp interpolates colours between modes', () {
      final AppTextStyles dark = AppTextStyles.fromColors(AppColors.dark);
      final AppTextStyles mid = styles.lerp(dark, 0.5);
      expect(mid.body.color, isNot(styles.body.color));
      expect(mid.body.color, isNot(dark.body.color));
    });
  });
}
