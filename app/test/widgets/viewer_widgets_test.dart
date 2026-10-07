import 'dart:typed_data';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/contracts/video_playback.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/widgets/primitives/loading_indicator.dart';
import 'package:statussozo/widgets/primitives/pressable.dart';
import 'package:statussozo/widgets/viewer/video_controls.dart';
import 'package:statussozo/widgets/viewer/video_surface.dart';
import 'package:statussozo/widgets/viewer/viewer_overlay.dart';
import 'package:statussozo/widgets/viewer/zoomable_image.dart';

import '../fakes/fakes.dart';
import 'harness.dart';

// A valid 1x1 PNG.
final Uint8List _png = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F,
  0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Future<void> _doubleTap(WidgetTester tester, Finder finder) async {
  final Offset point = tester.getCenter(finder);
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(point);
}

double _scale(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value
    .getMaxScaleOnAxis();

void main() {
  setUp(VideoSurface.debugReset);

  group('ZoomableImage', () {
    Widget zoomable({
      ValueChanged<bool>? onZoom,
      VoidCallback? onTap,
      bool reduce = false,
    }) {
      return harness(
        SizedBox(
          width: 360,
          height: 600,
          child: ZoomableImage(bytes: _png, onZoomChanged: onZoom, onTap: onTap),
        ),
        disableAnimations: reduce,
      );
    }

    testWidgets('limits zoom to 1x through 4x', (WidgetTester tester) async {
      await tester.pumpWidget(zoomable());
      final InteractiveViewer viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(viewer.minScale, 1);
      expect(viewer.maxScale, 4);
      expect(ZoomableImage.doubleTapScale, 2.5);
    });

    testWidgets('a double tap zooms to 2.5x and a second one back to 1x', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(zoomable());
      expect(_scale(tester), closeTo(1, 0.001));

      await _doubleTap(tester, find.byType(ZoomableImage));
      await tester.pumpAndSettle();
      expect(_scale(tester), closeTo(2.5, 0.01));

      await _doubleTap(tester, find.byType(ZoomableImage));
      await tester.pumpAndSettle();
      expect(_scale(tester), closeTo(1, 0.01));
    });

    testWidgets('reports zoom changes so the pager can lock', (
      WidgetTester tester,
    ) async {
      final List<bool> changes = <bool>[];
      await tester.pumpWidget(zoomable(onZoom: changes.add));
      await _doubleTap(tester, find.byType(ZoomableImage));
      await tester.pumpAndSettle();
      await _doubleTap(tester, find.byType(ZoomableImage));
      await tester.pumpAndSettle();
      expect(changes, <bool>[true, false]);
    });

    testWidgets('panning is enabled only while zoomed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(zoomable());
      bool panEnabled() => tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .panEnabled;
      expect(panEnabled(), isFalse);
      await _doubleTap(tester, find.byType(ZoomableImage));
      await tester.pumpAndSettle();
      expect(panEnabled(), isTrue);
    });

    testWidgets('the zoom animation takes about 200 ms', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(zoomable());
      await _doubleTap(tester, find.byType(ZoomableImage));
      await tester.pump(const Duration(milliseconds: 20));
      final double early = _scale(tester);
      expect(early, lessThan(2.5));
      await tester.pump(const Duration(milliseconds: 250));
      expect(_scale(tester), closeTo(2.5, 0.01));
    });

    testWidgets('reduce motion zooms instantly', (WidgetTester tester) async {
      await tester.pumpWidget(zoomable(reduce: true));
      await _doubleTap(tester, find.byType(ZoomableImage));
      await tester.pump();
      expect(_scale(tester), closeTo(2.5, 0.01));
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('a single tap reaches onTap, a double tap does not', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(zoomable(onTap: () => taps++));
      await tester.tap(find.byType(ZoomableImage));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 1);

      await _doubleTap(tester, find.byType(ZoomableImage));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('the image fits inside the frame', (WidgetTester tester) async {
      await tester.pumpWidget(zoomable());
      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
    });

    testWidgets('disposing mid-animation is safe', (WidgetTester tester) async {
      await tester.pumpWidget(zoomable());
      await _doubleTap(tester, find.byType(ZoomableImage));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpWidget(harness(const SizedBox()));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });
  });

  group('VideoControls', () {
    Widget controls(
      VideoState state, {
      VoidCallback? onPlayPause,
      ValueChanged<Duration>? onSeek,
      VoidCallback? onReplay,
      TextDirection direction = TextDirection.ltr,
      double scale = 1,
    }) {
      return harness(
        VideoControls(
          state: state,
          onPlayPause: onPlayPause ?? () {},
          onSeek: onSeek ?? (Duration _) {},
          onReplay: onReplay ?? () {},
        ),
        direction: direction,
        textScale: scale,
      );
    }

    const VideoState half = VideoState(
      initialised: true,
      position: Duration(seconds: 5),
      duration: Duration(seconds: 10),
    );

    testWidgets('shows play, pause or replay for the state', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(controls(half));
      expect(find.bySemanticsLabel('Play'), findsOneWidget);
      await tester.pumpWidget(controls(half.copyWith(playing: true)));
      expect(find.bySemanticsLabel('Pause'), findsOneWidget);
      await tester.pumpWidget(controls(half.copyWith(ended: true)));
      expect(find.bySemanticsLabel('Replay'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the circle is 64 px and calls the matching callback', (
      WidgetTester tester,
    ) async {
      int toggles = 0;
      int replays = 0;
      await tester.pumpWidget(
        controls(half, onPlayPause: () => toggles++, onReplay: () => replays++),
      );
      final Finder circle = find.byType(Pressable).first;
      expect(
        tester.getSize(find.byWidgetPredicate((Widget w) => w is SizedBox && w.width == 64 && w.height == 64)),
        const Size(AppSizes.playCircle, AppSizes.playCircle),
      );
      await tester.tap(circle);
      expect(toggles, 1);
      expect(replays, 0);

      await tester.pumpWidget(
        controls(
          half.copyWith(ended: true),
          onPlayPause: () => toggles++,
          onReplay: () => replays++,
        ),
      );
      await tester.tap(find.byType(Pressable).first);
      expect(toggles, 1);
      expect(replays, 1);
    });

    testWidgets('shows elapsed and total time in tabular figures', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(controls(half));
      expect(find.text('0:05'), findsOneWidget);
      expect(find.text('0:10'), findsOneWidget);
      expect(tester.widget<Text>(find.text('0:05')).style?.fontFeatures, isNotNull);
      await tester.pumpWidget(
        controls(
          const VideoState(
            initialised: true,
            position: Duration(minutes: 1, seconds: 2),
            duration: Duration(hours: 1),
          ),
        ),
      );
      expect(find.text('1:02'), findsOneWidget);
      expect(find.text('1:00:00'), findsOneWidget);
    });

    Finder scrubber() => find.byWidgetPredicate(
      (Widget w) => w is GestureDetector && w.onHorizontalDragStart != null,
    );

    testWidgets('tapping the scrubber seeks to that position', (
      WidgetTester tester,
    ) async {
      final List<Duration> seeks = <Duration>[];
      await tester.pumpWidget(controls(half, onSeek: seeks.add));
      await tester.tap(scrubber());
      expect(seeks, hasLength(1));
      expect(seeks.single.inMilliseconds, closeTo(5000, 400));
    });

    testWidgets('tapping near the start and end seeks near 0 and the end', (
      WidgetTester tester,
    ) async {
      final List<Duration> seeks = <Duration>[];
      await tester.pumpWidget(controls(half, onSeek: seeks.add));
      final Rect box = tester.getRect(scrubber());
      await tester.tapAt(Offset(box.left + 1, box.center.dy));
      await tester.tapAt(Offset(box.right - 1, box.center.dy));
      expect(seeks.first.inMilliseconds, lessThan(500));
      expect(seeks.last.inMilliseconds, greaterThan(9500));
    });

    testWidgets('dragging seeks once, on release, and thickens the track', (
      WidgetTester tester,
    ) async {
      final List<Duration> seeks = <Duration>[];
      await tester.pumpWidget(controls(half, onSeek: seeks.add));
      final Finder thick = find.byWidgetPredicate(
        (Widget w) => w is SizedBox && w.height == AppSizes.scrubTrackActive,
      );
      expect(thick, findsNothing);

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(scrubber()),
      );
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(thick, findsWidgets);
      expect(seeks, isEmpty);

      await gesture.up();
      await tester.pump();
      expect(seeks, hasLength(1));
      expect(seeks.single.inMilliseconds, greaterThan(5000));
      expect(thick, findsNothing);
    });

    testWidgets('the scrubber has a 48 px touch height and a 14 px thumb', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(controls(half));
      expect(
        tester.getSize(scrubber()).height,
        greaterThanOrEqualTo(AppSizes.touchTarget),
      );
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is SizedBox && w.width == AppSizes.scrubThumb && w.height == AppSizes.scrubThumb,
        ),
        findsOneWidget,
      );
    });

    testWidgets('is a slider for screen readers with increase and decrease', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<Duration> seeks = <Duration>[];
      await tester.pumpWidget(controls(half, onSeek: seeks.add));
      final SemanticsData data = tester
          .getSemantics(find.bySemanticsLabel('Video position'))
          .getSemanticsData();
      expect(data.hasFlag(SemanticsFlag.isSlider), isTrue);
      expect(data.value, '0:05 of 0:10');
      expect(data.hasAction(SemanticsAction.increase), isTrue);
      expect(data.hasAction(SemanticsAction.decrease), isTrue);

      tester.semantics.performAction(
        find.semantics.byLabel('Video position'),
        SemanticsAction.increase,
      );
      tester.semantics.performAction(
        find.semantics.byLabel('Video position'),
        SemanticsAction.decrease,
      );
      expect(seeks, <Duration>[
        const Duration(seconds: 10),
        Duration.zero,
      ]);
      handle.dispose();
    });

    testWidgets('keeps a left-to-right time axis in right-to-left layouts', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(controls(half, direction: TextDirection.rtl));
      expect(
        tester.getCenter(find.text('0:05')).dx,
        lessThan(tester.getCenter(find.text('0:10')).dx),
      );
    });

    testWidgets('does not overflow at large text', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(controls(half, scale: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unknown duration shows zero progress without error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(controls(const VideoState(initialised: true)));
      expect(find.text('0:00'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  group('ViewerOverlay', () {
    Widget overlay({
      required bool visible,
      bool reduce = false,
      EdgeInsets padding = EdgeInsets.zero,
      VoidCallback? onTapTop,
    }) {
      return harness(
        SizedBox(
          height: 600,
          child: ViewerOverlay(
            visible: visible,
            top: GestureDetector(
              key: const ValueKey<String>('top'),
              behavior: HitTestBehavior.opaque,
              onTap: onTapTop,
              child: const SizedBox(height: 56),
            ),
            bottom: const SizedBox(key: ValueKey<String>('bottom'), height: 80),
          ),
        ),
        disableAnimations: reduce,
        padding: padding,
      );
    }

    testWidgets('shows its top and bottom content', (WidgetTester tester) async {
      await tester.pumpWidget(overlay(visible: true));
      final double top = tester.getTopLeft(find.byKey(const ValueKey<String>('top'))).dy;
      final double bottom = tester.getTopLeft(find.byKey(const ValueKey<String>('bottom'))).dy;
      expect(top, lessThan(bottom));
      expect(tester.getBottomLeft(find.byKey(const ValueKey<String>('bottom'))).dy, closeTo(600, 1));
    });

    testWidgets('fades over 200 ms and ignores touches when hidden', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(overlay(visible: false, onTapTop: () => taps++));
      final AnimatedOpacity opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );
      expect(opacity.opacity, 0);
      expect(opacity.duration, const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const ValueKey<String>('top')), warnIfMissed: false);
      expect(taps, 0);

      await tester.pumpWidget(overlay(visible: true, onTapTop: () => taps++));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // ignore: avoid_print
      print('DIAG ignoring=${tester.widget<IgnorePointer>(find.descendant(of: find.byType(ViewerOverlay), matching: find.byType(IgnorePointer)).first).ignoring} opacity=${tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first).opacity} overlays=${find.byType(ViewerOverlay).evaluate().length} ignorePointers=${find.descendant(of: find.byType(ViewerOverlay), matching: find.byType(IgnorePointer)).evaluate().length}');
      await tester.tap(find.byKey(const ValueKey<String>('top')));
      expect(taps, 1);
    });

    testWidgets('reduce motion removes the fade time', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(overlay(visible: true, reduce: true));
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first).duration,
        Duration.zero,
      );
    });

    testWidgets('the gradients run from the scrim to transparent', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(overlay(visible: true));
      final List<LinearGradient> gradients = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((DecoratedBox d) => d.decoration)
          .whereType<BoxDecoration>()
          .map((BoxDecoration d) => d.gradient)
          .whereType<LinearGradient>()
          .toList();
      expect(gradients, hasLength(2));
      for (final LinearGradient g in gradients) {
        expect(g.colors.first, AppColors.light.scrim);
        expect(g.colors.last.a, 0);
      }
    });

    testWidgets('honours the safe area at both edges', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        overlay(visible: true, padding: const EdgeInsets.only(top: 40, bottom: 30)),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey<String>('top'))).dy,
        greaterThanOrEqualTo(40),
      );
      expect(
        tester.getBottomLeft(find.byKey(const ValueKey<String>('bottom'))).dy,
        lessThanOrEqualTo(600 - 30 + 0.5),
      );
    });

    testWidgets('hidden content is removed from screen readers', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      Widget labelled(bool visible) => harness(
        SizedBox(
          height: 400,
          child: ViewerOverlay(
            visible: visible,
            top: Semantics(label: 'Top chrome', child: const SizedBox(height: 56)),
          ),
        ),
      );
      await tester.pumpWidget(labelled(false));
      expect(find.bySemanticsLabel('Top chrome'), findsNothing);
      await tester.pumpWidget(labelled(true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.bySemanticsLabel('Top chrome'), findsOneWidget);
      handle.dispose();
    });
  });

  group('VideoSurface', () {
    late FakeVideoSessionFactory factory;
    setUp(() => factory = FakeVideoSessionFactory());

    Widget surface({
      required bool active,
      String uri = 'content://video/1',
      Widget? poster,
      VoidCallback? onTap,
      VideoControlsBuilder? controls,
      Key? key,
    }) {
      return harness(
        SizedBox(
          width: 360,
          height: 400,
          child: VideoSurface(
            key: key,
            uri: uri,
            factory: factory,
            active: active,
            poster: poster,
            onTap: onTap,
            controlsBuilder: controls,
          ),
        ),
      );
    }

    const Widget poster = SizedBox(key: ValueKey<String>('poster'));

    testWidgets('an inactive surface creates no session and shows its poster', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(surface(active: false, poster: poster));
      expect(factory.created, isEmpty);
      expect(find.byKey(const ValueKey<String>('poster')), findsOneWidget);
      expect(find.byType(AppLoadingIndicator), findsNothing);
    });

    testWidgets('an active surface creates one session, shows a spinner, then plays', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(surface(active: true, poster: poster));
      expect(factory.created, hasLength(1));
      expect(factory.created.single.uri, 'content://video/1');
      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('poster')), findsOneWidget);

      await tester.pump();
      await tester.pump();
      expect(find.byType(AppLoadingIndicator), findsNothing);
      expect(find.byKey(const ValueKey<String>('poster')), findsNothing);
      expect(factory.created.single.state.value.initialised, isTrue);
      expect(factory.created.single.state.value.playing, isTrue);
    });

    testWidgets('becoming inactive disposes the session at once', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(surface(active: true, poster: poster));
      await tester.pump();
      await tester.pump();
      expect(factory.alive, 1);

      await tester.pumpWidget(surface(active: false, poster: poster));
      expect(factory.alive, 0);
      expect(factory.created.single.disposed, isTrue);
      expect(find.byKey(const ValueKey<String>('poster')), findsOneWidget);
    });

    testWidgets('becoming active again creates a fresh session', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(surface(active: true));
      await tester.pump();
      await tester.pumpWidget(surface(active: false));
      await tester.pumpWidget(surface(active: true));
      await tester.pump();
      expect(factory.created, hasLength(2));
      expect(factory.alive, 1);
    });

    testWidgets('disposing the widget disposes the session', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(surface(active: true));
      await tester.pump();
      await tester.pumpWidget(harness(const SizedBox()));
      expect(factory.alive, 0);
    });

    testWidgets('a new uri replaces the session', (WidgetTester tester) async {
      await tester.pumpWidget(surface(active: true, uri: 'content://video/1'));
      await tester.pump();
      await tester.pumpWidget(surface(active: true, uri: 'content://video/2'));
      await tester.pump();
      expect(factory.created.map((FakeVideoSession s) => s.uri), <String>[
        'content://video/1',
        'content://video/2',
      ]);
      expect(factory.alive, 1);
    });

    Widget twoPages({required bool firstActive, required bool secondActive}) {
      return harness(
        SizedBox(
          height: 800,
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 300,
                child: VideoSurface(
                  key: const ValueKey<String>('first'),
                  uri: 'content://video/first',
                  factory: factory,
                  active: firstActive,
                ),
              ),
              SizedBox(
                height: 300,
                child: VideoSurface(
                  key: const ValueKey<String>('second'),
                  uri: 'content://video/second',
                  factory: factory,
                  active: secondActive,
                ),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('never more than one session is alive when moving forward', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(twoPages(firstActive: true, secondActive: false));
      await tester.pump();
      await tester.pumpWidget(twoPages(firstActive: false, secondActive: true));
      await tester.pump();
      await tester.pumpWidget(twoPages(firstActive: true, secondActive: false));
      await tester.pump();
      expect(factory.maxAlive, 1);
      expect(factory.alive, 1);
    });

    testWidgets('never more than one when the new page builds first', (
      WidgetTester tester,
    ) async {
      Widget reversed({required bool firstActive, required bool secondActive}) {
        return harness(
          SizedBox(
            height: 800,
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 300,
                  child: VideoSurface(
                    key: const ValueKey<String>('a'),
                    uri: 'content://video/a',
                    factory: factory,
                    active: firstActive,
                  ),
                ),
                SizedBox(
                  height: 300,
                  child: VideoSurface(
                    key: const ValueKey<String>('b'),
                    uri: 'content://video/b',
                    factory: factory,
                    active: secondActive,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(reversed(firstActive: false, secondActive: true));
      await tester.pump();
      // The earlier child becomes active before the later one is deactivated.
      await tester.pumpWidget(reversed(firstActive: true, secondActive: false));
      await tester.pump();
      await tester.pump();
      expect(factory.maxAlive, 1);
      expect(factory.alive, 1);
      expect(factory.created.last.uri, 'content://video/a');
    });

    testWidgets('a failure shows a message and Retry starts a new session', (
      WidgetTester tester,
    ) async {
      factory.failInitialise = true;
      await tester.pumpWidget(surface(active: true));
      await tester.pump();
      await tester.pump();
      expect(find.text("Couldn't play this video."), findsOneWidget);
      expect(find.byType(AppLoadingIndicator), findsNothing);
      expect(factory.created, hasLength(1));

      factory.failInitialise = false;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(factory.created, hasLength(2));
      expect(factory.created.first.disposed, isTrue);
      expect(factory.alive, 1);
      expect(find.text("Couldn't play this video."), findsNothing);
      expect(factory.created.last.state.value.playing, isTrue);
    });

    testWidgets('controls are built only once the video is ready', (
      WidgetTester tester,
    ) async {
      final List<VideoState> seen = <VideoState>[];
      await tester.pumpWidget(
        surface(
          active: true,
          controls: (BuildContext context, VideoSession session, VideoState state) {
            seen.add(state);
            return const SizedBox(key: ValueKey<String>('controls'));
          },
        ),
      );
      expect(seen, isEmpty);
      expect(find.byKey(const ValueKey<String>('controls')), findsNothing);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('controls')), findsOneWidget);
      expect(seen.last.initialised, isTrue);
    });

    testWidgets('controls are not built when the video failed', (
      WidgetTester tester,
    ) async {
      factory.failInitialise = true;
      await tester.pumpWidget(
        surface(
          active: true,
          controls: (BuildContext c, VideoSession s, VideoState st) =>
              const SizedBox(key: ValueKey<String>('controls')),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('controls')), findsNothing);
    });

    testWidgets('a tap reaches onTap', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(surface(active: true, onTap: () => taps++));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byType(VideoSurface));
      expect(taps, 1);
    });
  });
}
