import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/providers/folder_access_provider.dart';
import 'package:statussozo/core/providers/toast_provider.dart';
import 'package:statussozo/screens/home_screen.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/media/selection_bar.dart';
import 'package:statussozo/widgets/media/status_tile.dart';
import 'package:statussozo/widgets/primitives/loading_indicator.dart';

import '../fakes/fakes.dart';
import '../widgets/harness.dart';
import 'screen_harness.dart';

void main() {
  late Rig rig;
  late PlatformRecorder platform;

  setUp(() {
    rig = Rig();
    platform = PlatformRecorder()..install();
  });
  tearDown(() {
    platform.uninstall();
    rig.dispose();
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    TextDirection direction = TextDirection.ltr,
    bool dark = false,
    double scale = 1,
  }) async {
    useSurface(tester);
    await tester.pumpWidget(
      screenApp(
        rig,
        const HomeScreen(),
        direction: direction,
        dark: dark,
        textScale: scale,
      ),
    );
    await tester.pump();
  }

  Future<void> primeAndPump(WidgetTester tester) async {
    await rig.prime();
    await pumpHome(tester);
  }

  int tiles() => find.byType(StatusTile).evaluate().length;

  group('loaded list', () {
    testWidgets('renders the photos from the fakes', (
      WidgetTester tester,
    ) async {
      await primeAndPump(tester);
      expect(tiles(), 3);
      expect(find.text('StatusSozo'), findsOneWidget);
    });

    testWidgets('tabs show live counts and filter the grid', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await primeAndPump(tester);
      expect(find.bySemanticsLabel('Photos, 3 items'), findsOneWidget);
      expect(find.bySemanticsLabel('Videos, 2 items'), findsOneWidget);
      await tester.tap(find.text('Videos'));
      await tester.pump();
      expect(tiles(), 2);
      await tester.tap(find.text('Photos'));
      await tester.pump();
      expect(tiles(), 3);
      handle.dispose();
    });

    testWidgets('the nav bar has Saved and Settings chips that open screens', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await primeAndPump(tester);
      await tester.tap(find.bySemanticsLabel('Saved'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing saved yet'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('APPEARANCE'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('tapping a tile opens the viewer on that item', (
      WidgetTester tester,
    ) async {
      await primeAndPump(tester);
      await tester.tap(find.byType(StatusTile).at(1));
      await tester.pumpAndSettle();
      expect(find.text('2 of 3'), findsOneWidget);
    });

    testWidgets('the source chip shows the current source', (
      WidgetTester tester,
    ) async {
      await primeAndPump(tester);
      expect(find.text('Standard'), findsOneWidget);
    });
  });

  group('selection', () {
    testWidgets('long press enters, tap toggles, close exits', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await primeAndPump(tester);
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.byType(StatusTile).at(1));
      await tester.pump();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.byType(StatusTile).at(1));
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pump();
      expect(find.text('StatusSozo'), findsOneWidget);
      expect(rig.services.homeSelection.value.active, isFalse);
      handle.dispose();
    });

    testWidgets('deselecting the last item leaves selection mode', (
      WidgetTester tester,
    ) async {
      await primeAndPump(tester);
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      await tester.tap(find.byType(StatusTile).first);
      await tester.pump();
      expect(rig.services.homeSelection.value.active, isFalse);
    });

    testWidgets('select all selects everything on the tab', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await primeAndPump(tester);
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Select all'));
      await tester.pump();
      expect(find.text('3 selected'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('each toggle gives a light haptic tick', (
      WidgetTester tester,
    ) async {
      await primeAndPump(tester);
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      await tester.tap(find.byType(StatusTile).at(1));
      await tester.pump();
      expect(rig.haptics.selectionCount, 2);
    });

    testWidgets('the back button leaves selection before leaving the screen', (
      WidgetTester tester,
    ) async {
      await primeAndPump(tester);
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      expect(rig.services.homeSelection.value.active, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(rig.services.homeSelection.value.active, isFalse);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('switching tab clears the selection', (
      WidgetTester tester,
    ) async {
      await primeAndPump(tester);
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      await tester.tap(find.text('Videos'));
      await tester.pump();
      expect(rig.services.homeSelection.value.active, isFalse);
    });

    testWidgets('the selection bar shows only in selection mode', (
      WidgetTester tester,
    ) async {
      await primeAndPump(tester);
      bool visible() => tester.widget<SelectionBar>(find.byType(SelectionBar)).visible;
      expect(visible(), isFalse);
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      expect(visible(), isTrue);
      expect(find.text('Save 1'), findsOneWidget);
    });
  });

  group('save and share', () {
    testWidgets('Save calls the provider, updates badges and toasts', (
      WidgetTester tester,
    ) async {
      await primeAndPump(tester);
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      await tester.tap(find.byType(StatusTile).at(1));
      await tester.pump();
      await tester.tap(find.text('Save 2'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(rig.saved.savedNames, <String>['p1.jpg', 'p2.jpg']);
      expect(rig.services.savedLibrary.value.names, <String>{'p1.jpg', 'p2.jpg'});
      expect(rig.services.homeSelection.value.active, isFalse);
      expect(find.text('Saved 2 items'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is HugeIcon && w.icon == AppIcons.check,
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('Share sends the selected items', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await primeAndPump(tester);
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Share'));
      await tester.pump();
      expect(rig.share.shared, hasLength(1));
      expect(rig.share.shared.single.single.name, 'p1.jpg');
      expect(rig.services.homeSelection.value.active, isTrue);
      handle.dispose();
    });

    testWidgets('a failed share shows a toast', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      rig.share.error = const AppError(AppErrorKind.io);
      await primeAndPump(tester);
      await tester.longPress(find.byType(StatusTile).first);
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Share'));
      await tester.pump();
      await tester.pump();
      expect(rig.services.toasts.value?.code, ToastCode.shareFailed);
      handle.dispose();
    });
  });

  group('states', () {
    testWidgets('loading shows a spinner', (WidgetTester tester) async {
      await rig.services.settings.load();
      await rig.prime();
      final Completer<void> gate = Completer<void>();
      rig.status.listGates[StatusSource.standard] = gate;
      await pumpHome(tester);
      unawaited(rig.services.statusList.refresh());
      await tester.pump();
      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byType(AppLoadingIndicator), findsNothing);
    });

    testWidgets('empty shows the message and Refresh reloads', (
      WidgetTester tester,
    ) async {
      await rig.prime(items: <StatusItem>[]);
      await pumpHome(tester);
      expect(find.text('No statuses yet'), findsOneWidget);
      final int before = rig.status.listCalls;
      rig.status.itemsBySource[StatusSource.standard] = <StatusItem>[
        statusItem('new.jpg'),
      ];
      await tester.tap(find.text('Refresh'));
      await tester.pump();
      await tester.pump();
      expect(rig.status.listCalls, greaterThan(before));
      expect(tiles(), 1);
    });

    testWidgets('an empty videos tab shows the empty state too', (
      WidgetTester tester,
    ) async {
      await rig.prime(items: <StatusItem>[statusItem('only.jpg')]);
      await pumpHome(tester);
      await tester.tap(find.text('Videos'));
      await tester.pump();
      expect(find.text('No statuses yet'), findsOneWidget);
    });

    testWidgets('an error shows the message and Try again reloads', (
      WidgetTester tester,
    ) async {
      await rig.prime();
      rig.status.listErrors[StatusSource.standard] = const AppError(
        AppErrorKind.io,
      );
      await rig.services.statusList.refresh();
      await pumpHome(tester);
      expect(find.text("Couldn't read the files"), findsOneWidget);
      rig.status.listErrors.clear();
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(tiles(), 3);
    });

    testWidgets('a source without a grant asks to connect', (
      WidgetTester tester,
    ) async {
      await rig.services.settings.load();
      await rig.services.bootstrap();
      await pumpHome(tester);
      expect(find.text('Connect your status folder'), findsOneWidget);
      await tester.tap(find.text('Choose folder'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the folder again'), findsOneWidget);
    });

    testWidgets('lost access shows Reconnect', (WidgetTester tester) async {
      await rig.prime();
      rig.status.lostAccess.add(StatusSource.standard);
      await rig.services.folderAccess.verifyAll();
      await pumpHome(tester);
      expect(
        rig.services.folderAccess.value.statusOf(StatusSource.standard),
        AccessStatus.needsRenewal,
      );
      expect(find.text('Access needs to be renewed'), findsOneWidget);
      await tester.tap(find.text('Reconnect'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the folder again'), findsOneWidget);
    });
  });

  group('source sheet', () {
    testWidgets('lists both sources with their connection state', (
      WidgetTester tester,
    ) async {
      await primeAndPump(tester);
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a source'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Not connected'), findsOneWidget);
    });

    testWidgets('choosing a connected source switches to it', (
      WidgetTester tester,
    ) async {
      await rig.prime(
        sources: <StatusSource>[StatusSource.standard, StatusSource.business],
      );
      await pumpHome(tester);
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Business'));
      await tester.pumpAndSettle();
      expect(rig.services.source.value, StatusSource.business);
    });

    testWidgets('choosing an unconnected source opens the connect screen', (
      WidgetTester tester,
    ) async {
      await primeAndPump(tester);
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Business'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the folder again'), findsOneWidget);
    });
  });

  group('layout', () {
    for (final bool dark in <bool>[false, true]) {
      for (final TextDirection direction in TextDirection.values) {
        testWidgets(
          '${dark ? 'dark' : 'light'} ${direction.name} at 2x text',
          (WidgetTester tester) async {
            await rig.prime();
            await pumpHome(tester, direction: direction, dark: dark, scale: 2);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('has no bottom embed in stage 1', (WidgetTester tester) async {
      await primeAndPump(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
