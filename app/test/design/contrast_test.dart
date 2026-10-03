import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/design/design.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double lighter = la > lb ? la : lb;
  final double darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  const double minimum = 4.5;

  void checkMode(String mode, AppColors c) {
    final Map<String, Color> foregrounds = <String, Color>{
      'textPrimary': c.textPrimary,
      'textSecondary': c.textSecondary,
      'textTertiary': c.textTertiary,
      'accent': c.accent,
      'error': c.error,
      'success': c.success,
      'warning': c.warning,
    };
    final Map<String, Color> backgrounds = <String, Color>{
      'bgPrimary': c.bgPrimary,
      'bgSecondary': c.bgSecondary,
    };

    for (final MapEntry<String, Color> fg in foregrounds.entries) {
      for (final MapEntry<String, Color> bg in backgrounds.entries) {
        test('$mode: ${fg.key} on ${bg.key} is at least $minimum:1', () {
          final double ratio = contrastRatio(fg.value, bg.value);
          expect(
            ratio,
            greaterThanOrEqualTo(minimum),
            reason: '${fg.key} on ${bg.key} is ${ratio.toStringAsFixed(2)}:1',
          );
        });
      }
    }

    test('$mode: accentOn on accent is at least $minimum:1', () {
      expect(
        contrastRatio(c.accentOn, c.accent),
        greaterThanOrEqualTo(minimum),
      );
    });

    test('$mode: textSecondary on bgTertiary is at least $minimum:1', () {
      expect(
        contrastRatio(c.textSecondary, c.bgTertiary),
        greaterThanOrEqualTo(minimum),
      );
    });
  }

  group('WCAG contrast', () {
    checkMode('light', AppColors.light);
    checkMode('dark', AppColors.dark);

    test('helper sanity: black on white is 21:1', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.001),
      );
    });
  });
}
