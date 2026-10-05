import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/widgets/icons/app_icon.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/primitives/app_card.dart';
import 'package:statussozo/widgets/primitives/app_chip.dart';
import 'package:statussozo/widgets/primitives/app_group.dart';
import 'package:statussozo/widgets/primitives/app_row.dart';
import 'package:statussozo/widgets/primitives/loading_indicator.dart';
import 'package:statussozo/widgets/primitives/nav_icon_button.dart';
import 'package:statussozo/widgets/primitives/pressable.dart';
import 'package:statussozo/widgets/primitives/primary_button.dart';
import 'package:statussozo/widgets/primitives/secondary_button.dart';
import 'package:statussozo/widgets/primitives/section_header.dart';
import 'package:statussozo/widgets/primitives/segmented_tabs.dart';

import 'harness.dart';

Widget _everything() {
  return SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader('Folders'),
        AppGroup(
          children: <Widget>[
            AppRow(
              icon: AppIcons.folder,
              label: 'Standard',
              secondary: 'A second line of text that is rather long',
              trailing: const AppChip(label: 'Connected', tone: AppChipTone.success),
              onPressed: () {},
            ),
            AppRow(
              icon: AppIcons.delete,
              label: 'Disconnect',
              destructive: true,
              showChevron: true,
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 8),
        AppCard.tile(
          icon: AppIcons.language,
          label: 'Language',
          value: 'System default',
          showChevron: true,
          onPressed: () {},
        ),
        const SizedBox(height: 8),
        const AppCard(child: Text('Plain card content that may wrap')),
        const SizedBox(height: 8),
        PrimaryButton(label: 'Choose folder', icon: AppIcons.folder, onPressed: () {}),
        const SizedBox(height: 8),
        SecondaryButton(label: 'Use Business instead', onPressed: () {}),
        const SizedBox(height: 8),
        const PrimaryButton(label: 'Disabled', onPressed: null),
        const SizedBox(height: 8),
        PrimaryButton(label: 'Loading', loading: true, onPressed: () {}),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            NavIconButton(
              icon: AppIcons.back,
              semanticLabel: 'Back',
              mirrorInRtl: true,
              onPressed: () {},
            ),
            NavIconButton(
              icon: AppIcons.settings,
              semanticLabel: 'Settings',
              badge: true,
              onPressed: () {},
            ),
          ],
        ),
        const AppLoadingIndicator(),
        SegmentedTabs<int>(
          segments: const <SegmentItem<int>>[
            SegmentItem<int>(value: 0, label: 'Photos', count: 1234),
            SegmentItem<int>(value: 1, label: 'Videos', count: 5),
          ],
          value: 0,
          onChanged: (int _) {},
          semanticLabel: 'Media type',
        ),
      ],
    ),
  );
}

