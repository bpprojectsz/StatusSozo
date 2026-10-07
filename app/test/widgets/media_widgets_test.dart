import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:statussozo/core/contracts/thumbnail_source.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/models/viewable_media.dart';
import 'package:statussozo/core/result.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/media/media_grid.dart';
import 'package:statussozo/widgets/media/media_thumbnail.dart';
import 'package:statussozo/widgets/media/selection_bar.dart';
import 'package:statussozo/widgets/media/status_tile.dart';
import 'package:statussozo/widgets/primitives/nav_icon_button.dart';

import '../fakes/fakes.dart';
import 'harness.dart';

class _ThrowingSource implements ThumbnailSource {
  @override
  Future<Uint8List?> thumbnail(ViewableMedia media, int px) =>
      Future<Uint8List?>.error(StateError('decoder exploded'));

  @override
  Future<Result<Uint8List>> readImage(ViewableMedia media) =>
      throw UnimplementedError();
}

Widget _sized(Widget child) => Align(
  alignment: AlignmentDirectional.topStart,
  child: SizedBox(width: 120, height: 120, child: child),
);

void main() {
  late FakeThumbnailSource source;
  setUp(() => source = FakeThumbnailSource());

  group('MediaThumbnail', () {
    testWidgets('shows a flat fill while waiting, then the image', (
      WidgetTester tester,
    ) async {
      final Completer<void> gate = Completer<void>();
      source.gate = gate;
      await tester.pumpWidget(
        harness(_sized(MediaThumbnail(media: statusItem('a.jpg'), source: source))),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byType(HugeIcon), findsNothing);
      final ColoredBox fill = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(MediaThumbnail),
          matching: find.byType(ColoredBox),
        ).first,
      );
      expect(fill.color, AppColors.light.bgTertiary);

      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('the image covers the tile and keeps the old frame', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(_sized(MediaThumbnail(media: statusItem('a.jpg'), source: source))),
      );
      await tester.pump();
      final Image image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      expect(image.gaplessPlayback, isTrue);
      expect(image.excludeFromSemantics, isTrue);
    });

    testWidgets('asks the source for the media at the thumbnail size, once', (
      WidgetTester tester,
    ) async {
      final StatusItem item = statusItem('a.jpg');
      await tester.pumpWidget(
        harness(_sized(MediaThumbnail(media: item, source: source))),
      );
      await tester.pump();
      await tester.pumpWidget(
        harness(_sized(MediaThumbnail(media: item, source: source))),
      );
      await tester.pump();
      expect(source.thumbnailCalls, 1);
    });

    testWidgets('a different item asks again', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(_sized(MediaThumbnail(media: statusItem('a.jpg'), source: source))),
      );
      await tester.pump();
      await tester.pumpWidget(
        harness(_sized(MediaThumbnail(media: statusItem('b.jpg'), source: source))),
      );
      await tester.pump();
      expect(source.thumbnailCalls, 2);
    });

    testWidgets('an undecodable image shows an icon on the same fill', (
      WidgetTester tester,
    ) async {
      final StatusItem item = statusItem('a.jpg');
      source.thumbnailsByUri[item.uri] = null;
      await tester.pumpWidget(
        harness(_sized(MediaThumbnail(media: item, source: source))),
      );
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(find.byType(HugeIcon), findsOneWidget);
      expect(
        tester.widget<HugeIcon>(find.byType(HugeIcon)).icon,
        AppIcons.image,
      );
    });

    testWidgets('an undecodable video shows the video icon', (
      WidgetTester tester,
    ) async {
      final StatusItem item = statusItem('a.mp4', mime: 'video/mp4');
      source.thumbnailsByUri[item.uri] = null;
      await tester.pumpWidget(
        harness(_sized(MediaThumbnail(media: item, source: source))),
      );
      await tester.pump();
      expect(
        tester.widget<HugeIcon>(find.byType(HugeIcon)).icon,
        AppIcons.video,
      );
    });

    testWidgets('a source that throws falls back to the icon', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          _sized(
            MediaThumbnail(media: statusItem('a.jpg'), source: _ThrowingSource()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(HugeIcon), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('StatusTile', () {
    Widget tile({
      StatusItem? media,
      bool selected = false,
      bool selectionMode = false,
      bool saved = false,
      VoidCallback? onTap,
      VoidCallback? onLongPress,
      TextDirection direction = TextDirection.ltr,
    }) {
      return harness(
        _sized(
          StatusTile(
            media: media ?? statusItem('a.jpg'),
            source: source,
            selected: selected,
            selectionMode: selectionMode,
            saved: saved,
            onTap: onTap,
            onLongPress: onLongPress,
          ),
        ),
        direction: direction,
      );
    }

    testWidgets('is square', (WidgetTester tester) async {
      await tester.pumpWidget(tile());
      final Size size = tester.getSize(find.byType(AspectRatio));
      expect(size.width, size.height);
    });

    testWidgets('semantics label combines kind, saved and selected', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final StatusItem video = statusItem('v.mp4', mime: 'video/mp4');
      final Map<String, Widget> cases = <String, Widget>{
        'Photo': tile(),
        'Photo, saved': tile(saved: true),
        'Photo, selected': tile(selected: true, selectionMode: true),
        'Photo, saved, selected': tile(
          saved: true,
          selected: true,
          selectionMode: true,
        ),
        'Video': tile(media: video),
        'Video, saved': tile(media: video, saved: true),
        'Video, selected': tile(media: video, selected: true),
        'Video, saved, selected': tile(
          media: video,
          saved: true,
          selected: true,
        ),
      };
      for (final MapEntry<String, Widget> entry in cases.entries) {
        await tester.pumpWidget(entry.value);
        expect(
          find.bySemanticsLabel(entry.key),
          findsOneWidget,
          reason: entry.key,
        );
      }
      handle.dispose();
    });

    testWidgets('a plain photo has no badges and no marks', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(tile());
      await tester.pump();
      expect(find.byType(HugeIcon), findsNothing);
    });

    testWidgets('a video shows a play badge', (WidgetTester tester) async {
      await tester.pumpWidget(
        tile(media: statusItem('v.mp4', mime: 'video/mp4')),
      );
      await tester.pump();
      expect(find.byType(HugeIcon), findsOneWidget);
      expect(tester.widget<HugeIcon>(find.byType(HugeIcon)).icon, AppIcons.play);
    });

    testWidgets('a saved item shows a check badge on a success chip', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(tile(saved: true));
      await tester.pump();
      expect(tester.widget<HugeIcon>(find.byType(HugeIcon)).icon, AppIcons.check);
      final bool hasSuccessChip = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .any(
            (DecoratedBox d) =>
                d.decoration is BoxDecoration &&
                (d.decoration as BoxDecoration).color ==
                    AppColors.light.success,
          );
      expect(hasSuccessChip, isTrue);
    });

    testWidgets('selection mode shows an empty ring until selected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(tile(selectionMode: true));
      await tester.pump();
      expect(find.byType(HugeIcon), findsNothing);
      final Size ring = tester.getSize(
        find.byWidgetPredicate(
          (Widget w) =>
              w is SizedBox &&
              w.width == AppSizes.selectionBadge &&
              w.height == AppSizes.selectionBadge,
        ),
      );
      expect(ring, const Size(AppSizes.selectionBadge, AppSizes.selectionBadge));
    });

    testWidgets('a selected tile gets a check, an accent ring and a wash', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(tile(selected: true, selectionMode: true));
      await tester.pump();
      expect(tester.widget<HugeIcon>(find.byType(HugeIcon)).icon, AppIcons.check);
      final BoxDecoration ring = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((DecoratedBox d) => d.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((BoxDecoration d) => d.border != null && d.shape == BoxShape.rectangle);
      expect((ring.border! as Border).top.color, AppColors.light.accent);
      expect((ring.border! as Border).top.width, AppSizes.selectionRing);
      final bool hasWash = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .any((ColoredBox c) => c.color.a > 0 && c.color.a < 1);
      expect(hasWash, isTrue);
    });

    testWidgets('an unselected tile has no ring', (WidgetTester tester) async {
      await tester.pumpWidget(tile(selectionMode: true));
      final bool anyAccentRing = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((DecoratedBox d) => d.decoration)
          .whereType<BoxDecoration>()
          .any(
            (BoxDecoration d) =>
                d.border is Border &&
                (d.border! as Border).top.color == AppColors.light.accent &&
                d.shape == BoxShape.rectangle,
          );
      expect(anyAccentRing, isFalse);
    });

    testWidgets('badges sit on the correct edges and mirror in RTL', (
      WidgetTester tester,
    ) async {
      final StatusItem video = statusItem('v.mp4', mime: 'video/mp4');
      await tester.pumpWidget(tile(media: video, saved: true));
      await tester.pump();
      final Rect tileRect = tester.getRect(find.byType(AspectRatio));
      final List<HugeIcon> icons = tester
          .widgetList<HugeIcon>(find.byType(HugeIcon))
          .toList();
      expect(icons, hasLength(2));
      final Offset play = tester.getCenter(
        find.byWidgetPredicate((Widget w) => w is HugeIcon && w.icon == AppIcons.play),
      );
      final Offset check = tester.getCenter(
        find.byWidgetPredicate((Widget w) => w is HugeIcon && w.icon == AppIcons.check),
      );
      expect(play.dx - tileRect.left, lessThan(tileRect.right - play.dx));
      expect(tileRect.right - check.dx, lessThan(check.dx - tileRect.left));

      await tester.pumpWidget(
        tile(media: video, saved: true, direction: TextDirection.rtl),
      );
      await tester.pump();
      final Offset playRtl = tester.getCenter(
        find.byWidgetPredicate((Widget w) => w is HugeIcon && w.icon == AppIcons.play),
      );
      expect(tileRect.right - playRtl.dx, lessThan(playRtl.dx - tileRect.left));
    });

    testWidgets('tap and long press reach their callbacks', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      int longs = 0;
      await tester.pumpWidget(
        tile(onTap: () => taps++, onLongPress: () => longs++),
      );
      await tester.tap(find.byType(StatusTile));
      expect(taps, 1);
      await tester.longPress(find.byType(StatusTile));
      expect(longs, 1);
    });
  });

  group('grid', () {
    List<StatusItem> items(int n) => <StatusItem>[
      for (int i = 0; i < n; i++) statusItem('item$i.jpg', modifiedMs: i),
    ];

    Widget grid(
      int count, {
      double width = 360,
      Set<String> selected = const <String>{},
      Set<String> saved = const <String>{},
      bool selectionMode = false,
      void Function(int)? onTap,
      Widget? footer,
    }) {
      return harness(
        SizedBox(
          height: 700,
          child: MediaGridView(
            items: items(count),
            source: source,
            selectedIds: selected,
            savedNames: saved,
            selectionMode: selectionMode,
            onTap: onTap,
            footer: footer,
          ),
        ),
        width: width,
      );
    }

    int columns(WidgetTester tester) {
      final List<Element> tiles = find.byType(StatusTile).evaluate().toList();
      final double firstTop = tester.getTopLeft(find.byType(StatusTile).first).dy;
      return tiles
          .where(
            (Element e) =>
                (tester.getTopLeft(find.byElementPredicate((Element x) => x == e)).dy -
                        firstTop)
                    .abs() <
                1,
          )
          .length;
    }

    test('the delegate uses a 140 max extent and an 8 gap', () {
      const SliverGridDelegateWithMaxCrossAxisExtent delegate =
          mediaGridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
      expect(delegate.maxCrossAxisExtent, 140);
      expect(delegate.mainAxisSpacing, 8);
      expect(delegate.crossAxisSpacing, 8);
    });

    testWidgets('three columns on a phone', (WidgetTester tester) async {
      useSurface(tester, width: 360);
      await tester.pumpWidget(grid(12));
      expect(columns(tester), 3);
    });

    testWidgets('more columns on a tablet', (WidgetTester tester) async {
      useSurface(tester, width: 800, height: 900);
      await tester.pumpWidget(grid(24, width: 800));
      expect(columns(tester), 6);
    });

    testWidgets('tiles stay square and within the gutters', (
      WidgetTester tester,
    ) async {
      useSurface(tester, width: 360);
      await tester.pumpWidget(grid(6));
      final Rect first = tester.getRect(find.byType(StatusTile).first);
      expect(first.width, closeTo(first.height, 0.01));
      expect(first.left, AppSpacing.gutter);
      expect(first.width, lessThanOrEqualTo(AppSizes.gridMaxTileExtent));
    });

    testWidgets('uses clamping physics and cheap scrolling settings', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(grid(6));
      expect(
        tester.widget<CustomScrollView>(find.byType(CustomScrollView)).physics,
        isA<ClampingScrollPhysics>(),
      );
      final SliverChildBuilderDelegate delegate =
          tester.widget<SliverGrid>(find.byType(SliverGrid)).delegate
              as SliverChildBuilderDelegate;
      expect(delegate.addAutomaticKeepAlives, isFalse);
      expect(delegate.addRepaintBoundaries, isTrue);
    });

    testWidgets('selection and saved state reach the tiles', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      useSurface(tester, width: 360);
      final List<StatusItem> all = items(3);
      await tester.pumpWidget(
        grid(
          3,
          selected: <String>{all[1].uri},
          saved: <String>{all[2].name},
          selectionMode: true,
        ),
      );
      expect(find.bySemanticsLabel('Photo'), findsOneWidget);
      expect(find.bySemanticsLabel('Photo, selected'), findsOneWidget);
      expect(find.bySemanticsLabel('Photo, saved'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('taps report the tile index', (WidgetTester tester) async {
      useSurface(tester, width: 360);
      final List<int> taps = <int>[];
      await tester.pumpWidget(grid(6, onTap: taps.add));
      await tester.tap(find.byType(StatusTile).at(1));
      await tester.tap(find.byType(StatusTile).at(4));
      expect(taps, <int>[1, 4]);
    });

    testWidgets('shows a footer under the grid', (WidgetTester tester) async {
      useSurface(tester, width: 360);
      await tester.pumpWidget(grid(3, footer: const Text('Also in your gallery')));
      expect(find.text('Also in your gallery'), findsOneWidget);
    });

    testWidgets('extra bottom padding clears the selection bar', (
      WidgetTester tester,
    ) async {
      useSurface(tester, width: 360, height: 500);
      final ScrollController controller = ScrollController();
      await tester.pumpWidget(
        harness(
          SizedBox(
            height: 400,
            child: MediaGridView(
              items: items(30),
              source: source,
              controller: controller,
            ),
          ),
        ),
      );
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      final Rect last = tester.getRect(find.byType(StatusTile).last);
      final Rect view = tester.getRect(find.byType(MediaGridView));
      expect(view.bottom - last.bottom, greaterThanOrEqualTo(MediaGridView.defaultBottomClearance - 1));
    });

    testWidgets('an empty grid renders nothing and does not fail', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(grid(0));
      expect(find.byType(StatusTile), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('SelectionBar', () {
    Widget bar({
      required bool visible,
      VoidCallback? onPrimary,
      bool dark = false,
      bool reduce = false,
    }) {
      return harness(
        SizedBox(
          height: 300,
          child: Align(
            alignment: AlignmentDirectional.bottomCenter,
            child: SelectionBar(
              visible: visible,
              primaryLabel: 'Save 3',
              onPrimary: onPrimary,
              actions: <Widget>[
                NavIconButton(
                  icon: AppIcons.share,
                  semanticLabel: 'Share',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
        dark: dark,
        disableAnimations: reduce,
      );
    }

    testWidgets('hidden: slides away, fades out and ignores touches', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(bar(visible: false, onPrimary: () => taps++));
      expect(
        tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
        const Offset(0, 1.5),
      );
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first).opacity,
        0,
      );
      await tester.tap(find.text('Save 3'), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('visible: shown, calls back, and holds its actions', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(bar(visible: true, onPrimary: () => taps++));
      expect(
        tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
        Offset.zero,
      );
      await tester.tap(find.text('Save 3'));
      expect(taps, 1);
      expect(find.byType(NavIconButton), findsOneWidget);
    });

    testWidgets('rises over 400 ms, instantly under reduce motion', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(bar(visible: true));
      expect(
        tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).duration,
        const Duration(milliseconds: 400),
      );
      await tester.pumpWidget(bar(visible: true, reduce: true));
      expect(
        tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).duration,
        Duration.zero,
      );
    });

    testWidgets('light mode uses the single shadow and no border', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(bar(visible: true));
      final BoxDecoration pill = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((DecoratedBox d) => d.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((BoxDecoration d) => d.borderRadius == AppRadii.pillRadius && d.boxShadow != null && d.boxShadow!.isNotEmpty);
      expect(pill.boxShadow, hasLength(1));
      expect(pill.border, isNull);
    });

    testWidgets('dark mode uses a hairline border and no shadow', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(bar(visible: true, dark: true));
      final BoxDecoration pill = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((DecoratedBox d) => d.decoration)
          .whereType<BoxDecoration>()
          .firstWhere(
            (BoxDecoration d) =>
                d.borderRadius == AppRadii.pillRadius && d.color == AppColors.dark.bgSecondary,
          );
      expect(pill.boxShadow, isEmpty);
      expect((pill.border! as Border).top.width, AppSizes.hairline);
    });

    testWidgets('hidden content is removed from screen readers', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(bar(visible: false));
      expect(find.bySemanticsLabel('Save 3'), findsNothing);
      await tester.pumpWidget(bar(visible: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.bySemanticsLabel('Save 3'), findsOneWidget);
      handle.dispose();
    });
  });
}
