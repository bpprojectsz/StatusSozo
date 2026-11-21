import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/folder_grant.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/providers/folder_access_provider.dart';
import 'package:statussozo/core/providers/toast_provider.dart';
import 'package:statussozo/core/result.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/screens/access_screen.dart';
import 'package:statussozo/screens/error_fallback_screen.dart';
import 'package:statussozo/widgets/primitives/loading_indicator.dart';
import 'package:statussozo/widgets/primitives/nav_icon_button.dart';
import 'package:statussozo/widgets/primitives/primary_button.dart';
import 'package:statussozo/widgets/primitives/secondary_button.dart';

import '../widgets/harness.dart';
import 'screen_harness.dart';

void main() {
  late Rig rig;
  void testScreen(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => screenTest(description, () => rig, body);
  setUp(() => rig = Rig());
  tearDown(() => rig.dispose());

  /// Only the standard app installed, which is the original single-source
  /// first run. Pass `null` for "unknown" and a set for any other case.
  const Set<StatusSource> standardOnly = <StatusSource>{StatusSource.standard};

  Future<void> pumpAccess(
    WidgetTester tester, {
    AccessMode mode = AccessMode.first,
    StatusSource? source,
    TextDirection direction = TextDirection.ltr,
    double scale = 1,
    Set<StatusSource>? installed = standardOnly,
  }) async {
    rig.status.installed = installed;
    await rig.run(tester, rig.services.folderAccess.verifyAll);
    useSurface(tester);
    await tester.pumpWidget(
      screenApp(
        rig,
        AccessScreen(mode: mode, source: source),
        direction: direction,
        textScale: scale,
      ),
    );
    await tester.pump();
  }

  group('copy', () {
    testScreen('first run', (WidgetTester tester) async {
      await pumpAccess(tester);
      expect(find.text('Connect your status folder'), findsOneWidget);
      expect(
        find.text(
          "Pick your status folder so StatusSozo can show your statuses.",
        ),
        findsOneWidget,
      );
      expect(find.text('Tap Choose folder.'), findsOneWidget);
      expect(find.text('Tap Use this folder, then Allow.'), findsOneWidget);
      expect(
        find.text(
          'Only the folder you pick is read. Chats and contacts are never accessed.',
        ),
        findsOneWidget,
      );
      expect(find.text('Choose folder'), findsOneWidget);
    });

    testScreen('renewal', (WidgetTester tester) async {
      await pumpAccess(tester, mode: AccessMode.renewal);
      expect(find.text('Access needs to be renewed'), findsOneWidget);
      expect(find.text('Connect your status folder'), findsNothing);
    });

    testScreen('reconnect has a back chip and its own title', (
      WidgetTester tester,
    ) async {
      await pumpAccess(tester, mode: AccessMode.reconnect);
      expect(find.text('Choose the folder again'), findsOneWidget);
      expect(find.byType(NavIconButton), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byType(SecondaryButton), findsNothing);
    });

    testScreen('never shows the wordmark', (WidgetTester tester) async {
      await pumpAccess(tester);
      expect(find.text('StatusSozo'), findsNothing);
    });

    testScreen('shows the numbered steps', (WidgetTester tester) async {
      await pumpAccess(tester);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('choose folder', () {
    testScreen('calls the provider and toasts success', (
      WidgetTester tester,
    ) async {
      await pumpAccess(tester);
      await tester.tap(find.text('Choose folder'));
      await tester.pump();
      await tester.pump();
      expect(rig.status.pickCalls, 1);
      expect(
        rig.services.folderAccess.value.statusOf(StatusSource.standard),
        AccessStatus.connected,
      );
      expect(rig.services.toasts.value?.code, ToastCode.folderConnected);
    });

    testScreen('a wrong folder shows the wrong-folder toast', (
      WidgetTester tester,
    ) async {
      rig.status.pickResult = const Err<FolderGrant>(
        AppError(AppErrorKind.wrongFolder),
      );
      await pumpAccess(tester);
      await tester.tap(find.text('Choose folder'));
      await tester.pump();
      await tester.pump();
      expect(rig.services.toasts.value?.code, ToastCode.wrongFolder);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('That isn\'t the status folder. Choose .Statuses, or the folder that contains it.'),
        findsOneWidget,
      );
    });

    testScreen('a cancelled picker shows an info toast', (
      WidgetTester tester,
    ) async {
      rig.status.pickResult = const Err<FolderGrant>(
        AppError(AppErrorKind.pickerCancelled),
      );
      await pumpAccess(tester);
      await tester.tap(find.text('Choose folder'));
      await tester.pump();
      await tester.pump();
      expect(rig.services.toasts.value?.code, ToastCode.pickerCancelled);
      expect(rig.services.toasts.value?.kind, ToastKind.info);
    });

    testScreen('other failures map to a matching toast', (
      WidgetTester tester,
    ) async {
      rig.status.pickResult = const Err<FolderGrant>(AppError(AppErrorKind.io));
      await pumpAccess(tester);
      await tester.tap(find.text('Choose folder'));
      await tester.pump();
      await tester.pump();
      expect(rig.services.toasts.value?.code, ToastCode.ioError);
    });

    testScreen('shows a spinner while the picker is open', (
      WidgetTester tester,
    ) async {
      rig.status.delay = const Duration(milliseconds: 500);
      await pumpAccess(tester);
      await tester.tap(find.text('Choose folder'));
      await tester.pump();
      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(find.byType(AppLoadingIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 4));
    });

    testScreen('reconnect mode closes itself after success', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      await tester.pumpWidget(
        screenApp(
          rig,
          Builder(
            builder: (BuildContext context) => PrimaryButton(
              label: 'Open',
              onPressed: () => Navigator.of(context).push(
                AppPageRoute<void>(
                  builder: (_) => const AccessScreen(mode: AccessMode.reconnect),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the folder again'), findsOneWidget);
      await tester.tap(find.text('Choose folder'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the folder again'), findsNothing);
      expect(rig.services.toasts.value?.code, ToastCode.folderConnected);
    });
  });

  group('switching source', () {
    testScreen('offers the other source and retargets the picker', (
      WidgetTester tester,
    ) async {
      await pumpAccess(tester, mode: AccessMode.renewal, installed: null);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Use Business instead'), findsOneWidget);

      await tester.tap(find.text('Use Business instead'));
      await tester.pump();
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('Use Standard instead'), findsOneWidget);

      await tester.tap(find.text('Choose folder'));
      await tester.pump();
      await tester.pump();
      expect(
        rig.services.folderAccess.value.statusOf(StatusSource.business),
        AccessStatus.connected,
      );
      expect(rig.services.source.value, StatusSource.business);
    });

    testScreen('when the other source works, selecting it leaves this screen', (
      WidgetTester tester,
    ) async {
      await rig.run(tester, () => rig.services.folderAccess.connect(StatusSource.business));
      await rig.run(tester, () => rig.services.source.select(StatusSource.standard));
      await pumpAccess(tester, mode: AccessMode.renewal, installed: null);
      await tester.tap(find.text('Use Business instead'));
      await tester.pump();
      expect(rig.services.source.value, StatusSource.business);
    });

    testScreen('reconnect mode has no source switch', (
      WidgetTester tester,
    ) async {
      await pumpAccess(
        tester,
        mode: AccessMode.reconnect,
        source: StatusSource.business,
      );
      expect(find.byType(SecondaryButton), findsNothing);
      expect(find.text('Business'), findsOneWidget);
    });
  });

  group('first run with both apps installed', () {
    Future<void> pumpBoth(WidgetTester tester) =>
        pumpAccess(tester, installed: StatusSource.values.toSet());

    testScreen('shows one row per app, not connected, and no switch button', (
      WidgetTester tester,
    ) async {
      await pumpBoth(tester);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('Not connected'), findsNWidgets(2));
      expect(find.text('Use Business instead'), findsNothing);
      expect(find.byType(SecondaryButton), findsNothing);
    });

    testScreen('Choose folder connects Standard and then Business', (
      WidgetTester tester,
    ) async {
      await pumpBoth(tester);
      await tester.tap(find.text('Choose folder'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(rig.status.pickCalls, 2);
      for (final StatusSource s in StatusSource.values) {
        expect(
          rig.services.folderAccess.value.statusOf(s),
          AccessStatus.connected,
        );
      }
      expect(rig.services.folderAccess.value.holdSetup, isFalse);
      expect(rig.services.toasts.value?.code, ToastCode.folderConnected);
    });

    testScreen('tapping the Business row connects Business first, then Standard', (
      WidgetTester tester,
    ) async {
      final List<StatusSource> picked = <StatusSource>[];
      rig.services.folderAccess.addListener(() {
        final StatusSource? c = rig.services.folderAccess.value.connecting;
        if (c != null && (picked.isEmpty || picked.last != c)) {
          picked.add(c);
        }
      });
      await pumpBoth(tester);
      await tester.tap(find.text('Business'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(picked, <StatusSource>[
        StatusSource.business,
        StatusSource.standard,
      ]);
    });

    testScreen('cancelling the second picker keeps the first and shows no message', (
      WidgetTester tester,
    ) async {
      rig.status.pickQueue.add(
        Ok<FolderGrant>(
          FolderGrant(
            source: StatusSource.standard,
            treeUri: 'content://tree/standard',
            grantedAtMs: 1,
          ),
        ),
      );
      rig.status.pickQueue.add(
        const Err<FolderGrant>(AppError(AppErrorKind.pickerCancelled)),
      );
      await pumpBoth(tester);
      await tester.tap(find.text('Choose folder'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(rig.status.pickCalls, 2);
      expect(
        rig.services.folderAccess.value.statusOf(StatusSource.standard),
        AccessStatus.connected,
      );
      expect(
        rig.services.folderAccess.value.statusOf(StatusSource.business),
        AccessStatus.notConnected,
      );
      expect(rig.services.toasts.value?.code, isNot(ToastCode.pickerCancelled));
      expect(rig.services.folderAccess.value.holdSetup, isFalse);
    });

    testScreen('cancelling the first picker connects nothing and says so', (
      WidgetTester tester,
    ) async {
      rig.status.pickResult = const Err<FolderGrant>(
        AppError(AppErrorKind.pickerCancelled),
      );
      await pumpBoth(tester);
      await tester.tap(find.text('Choose folder'));
      await tester.pump();
      await tester.pump();
      expect(rig.status.pickCalls, 1);
      expect(rig.services.toasts.value?.code, ToastCode.pickerCancelled);
    });

    testScreen('a source that is already connected is not asked again', (
      WidgetTester tester,
    ) async {
      await rig.run(
        tester,
        () => rig.services.folderAccess.connect(StatusSource.standard),
      );
      rig.status.pickCalls = 0;
      await pumpBoth(tester);
      expect(find.text('Connected'), findsOneWidget);
      await tester.tap(find.text('Choose folder'));
      await tester.pump();
      await tester.pump();
      expect(rig.status.pickCalls, 1);
    });

    testScreen('only one app installed: no rows, one picker', (
      WidgetTester tester,
    ) async {
      await pumpAccess(tester);
      expect(find.text('Not connected'), findsNothing);
      expect(find.text('Use Business instead'), findsNothing);
      await tester.tap(find.text('Choose folder'));
      await tester.pump();
      await tester.pump();
      expect(rig.status.pickCalls, 1);
    });

    testScreen('when the installed apps cannot be read, both are offered', (
      WidgetTester tester,
    ) async {
      await pumpAccess(tester, installed: null);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);
    });

    for (final TextDirection direction in TextDirection.values) {
      testScreen('renders the rows in ${direction.name} at double text', (
        WidgetTester tester,
      ) async {
        await pumpAccess(
          tester,
          direction: direction,
          scale: 2,
          installed: StatusSource.values.toSet(),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('layout', () {
    testScreen('does not scroll at normal text size', (
      WidgetTester tester,
    ) async {
      // The test font is much wider than the real one, so use a tall surface.
      useSurface(tester, width: 400, height: 2600);
      await tester.pumpWidget(screenApp(rig, const AccessScreen()));
      await tester.pump();
      final ScrollableState scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.maxScrollExtent, 0);
    });

    testScreen('the Choose folder button stays pinned when text is huge', (
      WidgetTester tester,
    ) async {
      useSurface(tester, width: 360, height: 640);
      await tester.pumpWidget(
        screenApp(rig, const AccessScreen(), textScale: 2),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final ScrollableState scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      final Rect button = tester.getRect(find.byType(PrimaryButton));
      expect(button.bottom, lessThanOrEqualTo(640));
    });

    for (final TextDirection direction in TextDirection.values) {
      testScreen('renders in ${direction.name} without overflow', (
        WidgetTester tester,
      ) async {
        await pumpAccess(tester, direction: direction);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ErrorFallbackScreen', () {
    testScreen('renders its English strings with no app around it', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      int retries = 0;
      int reports = 0;
      await tester.pumpWidget(
        ErrorFallbackScreen(onRetry: () => retries++, onReport: () => reports++),
      );
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.text('The app ran into a problem. You can try again or report it.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Try again'));
      await tester.tap(find.text('Report a problem'));
      expect(retries, 1);
      expect(reports, 1);
      expect(tester.takeException(), isNull);
    });

    testScreen('uses the light colours when there is no theme', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      await tester.pumpWidget(
        ErrorFallbackScreen(onRetry: () {}, onReport: () {}),
      );
      final ColoredBox background = tester.widget<ColoredBox>(
        find.byType(ColoredBox).first,
      );
      expect(background.color, AppColors.light.bgPrimary);
    });

    testScreen('is localised when a localisation exists', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      await tester.pumpWidget(
        screenApp(
          rig,
          ErrorFallbackScreen(onRetry: () {}, onReport: () {}),
        ),
      );
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