void main() {
  group('renders everywhere without overflow', () {
    for (final bool dark in <bool>[false, true]) {
      for (final TextDirection direction in TextDirection.values) {
        for (final double scale in <double>[1, 2]) {
          testWidgets(
            '${dark ? 'dark' : 'light'} ${direction.name} x$scale',
            (WidgetTester tester) async {
              useSurface(tester);
              await tester.pumpWidget(
                harness(
                  _everything(),
                  dark: dark,
                  direction: direction,
                  textScale: scale,
                ),
              );
              await tester.pump();
              final Object? problem = tester.takeException();
              expect(
                problem,
                isNull,
                reason: problem is FlutterError ? problem.toStringDeep() : '',
              );
              expect(find.text('Choose folder'), findsOneWidget);
              expect(find.text('FOLDERS'), findsOneWidget);
            },
          );
        }
      }
    }
  });

  group('Pressable', () {
    testWidgets('has a hit area of at least 48 x 48 around a tiny child', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const Pressable(
            onPressed: null,
            child: SizedBox(width: 10, height: 10),
          ),
        ),
      );
      final Size size = tester.getSize(find.byType(Pressable));
      expect(size.width, greaterThanOrEqualTo(AppSizes.touchTarget));
      expect(size.height, greaterThanOrEqualTo(AppSizes.touchTarget));
    });

    testWidgets('taps reach the callback, even outside a tiny child', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        harness(
          Pressable(
            onPressed: () => taps++,
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );
      final Rect box = tester.getRect(find.byType(Pressable));
      await tester.tapAt(box.topLeft + const Offset(3, 3));
      expect(taps, 1);
    });

    testWidgets('long press fires its own callback', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      int longs = 0;
      await tester.pumpWidget(
        harness(
          Pressable(
            onPressed: () => taps++,
            onLongPress: () => longs++,
            child: const SizedBox(width: 60, height: 60),
          ),
        ),
      );
      await tester.longPress(find.byType(Pressable));
      expect(longs, 1);
      expect(taps, 0);
    });

    testWidgets('exposes a button role and its label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          Pressable(
            onPressed: () {},
            semanticLabel: 'Go',
            child: const SizedBox(width: 60, height: 60),
          ),
        ),
      );
      final SemanticsData data = tester
          .getSemantics(find.bySemanticsLabel('Go'))
          .getSemanticsData();
      expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(data.hasFlag(SemanticsFlag.isEnabled), isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('disabled ignores taps and renders at 40 percent', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        harness(
          Pressable(
            enabled: false,
            onPressed: () => taps++,
            child: const SizedBox(width: 60, height: 60),
          ),
        ),
      );
      await tester.tap(find.byType(Pressable));
      await tester.pump();
      expect(taps, 0);
      final AnimatedOpacity opacity = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(Pressable),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(opacity.opacity, Pressable.disabledOpacity);
    });

    testWidgets('without a callback it does nothing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(const Pressable(child: SizedBox(width: 60, height: 60))),
      );
      await tester.tap(find.byType(Pressable));
      expect(tester.takeException(), isNull);
    });

    testWidgets('press feedback changes opacity, then restores it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          Pressable(
            onPressed: () {},
            child: const SizedBox(width: 60, height: 60),
          ),
        ),
      );
      final Finder opacityFinder = find.descendant(
        of: find.byType(Pressable),
        matching: find.byType(AnimatedOpacity),
      );
      expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 1);
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(Pressable)),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 0.7);
      await gesture.up();
      await tester.pump();
      expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 1);
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('scale feedback goes to 0.97 when enabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          Pressable(
            onPressed: () {},
            scaleOnPress: true,
            child: const SizedBox(width: 60, height: 60),
          ),
        ),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(Pressable)),
      );
      await tester.pump(const Duration(milliseconds: 150));
      final AnimatedScale scale = tester.widget<AnimatedScale>(
        find.descendant(
          of: find.byType(Pressable),
          matching: find.byType(AnimatedScale),
        ),
      );
      expect(scale.scale, Pressable.pressedScale);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('a tint replaces the opacity change when pressedColor is set', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          Pressable(
            onPressed: () {},
            pressedColor: AppColors.light.bgTertiary,
            fill: true,
            child: const SizedBox(height: 60),
          ),
        ),
      );
      final Finder opacityFinder = find.descendant(
        of: find.byType(Pressable),
        matching: find.byType(AnimatedOpacity),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(Pressable)),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 1);
      final AnimatedContainer tint = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(Pressable),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(tint.decoration, isNotNull);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('reduce motion makes feedback instant', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          Pressable(
            onPressed: () {},
            child: const SizedBox(width: 60, height: 60),
          ),
          disableAnimations: true,
        ),
      );
      final AnimatedOpacity opacity = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(Pressable),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(opacity.duration, Duration.zero);
    });
  });

  group('AppIcon', () {
    testWidgets('passes a stroke width of 2.0 to the icon widget', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(const AppIcon(AppIcons.check)));
      final HugeIcon icon = tester.widget<HugeIcon>(find.byType(HugeIcon));
      expect(icon.strokeWidth, 2.0);
      expect(icon.size, AppSizes.iconNav);
    });

    testWidgets('defaults to the primary text colour', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(const AppIcon(AppIcons.check)));
      expect(
        tester.widget<HugeIcon>(find.byType(HugeIcon)).color,
        AppColors.light.textPrimary,
      );
    });

    testWidgets('is hidden from screen readers without a label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(harness(const AppIcon(AppIcons.check)));
      expect(find.bySemanticsLabel('Done'), findsNothing);
      handle.dispose();
    });

    testWidgets('announces its label when given one', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(const AppIcon(AppIcons.check, semanticLabel: 'Done')),
      );
      expect(find.bySemanticsLabel('Done'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('mirrors only in right-to-left when asked', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(const AppIcon(AppIcons.back, mirrorInRtl: true)),
      );
      expect(
        find.descendant(
          of: find.byType(AppIcon),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
      await tester.pumpWidget(
        harness(
          const AppIcon(AppIcons.back, mirrorInRtl: true),
          direction: TextDirection.rtl,
        ),
      );
      expect(
        find.descendant(
          of: find.byType(AppIcon),
          matching: find.byType(Transform),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(
        harness(
          const AppIcon(AppIcons.back),
          direction: TextDirection.rtl,
        ),
      );
      expect(
        find.descendant(
          of: find.byType(AppIcon),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    });
  });

  group('buttons', () {
    testWidgets('PrimaryButton fires and shows its label', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        harness(PrimaryButton(label: 'Go', onPressed: () => taps++)),
      );
      expect(find.text('Go'), findsOneWidget);
      await tester.tap(find.text('Go'));
      expect(taps, 1);
    });

    testWidgets('PrimaryButton is at least 52 tall and fills the width', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(PrimaryButton(label: 'Go', onPressed: () {})),
      );
      final Size size = tester.getSize(find.byType(PrimaryButton));
      expect(size.height, greaterThanOrEqualTo(AppSizes.buttonHeight));
      expect(size.width, 360);
    });

    testWidgets('a non-expanding button shrinks to its content', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          Align(
            alignment: AlignmentDirectional.topStart,
            child: PrimaryButton(label: 'Go', expand: false, onPressed: () {}),
          ),
        ),
      );
      expect(tester.getSize(find.byType(PrimaryButton)).width, lessThan(200));
    });

    testWidgets('a disabled button ignores taps and is dimmed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(const PrimaryButton(label: 'Go', onPressed: null)),
      );
      await tester.tap(find.text('Go'));
      final AnimatedOpacity opacity = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(PrimaryButton),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(opacity.opacity, Pressable.disabledOpacity);
    });

    testWidgets('loading shows the spinner, hides the label and blocks taps', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        harness(
          PrimaryButton(label: 'Go', loading: true, onPressed: () => taps++),
        ),
      );
      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      expect(find.text('Go'), findsNothing);
      await tester.tap(find.byType(PrimaryButton));
      expect(taps, 0);
    });

    testWidgets('press scales a button to 0.97', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(PrimaryButton(label: 'Go', onPressed: () {})),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(PrimaryButton)),
      );
      await tester.pump(const Duration(milliseconds: 150));
      final AnimatedScale scale = tester.widget<AnimatedScale>(
        find.descendant(
          of: find.byType(PrimaryButton),
          matching: find.byType(AnimatedScale),
        ),
      );
      expect(scale.scale, 0.97);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('PrimaryButton uses accent, SecondaryButton accentSoft', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          Column(
            children: <Widget>[
              PrimaryButton(label: 'Primary', onPressed: () {}),
              SecondaryButton(label: 'Secondary', onPressed: () {}),
            ],
          ),
        ),
      );
      Color? fillOf(Type parent) {
        final DecoratedBox box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(parent),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        return (box.decoration as BoxDecoration).color;
      }

      expect(fillOf(PrimaryButton), AppColors.light.accent);
      expect(fillOf(SecondaryButton), AppColors.light.accentSoft);
    });

    testWidgets('a button exposes its label and button role', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(PrimaryButton(label: 'Choose folder', onPressed: () {})),
      );
      final SemanticsData data = tester
          .getSemantics(find.bySemanticsLabel('Choose folder'))
          .getSemanticsData();
      expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
      handle.dispose();
    });
  });

  group('AppRow', () {
    testWidgets('shows label, second line and fires onPressed', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        harness(
          AppRow(
            label: 'Theme',
            secondary: 'Choose a look',
            showChevron: true,
            onPressed: () => taps++,
          ),
        ),
      );
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Choose a look'), findsOneWidget);
      await tester.tap(find.text('Theme'));
      expect(taps, 1);
    });

    testWidgets('destructive rows use the error colour on label and icon', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          AppRow(
            icon: AppIcons.delete,
            label: 'Delete',
            destructive: true,
            onPressed: () {},
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('Delete')).style?.color,
        AppColors.light.error,
      );
      expect(
        tester.widget<HugeIcon>(find.byType(HugeIcon)).color,
        AppColors.light.error,
      );
    });

    testWidgets('a row without onPressed is not a button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(const AppRow(label: 'Version')));
      expect(find.byType(Pressable), findsNothing);
    });

    testWidgets('a trailing widget replaces the chevron', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const AppRow(
            label: 'Folder',
            showChevron: true,
            trailing: AppChip(label: 'Connected'),
          ),
        ),
      );
      expect(find.text('Connected'), findsOneWidget);
      expect(find.byType(HugeIcon), findsNothing);
    });

    testWidgets('keeps a minimum height of 48', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(AppRow(label: 'Short', onPressed: () {})),
      );
      expect(
        tester.getSize(find.byType(AppRow)).height,
        greaterThanOrEqualTo(AppSizes.touchTarget),
      );
    });
  });

  group('AppGroup and AppCard', () {
    testWidgets('a group draws one divider between each pair of rows', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const AppGroup(
            children: <Widget>[
              AppRow(label: 'One'),
              AppRow(label: 'Two'),
              AppRow(label: 'Three'),
            ],
          ),
        ),
      );
      expect(find.byKey(AppGroup.dividerKey), findsNWidgets(2));
    });

    testWidgets('a group of one row has no divider', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(const AppGroup(children: <Widget>[AppRow(label: 'One')])),
      );
      expect(find.byKey(AppGroup.dividerKey), findsNothing);
    });

    testWidgets('dividers are hairlines inset on the start edge', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const AppGroup(
            children: <Widget>[AppRow(label: 'One'), AppRow(label: 'Two')],
          ),
        ),
      );
      final Rect divider = tester.getRect(find.byKey(AppGroup.dividerKey));
      final Rect group = tester.getRect(find.byType(AppGroup));
      expect(divider.height, AppSizes.hairline);
      expect(divider.left - group.left, AppGroup.defaultDividerInset + 0.5);
    });

    testWidgets('the card is a tappable surface only when given a callback', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(const AppCard(child: Text('Static'))),
      );
      expect(find.byType(Pressable), findsNothing);
      int taps = 0;
      await tester.pumpWidget(
        harness(AppCard(onPressed: () => taps++, child: const Text('Tap'))),
      );
      await tester.tap(find.text('Tap'));
      expect(taps, 1);
    });

    testWidgets('the card tile shows label, value and chevron', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          AppCard.tile(
            icon: AppIcons.language,
            label: 'Language',
            value: 'English',
            showChevron: true,
            onPressed: () {},
          ),
        ),
      );
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.byType(HugeIcon), findsNWidgets(2));
    });

    testWidgets('the card uses a hairline border and the card radius', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(const AppCard(child: Text('Hello'))),
      );
      final BoxDecoration decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(AppCard),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.borderRadius, AppRadii.cardRadius);
      expect(decoration.color, AppColors.light.bgSecondary);
      expect((decoration.border! as Border).top.width, AppSizes.hairline);
    });
  });

  group('AppChip', () {
    testWidgets('a success chip shows a check icon', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(const AppChip(label: 'Connected', tone: AppChipTone.success)),
      );
      expect(find.byType(HugeIcon), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('a neutral chip has no icon unless given one', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(const AppChip(label: 'Standard')));
      expect(find.byType(HugeIcon), findsNothing);
      await tester.pumpWidget(
        harness(const AppChip(label: 'Standard', icon: AppIcons.folder)),
      );
      expect(find.byType(HugeIcon), findsOneWidget);
    });

    testWidgets('a tappable chip still has a 48 px hit area', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        harness(
          Align(
            alignment: AlignmentDirectional.topStart,
            child: AppChip(label: 'Std', onPressed: () => taps++),
          ),
        ),
      );
      final Size size = tester.getSize(find.byType(Pressable));
      expect(size.height, greaterThanOrEqualTo(AppSizes.touchTarget));
      expect(size.width, greaterThanOrEqualTo(AppSizes.touchTarget));
      await tester.tap(find.text('Std'));
      expect(taps, 1);
    });

    testWidgets('a non-tappable chip is not a button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(const AppChip(label: 'Info')));
      expect(find.byType(Pressable), findsNothing);
    });
  });

  group('SectionHeader', () {
    testWidgets('uppercases the label and is announced as a header', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(harness(const SectionHeader('Appearance')));
      expect(find.text('APPEARANCE'), findsOneWidget);
      final SemanticsData data = tester
          .getSemantics(find.bySemanticsLabel('APPEARANCE'))
          .getSemanticsData();
      expect(data.hasFlag(SemanticsFlag.isHeader), isTrue);
      handle.dispose();
    });

    testWidgets('uses the tertiary colour', (WidgetTester tester) async {
      await tester.pumpWidget(harness(const SectionHeader('About')));
      expect(
        tester.widget<Text>(find.text('ABOUT')).style?.color,
        AppColors.light.textTertiary,
      );
    });
  });

  group('NavIconButton', () {
    testWidgets('is a 40 px chip with a 48 px hit area and a label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      int taps = 0;
      await tester.pumpWidget(
        harness(
          Align(
            alignment: AlignmentDirectional.topStart,
            child: NavIconButton(
              icon: AppIcons.settings,
              semanticLabel: 'Settings',
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      final Size hit = tester.getSize(find.byType(Pressable));
      expect(hit.width, greaterThanOrEqualTo(AppSizes.touchTarget));
      expect(hit.height, greaterThanOrEqualTo(AppSizes.touchTarget));
      final Size chip = tester.getSize(
        find.descendant(
          of: find.byType(NavIconButton),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(chip, const Size(AppSizes.iconChip, AppSizes.iconChip));
      expect(find.bySemanticsLabel('Settings'), findsOneWidget);
      await tester.tap(find.byType(NavIconButton));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('shows a badge dot only when asked', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          NavIconButton(
            icon: AppIcons.saved,
            semanticLabel: 'Saved',
            onPressed: () {},
          ),
        ),
      );
      expect(find.byType(PositionedDirectional), findsNothing);
      await tester.pumpWidget(
        harness(
          NavIconButton(
            icon: AppIcons.saved,
            semanticLabel: 'Saved',
            badge: true,
            onPressed: () {},
          ),
        ),
      );
      expect(find.byType(PositionedDirectional), findsOneWidget);
    });
  });

  group('AppLoadingIndicator', () {
    testWidgets('is a tinted Cupertino indicator with a semantics label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(harness(const AppLoadingIndicator()));
      final CupertinoActivityIndicator indicator = tester
          .widget<CupertinoActivityIndicator>(
            find.byType(CupertinoActivityIndicator),
          );
      expect(indicator.color, AppColors.light.textSecondary);
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('SegmentedTabs', () {
    Widget build({
      required int value,
      required ValueChanged<int> onChanged,
      bool dark = false,
      TextDirection direction = TextDirection.ltr,
      bool disableAnimations = false,
    }) {
      return harness(
        SegmentedTabs<int>(
          segments: const <SegmentItem<int>>[
            SegmentItem<int>(value: 0, label: 'Photos', count: 12),
            SegmentItem<int>(value: 1, label: 'Videos', count: 3),
            SegmentItem<int>(value: 2, label: 'Other'),
          ],
          value: value,
          onChanged: onChanged,
          semanticLabel: 'Media type',
        ),
        dark: dark,
        direction: direction,
        disableAnimations: disableAnimations,
      );
    }

    AlignmentGeometry indicatorAlignment(WidgetTester tester) =>
        tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).alignment;

    testWidgets('fires onChanged with the tapped segment', (
      WidgetTester tester,
    ) async {
      final List<int> changes = <int>[];
      await tester.pumpWidget(build(value: 0, onChanged: changes.add));
      await tester.tap(find.text('Videos'));
      await tester.tap(find.text('Other'));
      expect(changes, <int>[1, 2]);
    });

    testWidgets('reflects the value with the indicator position', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(build(value: 0, onChanged: (int _) {}));
      expect(indicatorAlignment(tester), const AlignmentDirectional(-1, 0));
      await tester.pumpWidget(build(value: 1, onChanged: (int _) {}));
      await tester.pumpAndSettle();
      expect(indicatorAlignment(tester), const AlignmentDirectional(0, 0));
      await tester.pumpWidget(build(value: 2, onChanged: (int _) {}));
      await tester.pumpAndSettle();
      expect(indicatorAlignment(tester), const AlignmentDirectional(1, 0));
    });

    testWidgets('the indicator slides over 200 ms, instantly with reduce motion', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(build(value: 0, onChanged: (int _) {}));
      expect(
        tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).duration,
        const Duration(milliseconds: 200),
      );
      await tester.pumpWidget(
        build(value: 0, onChanged: (int _) {}, disableAnimations: true),
      );
      expect(
        tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).duration,
        Duration.zero,
      );
    });

    testWidgets('shows counts in tabular figures, formatted per locale', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(build(value: 0, onChanged: (int _) {}));
      expect(find.text('12'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      final Text count = tester.widget<Text>(find.text('12'));
      expect(count.style?.fontFeatures, isNotNull);
    });

    testWidgets('each segment announces its selected state and count', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(build(value: 0, onChanged: (int _) {}));
      final SemanticsData photos = tester
          .getSemantics(find.bySemanticsLabel('Photos, 12 items'))
          .getSemanticsData();
      expect(photos.hasFlag(SemanticsFlag.isSelected), isTrue);
      final SemanticsData videos = tester
          .getSemantics(find.bySemanticsLabel('Videos, 3 items'))
          .getSemanticsData();
      expect(videos.hasFlag(SemanticsFlag.isSelected), isFalse);
      expect(videos.hasFlag(SemanticsFlag.isButton), isTrue);
      handle.dispose();
    });

    testWidgets('the whole control is at least 48 tall', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(build(value: 0, onChanged: (int _) {}));
      expect(
        tester.getSize(find.byType(SegmentedTabs<int>)).height,
        greaterThanOrEqualTo(AppSizes.touchTarget),
      );
    });

    testWidgets('mirrors in right-to-left', (WidgetTester tester) async {
      await tester.pumpWidget(build(value: 0, onChanged: (int _) {}));
      final double ltrPhotos = tester.getCenter(find.text('Photos')).dx;
      final double ltrOther = tester.getCenter(find.text('Other')).dx;
      expect(ltrPhotos, lessThan(ltrOther));
      await tester.pumpWidget(
        build(
          value: 0,
          onChanged: (int _) {},
          direction: TextDirection.rtl,
        ),
      );
      final double rtlPhotos = tester.getCenter(find.text('Photos')).dx;
      final double rtlOther = tester.getCenter(find.text('Other')).dx;
      expect(rtlPhotos, greaterThan(rtlOther));
    });

    testWidgets('an unknown value falls back to the first segment', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(build(value: 99, onChanged: (int _) {}));
      expect(indicatorAlignment(tester), const AlignmentDirectional(-1, 0));
    });
  });
}
