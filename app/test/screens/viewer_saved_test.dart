import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/models/viewable_media.dart';
import 'package:statussozo/core/providers/status_list_provider.dart';
import 'package:statussozo/core/providers/toast_provider.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/screens/saved_screen.dart';
import 'package:statussozo/screens/viewer_screen.dart';
import 'package:statussozo/widgets/media/selection_bar.dart';
import 'package:statussozo/widgets/media/status_tile.dart';
import 'package:statussozo/widgets/primitives/loading_indicator.dart';
import 'package:statussozo/widgets/primitives/primary_button.dart';
import 'package:statussozo/widgets/viewer/video_controls.dart';
import 'package:statussozo/widgets/viewer/viewer_overlay.dart';
import 'package:statussozo/widgets/viewer/video_surface.dart';
import 'package:statussozo/widgets/viewer/zoomable_image.dart';

import '../fakes/fakes.dart';
import '../widgets/harness.dart';
import 'screen_harness.dart';

Widget _launcher(Widget Function() screen) {
  return Builder(
    builder: (BuildContext context) => PrimaryButton(
      label: 'Open',
      onPressed: () => Navigator.of(context).push(
        AppPageRoute<void>(builder: (_) => screen()),
      ),
    ),
  );
}

Future<void> _doubleTap(WidgetTester tester, Finder finder) async {
  final Offset point = tester.getCenter(finder);
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(point);
}

