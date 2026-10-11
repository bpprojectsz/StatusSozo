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

  Future<void> pumpAccess(
    WidgetTester tester, {
    AccessMode mode = AccessMode.first,
    StatusSource? source,
    TextDirection direction = TextDirection.ltr,
    double scale = 1,
  }) async {
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
          "Pick the folder where your statuses are stored so StatusSozo can show the ones you've already viewed.",
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
        find.text('That isn\'t the status folder. Choose the folder named .Statuses.'),
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
      await pumpAccess(tester);
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
      await pumpAccess(tester, mode: AccessMode.renewal);
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
