import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/design/design.dart';

void main() {
  group('spacing', () {
    test('every value is a multiple of 2', () {
      const List<double> values = <double>[
        AppSpacing.xxs,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xxxl,
      ];
      for (final double v in values) {
        expect(v % 2, 0, reason: '$v is not a multiple of 2');
      }
    });

    test('main steps sit on the 4 px grid', () {
      const List<double> main = <double>[
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xxxl,
      ];
      for (final double v in main) {
        expect(v % 4, 0, reason: '$v is not on the 4 px grid');
      }
    });

    test('semantic aliases', () {
      expect(AppSpacing.gutter, AppSpacing.md);
      expect(AppSpacing.gridGap, AppSpacing.sm);
    });
  });

  group('radii', () {
    test('match the design specification', () {
      expect(AppRadii.card, 16);
      expect(AppRadii.hero, 24);
      expect(AppRadii.button, 12);
      expect(AppRadii.iconChip, 12);
      expect(AppRadii.thumb, 12);
      expect(AppRadii.sheetTop, 20);
      expect(AppRadii.dialog, 16);
      expect(AppRadii.pill, 999);
    });

    test('sheet radius rounds the top corners only', () {
      expect(AppRadii.sheetTopRadius.topLeft, const Radius.circular(20));
      expect(AppRadii.sheetTopRadius.topRight, const Radius.circular(20));
      expect(AppRadii.sheetTopRadius.bottomLeft, Radius.zero);
      expect(AppRadii.sheetTopRadius.bottomRight, Radius.zero);
    });
  });

  group('sizes', () {
    test('touch target is 48', () {
      expect(AppSizes.touchTarget, 48);
    });

    test('icon stroke is 2.0', () {
      expect(AppSizes.iconStroke, 2.0);
    });

    test('chrome sizes', () {
      expect(AppSizes.navBar, 56);
      expect(AppSizes.iconChip, 40);
      expect(AppSizes.buttonHeight, 52);
      expect(AppSizes.segmentHeight, 40);
      expect(AppSizes.hairline, 0.5);
      expect(AppSizes.gridMaxTileExtent, 140);
      expect(AppSizes.thumbnailRequestPx, 256);
      expect(AppSizes.selectionBadge, 24);
      expect(AppSizes.playCircle, 64);
      expect(AppSizes.scrubTrack, 4);
      expect(AppSizes.scrubTrackActive, 6);
      expect(AppSizes.scrubThumb, 14);
      expect(AppSizes.adSlotMaxHeight, 90);
      expect(AppSizes.adSlotGapAbove, 8);
    });
  });

  group('shadows', () {
    test('light has exactly one floating-bar shadow', () {
      final List<BoxShadow> shadows =
          AppShadows.floatingBar(Brightness.light);
      expect(shadows, hasLength(1));
      expect(shadows.single.blurRadius, 24);
      expect(shadows.single.offset, const Offset(0, 8));
    });

    test('dark has no shadow', () {
      expect(AppShadows.floatingBar(Brightness.dark), isEmpty);
    });
  });

  group('motion', () {
    test('durations match the specification', () {
      expect(AppMotion.push, const Duration(milliseconds: 350));
      expect(AppMotion.pop, const Duration(milliseconds: 280));
      expect(AppMotion.sheet, const Duration(milliseconds: 400));
      expect(AppMotion.press, const Duration(milliseconds: 150));
      expect(AppMotion.toast, const Duration(milliseconds: 300));
      expect(AppMotion.theme, const Duration(milliseconds: 200));
      expect(AppMotion.tab, const Duration(milliseconds: 200));
      expect(AppMotion.viewerControls, const Duration(milliseconds: 200));
    });

    test('no spring or bounce curve is exposed', () {
      expect(AppMotion.allCurves, isNotEmpty);
      for (final Curve curve in AppMotion.allCurves) {
        expect(curve, isNot(isA<ElasticInCurve>()));
        expect(curve, isNot(isA<ElasticOutCurve>()));
        expect(curve, isNot(isA<ElasticInOutCurve>()));
        expect(curve, isNot(equals(Curves.bounceIn)));
        expect(curve, isNot(equals(Curves.bounceOut)));
        expect(curve, isNot(equals(Curves.bounceInOut)));
      }
    });
  });
}