void main() {
  late Rig rig;
  late PlatformRecorder platform;

  setUp(() {
    rig = Rig();
    platform = PlatformRecorder()..install();
    VideoSurface.debugReset();
  });
  tearDown(() {
    platform.uninstall();
    rig.dispose();
  });

  List<StatusItem> photos(int n) => <StatusItem>[
    for (int i = 0; i < n; i++) statusItem('p$i.jpg', modifiedMs: 100 - i),
  ];

  Future<void> openViewer(
    WidgetTester tester,
    List<ViewableMedia> items, {
    int index = 0,
    ViewerMode mode = ViewerMode.status,
    TextDirection direction = TextDirection.ltr,
    bool dark = false,
    bool settle = true,
  }) async {
    useSurface(tester);
    await tester.pumpWidget(
      screenApp(
        rig,
        _launcher(
          () => ViewerScreen(items: items, initialIndex: index, mode: mode),
        ),
        direction: direction,
        dark: dark,
      ),
    );
    await tester.tap(find.text('Open'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  double overlayOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find
            .descendant(
              of: find.byType(ViewerOverlay),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      )
      .opacity;

  group('ViewerScreen (status mode)', () {
    testWidgets('shows the counter and closes with the close chip', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await openViewer(tester, photos(3));
      expect(find.text('1 of 3'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Close viewer'));
      await tester.pumpAndSettle();
      expect(find.byType(ViewerScreen), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('starts at the requested index and clamps a bad one', (
      WidgetTester tester,
    ) async {
      await openViewer(tester, photos(3), index: 2);
      expect(find.text('3 of 3'), findsOneWidget);
    });

    testWidgets('an out-of-range index is clamped', (
      WidgetTester tester,
    ) async {
      await openViewer(tester, photos(3), index: 99);
      expect(find.text('3 of 3'), findsOneWidget);
    });

    testWidgets('swiping moves between items and updates the counter', (
      WidgetTester tester,
    ) async {
      await openViewer(tester, photos(3));
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('2 of 3'), findsOneWidget);
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('1 of 3'), findsOneWidget);
    });

    testWidgets('zooming locks paging until it is zoomed out', (
      WidgetTester tester,
    ) async {
      await openViewer(tester, photos(3));
      PageView pager() => tester.widget<PageView>(find.byType(PageView));
      expect(pager().physics, isA<ClampingScrollPhysics>());

      await _doubleTap(tester, find.byType(ZoomableImage).first);
      await tester.pumpAndSettle();
      expect(pager().physics, isA<NeverScrollableScrollPhysics>());

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('1 of 3'), findsOneWidget);

      await _doubleTap(tester, find.byType(ZoomableImage).first);
      await tester.pumpAndSettle();
      expect(pager().physics, isA<ClampingScrollPhysics>());
    });

    testWidgets('Save becomes a disabled Saved state', (
      WidgetTester tester,
    ) async {
      await openViewer(tester, photos(2));
      expect(find.text('Save'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(rig.saved.savedNames, <String>['p0.jpg']);
      expect(find.text('Saved'), findsWidgets);
      expect(find.text('Save'), findsNothing);

      await tester.tap(find.byType(PrimaryButton).last, warnIfMissed: false);
      await tester.pump();
      expect(rig.saved.saveCalls, 1);
    });

    testWidgets('an item that is already saved starts as Saved', (
      WidgetTester tester,
    ) async {
      rig.saved.items.add(savedItem('p0.jpg'));
      await rig.services.savedLibrary.refresh();
      await openViewer(tester, photos(2));
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('the saved state follows the page', (WidgetTester tester) async {
      rig.saved.items.add(savedItem('p1.jpg'));
      await rig.services.savedLibrary.refresh();
      await openViewer(tester, photos(2));
      expect(find.text('Save'), findsOneWidget);
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('a tap toggles the overlays', (WidgetTester tester) async {
      await openViewer(tester, photos(2));
      expect(overlayOpacity(tester), 1);
      await tester.tap(find.byType(ZoomableImage).first);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(overlayOpacity(tester), 0);
      await tester.tap(find.byType(ZoomableImage).first);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(overlayOpacity(tester), 1);
    });

    testWidgets('Share sends the current item', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await openViewer(tester, photos(2));
      await tester.tap(find.bySemanticsLabel('Share'));
      await tester.pump();
      expect(rig.share.shared.single.single.name, 'p0.jpg');
      handle.dispose();
    });

    testWidgets('a failed share shows a toast', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      rig.share.error = const AppError(AppErrorKind.io);
      await openViewer(tester, photos(2));
      await tester.tap(find.bySemanticsLabel('Share'));
      await tester.pump();
      await tester.pump();
      expect(rig.services.toasts.value?.code, ToastCode.shareFailed);
      handle.dispose();
    });

    testWidgets('prefetches the neighbouring pages', (
      WidgetTester tester,
    ) async {
      await openViewer(tester, photos(4), index: 1);
      expect(rig.thumbs.readCalls, greaterThanOrEqualTo(3));
    });

    testWidgets('an image that cannot be read shows a message and retry', (
      WidgetTester tester,
    ) async {
      rig.thumbs.readError = const AppError(AppErrorKind.io);
      await openViewer(tester, photos(1));
      expect(find.text("Couldn't open this item."), findsOneWidget);
      rig.thumbs.readError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't open this item."), findsNothing);
      expect(find.byType(ZoomableImage), findsOneWidget);
    });

    testWidgets('hides the system bars and restores them on exit', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await openViewer(tester, photos(1));
      expect(platform.uiModes, contains('SystemUiMode.immersiveSticky'));
      await tester.tap(find.bySemanticsLabel('Close viewer'));
      await tester.pumpAndSettle();
      expect(platform.uiModes.last, 'SystemUiMode.edgeToEdge');
      handle.dispose();
    });

    for (final TextDirection direction in TextDirection.values) {
      testWidgets('renders in ${direction.name} on a dark theme', (
        WidgetTester tester,
      ) async {
        await openViewer(tester, photos(2), direction: direction, dark: true);
        expect(tester.takeException(), isNull);
        expect(find.text('1 of 2'), findsOneWidget);
      });
    }
  });

  group('ViewerScreen with video', () {
    final StatusItem video = statusItem('clip.mp4', mime: 'video/mp4');

    testWidgets('plays the current video with custom controls', (
      WidgetTester tester,
    ) async {
      await openViewer(tester, <ViewableMedia>[video], settle: false);
      await tester.pump();
      await tester.pump();
      expect(rig.video.created, hasLength(1));
      expect(rig.video.alive, 1);
      expect(rig.video.created.single.state.value.playing, isTrue);
      expect(find.byType(VideoControls), findsOneWidget);

      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.tap(find.bySemanticsLabel('Pause'));
      await tester.pump();
      expect(rig.video.created.single.state.value.playing, isFalse);
      handle.dispose();
    });

    testWidgets('closing the viewer disposes the session', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await openViewer(tester, <ViewableMedia>[video], settle: false);
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Close viewer'));
      await tester.pumpAndSettle();
      expect(rig.video.alive, 0);
      handle.dispose();
    });

    testWidgets('only the current page holds a session', (
      WidgetTester tester,
    ) async {
      await openViewer(
        tester,
        <ViewableMedia>[video, statusItem('b.jpg'), statusItem('v2.mp4', mime: 'video/mp4')],
        settle: false,
      );
      await tester.pump();
      expect(rig.video.alive, 1);
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(rig.video.alive, 0);
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(rig.video.alive, 1);
      expect(rig.video.maxAlive, 1);
    });
  });

  group('ViewerScreen (saved mode)', () {
    Future<void> openSaved(
      WidgetTester tester,
      List<SavedItem> items, {
      int index = 0,
    }) async {
      rig.saved.items.addAll(items);
      await rig.services.savedLibrary.refresh();
      await openViewer(
        tester,
        rig.services.savedLibrary.value.items,
        index: index,
        mode: ViewerMode.saved,
      );
    }

    testWidgets('has a Delete action and no Save button', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await openSaved(tester, <SavedItem>[savedItem('a.jpg')]);
      expect(find.bySemanticsLabel('Delete'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      handle.dispose();
    });

    testWidgets('deleting asks first, then removes the item and moves on', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await openSaved(tester, <SavedItem>[
        savedItem('a.jpg', savedAtMs: 3),
        savedItem('b.jpg', savedAtMs: 2),
        savedItem('c.jpg', savedAtMs: 1),
      ]);
      expect(find.text('1 of 3'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete 1 item?'), findsOneWidget);
      expect(
        find.text("They'll be removed from your gallery too."),
        findsOneWidget,
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(rig.saved.deleteCalls, 1);
      expect(rig.saved.items.map((SavedItem i) => i.name), <String>['b.jpg', 'c.jpg']);
      expect(find.text('1 of 2'), findsOneWidget);
      expect(rig.services.toasts.value?.code, ToastCode.deleted);
      handle.dispose();
    });

    testWidgets('cancelling keeps the item', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await openSaved(tester, <SavedItem>[savedItem('a.jpg'), savedItem('b.jpg')]);
      await tester.tap(find.bySemanticsLabel('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(rig.saved.deleteCalls, 0);
      expect(find.text('1 of 2'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('deleting the last item closes the viewer', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await openSaved(tester, <SavedItem>[savedItem('only.jpg')]);
      await tester.tap(find.bySemanticsLabel('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(ViewerScreen), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a failed delete shows a toast and keeps the item', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final SavedItem item = savedItem('stuck.jpg');
      rig.saved.deleteErrors[item.uri] = const AppError(
        AppErrorKind.permissionLost,
      );
      await openSaved(tester, <SavedItem>[item, savedItem('other.jpg')]);
      await tester.tap(find.bySemanticsLabel('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(rig.services.toasts.value?.code, ToastCode.deleteFailed);
      expect(find.text('1 of 2'), findsOneWidget);
      handle.dispose();
    });
  });

  group('SavedScreen', () {
    Future<void> pumpSaved(
      WidgetTester tester, {
      TextDirection direction = TextDirection.ltr,
    }) async {
      useSurface(tester);
      await tester.pumpWidget(
        screenApp(
          rig,
          _launcher(SavedScreen.new),
          direction: direction,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('refreshes when opened and shows the items and footer', (
      WidgetTester tester,
    ) async {
      rig.saved.items.addAll(<SavedItem>[
        savedItem('a.jpg', savedAtMs: 2),
        savedItem('b.mp4', mime: 'video/mp4', savedAtMs: 1),
      ]);
      await pumpSaved(tester);
      expect(rig.saved.listCalls, greaterThanOrEqualTo(1));
      expect(find.text('Saved'), findsOneWidget);
      expect(find.byType(StatusTile), findsNWidgets(2));
      expect(
        find.text('Also in your gallery: Pictures/StatusSozo and Movies/StatusSozo'),
        findsOneWidget,
      );
    });

    testWidgets('shows the empty state', (WidgetTester tester) async {
      await pumpSaved(tester);
      expect(find.text('Nothing saved yet'), findsOneWidget);
      expect(find.text('Items you save will appear here.'), findsOneWidget);
    });

    testWidgets('shows a spinner while the first load runs', (
      WidgetTester tester,
    ) async {
      rig.saved.delay = const Duration(milliseconds: 500);
      useSurface(tester);
      await tester.pumpWidget(
        screenApp(rig, _launcher(SavedScreen.new)),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });

    testWidgets('shows an error with retry when the first load fails', (
      WidgetTester tester,
    ) async {
      rig.saved.listError = const AppError(AppErrorKind.io);
      await pumpSaved(tester);
      expect(find.text("Couldn't read the files"), findsOneWidget);
      rig.saved.listError = null;
      rig.saved.items.add(savedItem('late.jpg'));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(StatusTile), findsOneWidget);
    });

    testWidgets('long press selects, and Share sends the selection', (
      WidgetTester tester,
    ) async {
      rig.saved.items.addAll(<SavedItem>[
        savedItem('a.jpg', savedAtMs: 2),
        savedItem('b.jpg', savedAtMs: 1),
      ]);
      await pumpSaved(tester);
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      await tester.tap(find.byType(StatusTile).last);
      await tester.pump();
      expect(find.text('2 selected'), findsOneWidget);
      expect(
        tester.widget<SelectionBar>(find.byType(SelectionBar)).primaryLabel,
        'Share',
      );
      await tester.tap(find.text('Share'));
      await tester.pump();
      expect(rig.share.shared.single, hasLength(2));
    });

    testWidgets('Delete asks for confirmation and removes the selection', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      rig.saved.items.addAll(<SavedItem>[
        savedItem('a.jpg', savedAtMs: 3),
        savedItem('b.jpg', savedAtMs: 2),
        savedItem('c.jpg', savedAtMs: 1),
      ]);
      await pumpSaved(tester);
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      await tester.tap(find.byType(StatusTile).at(1));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete 2 items?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(rig.saved.items.map((SavedItem i) => i.name), <String>['c.jpg']);
      expect(find.byType(StatusTile), findsOneWidget);
      expect(rig.services.savedSelection.value.active, isFalse);
      expect(rig.services.toasts.value?.code, ToastCode.deleted);
      expect(rig.services.toasts.value?.count, 2);
      handle.dispose();
    });

    testWidgets('cancelling the confirmation keeps everything', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      rig.saved.items.add(savedItem('a.jpg'));
      await pumpSaved(tester);
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(rig.saved.deleteCalls, 0);
      expect(find.byType(StatusTile), findsOneWidget);
      handle.dispose();
    });

    testWidgets('tapping an item opens the viewer in saved mode', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      rig.saved.items.add(savedItem('a.jpg'));
      await pumpSaved(tester);
      await tester.tap(find.byType(StatusTile).first);
      await tester.pumpAndSettle();
      expect(find.text('1 of 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Delete'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('back leaves selection first, then the screen', (
      WidgetTester tester,
    ) async {
      rig.saved.items.add(savedItem('a.jpg'));
      await pumpSaved(tester);
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(rig.services.savedSelection.value.active, isFalse);
      expect(find.byType(SavedScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SavedScreen), findsNothing);
    });

    for (final TextDirection direction in TextDirection.values) {
      testWidgets('renders in ${direction.name} without overflow', (
        WidgetTester tester,
      ) async {
        rig.saved.items.add(savedItem('a.jpg'));
        await pumpSaved(tester, direction: direction);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('lists items newest first', (WidgetTester tester) async {
      rig.saved.items.addAll(<SavedItem>[
        savedItem('old.jpg', savedAtMs: 1),
        savedItem('new.jpg', savedAtMs: 9),
      ]);
      await pumpSaved(tester);
      expect(rig.services.savedLibrary.value.phase, ListPhase.ready);
      expect(
        rig.services.savedLibrary.value.items.map((SavedItem i) => i.name),
        <String>['new.jpg', 'old.jpg'],
      );
    });
  });
}
