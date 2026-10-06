import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/providers/toast_provider.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/widgets/feedback/empty_state.dart';
import 'package:statussozo/widgets/feedback/error_state.dart';
import 'package:statussozo/widgets/feedback/toast_host.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/layout/app_nav_bar.dart';
import 'package:statussozo/widgets/layout/screen_scaffold.dart';
import 'package:statussozo/widgets/primitives/nav_icon_button.dart';
import 'package:statussozo/widgets/primitives/primary_button.dart';
import 'package:statussozo/widgets/sheets/app_sheet.dart';

import 'harness.dart';

const Duration _threeSeconds = Duration(seconds: 3);

Widget _marker(String name) => SizedBox(key: ValueKey<String>(name), height: 20);

void main() {
  group('ScreenScaffold', () {
    testWidgets('stacks nav bar, body and bottom embed', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      await tester.pumpWidget(
        harness(
          SizedBox(
            height: 600,
            child: ScreenScaffold(
              navBar: _marker('nav'),
              body: _marker('body'),
              bottomEmbed: _marker('embed'),
            ),
          ),
        ),
      );
      final double nav = tester.getTopLeft(find.byKey(const ValueKey<String>('nav'))).dy;
      final double body = tester.getTopLeft(find.byKey(const ValueKey<String>('body'))).dy;
      final double embed = tester.getTopLeft(find.byKey(const ValueKey<String>('embed'))).dy;
      expect(nav, lessThan(body));
      expect(body, lessThan(embed));
    });

    testWidgets('removes the whole bottom embed while the keyboard is open', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      Widget build({required bool keyboard}) => harness(
        SizedBox(
          height: 600,
          child: ScreenScaffold(
            body: _marker('body'),
            bottomEmbed: _marker('embed'),
          ),
        ),
        viewInsets: keyboard ? const EdgeInsets.only(bottom: 300) : EdgeInsets.zero,
      );
      await tester.pumpWidget(build(keyboard: false));
      expect(find.byKey(const ValueKey<String>('embed')), findsOneWidget);
      await tester.pumpWidget(build(keyboard: true));
      expect(find.byKey(const ValueKey<String>('embed')), findsNothing);
      await tester.pumpWidget(build(keyboard: false));
      expect(find.byKey(const ValueKey<String>('embed')), findsOneWidget);
    });

    testWidgets('protects the safe area on both edges', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      await tester.pumpWidget(
        harness(
          SizedBox(
            height: 700,
            child: ScreenScaffold(
              navBar: _marker('nav'),
              body: _marker('body'),
              bottomEmbed: _marker('embed'),
            ),
          ),
          width: 400,
          padding: const EdgeInsets.only(top: 40, bottom: 30),
        ),
      );
      final Rect screen = tester.getRect(find.byType(ScreenScaffold));
      final Rect nav = tester.getRect(find.byKey(const ValueKey<String>('nav')));
      final Rect embed = tester.getRect(find.byKey(const ValueKey<String>('embed')));
      expect(nav.top - screen.top, greaterThanOrEqualTo(40));
      expect(screen.bottom - embed.bottom, greaterThanOrEqualTo(30));
    });

    testWidgets('floating content sits over the body, above the embed', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      await tester.pumpWidget(
        harness(
          SizedBox(
            height: 600,
            child: ScreenScaffold(
              body: _marker('body'),
              floating: _marker('floating'),
              bottomEmbed: _marker('embed'),
            ),
          ),
        ),
      );
      final Rect floating = tester.getRect(find.byKey(const ValueKey<String>('floating')));
      final Rect embed = tester.getRect(find.byKey(const ValueKey<String>('embed')));
      expect(floating.bottom, lessThanOrEqualTo(embed.top));
    });

    testWidgets('uses the primary background', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(SizedBox(height: 200, child: ScreenScaffold(body: _marker('b')))),
      );
      final ColoredBox box = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(ScreenScaffold),
          matching: find.byType(ColoredBox),
        ).first,
      );
      expect(box.color, AppColors.light.bgPrimary);
    });
  });

  group('AppNavBar', () {
    Widget action(String label) => NavIconButton(
      icon: AppIcons.settings,
      semanticLabel: label,
      onPressed: () {},
    );

    testWidgets('home shows the wordmark and puts actions on the end edge', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(AppNavBar.home(actions: <Widget>[action('Settings')])),
      );
      expect(find.text('StatusSozo'), findsOneWidget);
      final double wordmark = tester.getCenter(find.text('StatusSozo')).dx;
      final double settings = tester.getCenter(find.byType(NavIconButton)).dx;
      expect(wordmark, lessThan(settings));
    });

    testWidgets('home mirrors in right-to-left', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          AppNavBar.home(actions: <Widget>[action('Settings')]),
          direction: TextDirection.rtl,
        ),
      );
      final double wordmark = tester.getCenter(find.text('StatusSozo')).dx;
      final double settings = tester.getCenter(find.byType(NavIconButton)).dx;
      expect(wordmark, greaterThan(settings));
    });

    testWidgets('pushed shows a back chip and the title, and calls onBack', (
      WidgetTester tester,
    ) async {
      int backs = 0;
      await tester.pumpWidget(
        harness(
          AppNavBar.pushed(title: 'Saved', onBack: () => backs++),
        ),
      );
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('StatusSozo'), findsNothing);
      await tester.tap(find.byType(NavIconButton));
      expect(backs, 1);
      final double chip = tester.getCenter(find.byType(NavIconButton)).dx;
      final double title = tester.getCenter(find.text('Saved')).dx;
      expect(chip, lessThan(title));
    });

    testWidgets('pushed in right-to-left puts the back chip on the right', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          AppNavBar.pushed(title: 'Saved', onBack: () {}),
          direction: TextDirection.rtl,
        ),
      );
      final double chip = tester.getCenter(find.byType(NavIconButton)).dx;
      final double title = tester.getCenter(find.text('Saved')).dx;
      expect(chip, greaterThan(title));
    });

    testWidgets('the back chip has an accessible label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(AppNavBar.pushed(title: 'Saved', onBack: () {})),
      );
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('selection shows the count, a close chip and actions', (
      WidgetTester tester,
    ) async {
      int closes = 0;
      await tester.pumpWidget(
        harness(
          AppNavBar.selection(
            count: 3,
            onClose: () => closes++,
            actions: <Widget>[action('Select all')],
          ),
        ),
      );
      expect(find.text('3 selected'), findsOneWidget);
      expect(find.text('StatusSozo'), findsNothing);
      await tester.tap(find.byType(NavIconButton).first);
      expect(closes, 1);
    });

    testWidgets('the wordmark exists only on the home bar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          Column(
            children: <Widget>[
              AppNavBar.pushed(title: 'Settings', onBack: () {}),
              AppNavBar.selection(count: 1, onClose: () {}, actions: const <Widget>[]),
            ],
          ),
        ),
      );
      expect(find.text('StatusSozo'), findsNothing);
    });

    testWidgets('is at least 56 tall and a header for screen readers', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(AppNavBar.pushed(title: 'Saved', onBack: () {})),
      );
      expect(
        tester.getSize(find.byType(AppNavBar)).height,
        greaterThanOrEqualTo(AppSizes.navBar),
      );
      final SemanticsData data = tester
          .getSemantics(find.bySemanticsLabel('Saved'))
          .getSemanticsData();
      expect(data.hasFlag(SemanticsFlag.isHeader), isTrue);
      handle.dispose();
    });
  });

  group('EmptyState and ErrorState', () {
    testWidgets('empty state shows its text and fires the action', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        harness(
          SizedBox(
            height: 500,
            child: EmptyState(
              title: 'No statuses yet',
              message: 'Open one, then come back.',
              actionLabel: 'Refresh',
              onAction: () => taps++,
            ),
          ),
        ),
      );
      expect(find.text('No statuses yet'), findsOneWidget);
      expect(find.text('Open one, then come back.'), findsOneWidget);
      await tester.tap(find.text('Refresh'));
      expect(taps, 1);
    });

    testWidgets('empty state without an action shows no button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(const SizedBox(height: 400, child: EmptyState(title: 'Nothing'))),
      );
      expect(find.byType(PrimaryButton), findsNothing);
      expect(find.text('Nothing'), findsOneWidget);
    });

    testWidgets('empty state scrolls instead of overflowing at huge text', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      await tester.pumpWidget(
        harness(
          const SizedBox(
            height: 200,
            child: EmptyState(
              title: 'A fairly long empty state title',
              message: 'And a message that is long enough to need several lines.',
            ),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    for (final AppErrorKind kind in AppErrorKind.values) {
      testWidgets('error state renders ${kind.name} without overflow', (
        WidgetTester tester,
      ) async {
        useSurface(tester);
        await tester.pumpWidget(
          harness(
            SizedBox(
              height: 600,
              child: ErrorState(
                error: AppError(kind),
                onRetry: () {},
                onReport: () {},
              ),
            ),
            textScale: 2,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a retriable error shows its action and calls onRetry', (
      WidgetTester tester,
    ) async {
      int retries = 0;
      await tester.pumpWidget(
        harness(
          SizedBox(
            height: 500,
            child: ErrorState(
              error: const AppError(AppErrorKind.io),
              onRetry: () => retries++,
            ),
          ),
        ),
      );
      expect(find.text("Couldn't read the files"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('access lost offers Reconnect', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        harness(
          SizedBox(
            height: 500,
            child: ErrorState(
              error: const AppError(AppErrorKind.accessLost),
              onRetry: () => taps++,
            ),
          ),
        ),
      );
      expect(find.text('Access needs to be renewed'), findsOneWidget);
      await tester.tap(find.text('Reconnect'));
      expect(taps, 1);
    });

    testWidgets('a non-actionable error hides every action', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          SizedBox(
            height: 500,
            child: ErrorState(
              error: const AppError(AppErrorKind.permissionLost),
              onRetry: () {},
              onReport: () {},
            ),
          ),
        ),
      );
      expect(find.byType(PrimaryButton), findsNothing);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Report a problem'), findsNothing);
    });

    testWidgets('no retry callback means no retry button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const SizedBox(
            height: 500,
            child: ErrorState(error: AppError(AppErrorKind.io)),
          ),
        ),
      );
      expect(find.byType(PrimaryButton), findsNothing);
    });

    testWidgets('unexpected offers Try again and Report a problem', (
      WidgetTester tester,
    ) async {
      int retries = 0;
      int reports = 0;
      await tester.pumpWidget(
        harness(
          SizedBox(
            height: 600,
            child: ErrorState(
              error: const AppError(AppErrorKind.unexpected),
              onRetry: () => retries++,
              onReport: () => reports++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Try again'));
      await tester.tap(find.text('Report a problem'));
      expect(retries, 1);
      expect(reports, 1);
    });

    testWidgets('unsupported offers only Report a problem', (
      WidgetTester tester,
    ) async {
      int reports = 0;
      int retries = 0;
      await tester.pumpWidget(
        harness(
          SizedBox(
            height: 500,
            child: ErrorState(
              error: const AppError(AppErrorKind.unsupported),
              onRetry: () => retries++,
              onReport: () => reports++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Report a problem'));
      expect(reports, 1);
      expect(retries, 0);
      expect(find.byType(PrimaryButton), findsOneWidget);
    });

    test('every kind has a title and message', () {
      // Uses the English localisation directly.
      final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));
      for (final AppErrorKind kind in AppErrorKind.values) {
        expect(errorTitle(l10n, kind), isNotEmpty);
        expect(errorMessage(l10n, kind), isNotEmpty);
      }
      expect(errorAction(l10n, AppErrorKind.permissionLost), isNull);
      expect(errorAction(l10n, AppErrorKind.io), 'Try again');
    });
  });

  group('ToastHost', () {
    Widget host(ToastProvider provider, {bool dark = false, bool reduce = false}) {
      return harness(
        SizedBox(
          height: 500,
          child: ToastHost(
            provider: provider,
            child: const ColoredBox(color: Color(0xFFFFFFFF)),
          ),
        ),
        dark: dark,
        disableAnimations: reduce,
      );
    }

    testWidgets('shows a toast with its text and auto-dismisses at 3 seconds', (
      WidgetTester tester,
    ) async {
      final ToastProvider provider = ToastProvider();
      await tester.pumpWidget(host(provider));
      expect(find.text('Saved 1 item'), findsNothing);
      provider.show(ToastCode.saved, count: 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Saved 1 item'), findsOneWidget);
      await tester.pump(_threeSeconds);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Saved 1 item'), findsNothing);
      provider.dispose();
    });

    testWidgets('plurals are correct', (WidgetTester tester) async {
      final ToastProvider provider = ToastProvider();
      await tester.pumpWidget(host(provider));
      provider.show(ToastCode.saved, count: 3);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Saved 3 items'), findsOneWidget);
      provider.dismiss();
      await tester.pump(const Duration(milliseconds: 350));
      provider.show(ToastCode.deleted, count: 1);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Deleted 1 item'), findsOneWidget);
      provider.dismiss();
      await tester.pump(const Duration(milliseconds: 350));
      provider.show(ToastCode.savedPartial, count: 2, secondCount: 1);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text("2 saved, 1 couldn't be saved"), findsOneWidget);
      provider.dispose();
    });

    testWidgets('a sticky toast stays', (WidgetTester tester) async {
      final ToastProvider provider = ToastProvider();
      await tester.pumpWidget(host(provider));
      provider.show(ToastCode.persistenceWarning, sticky: true);
      await tester.pump(const Duration(seconds: 20));
      expect(
        find.text(
          "Settings can't be saved right now. Changes will be lost when you close the app.",
        ),
        findsOneWidget,
      );
      provider.dispose();
    });

    testWidgets('tapping dismisses', (WidgetTester tester) async {
      final ToastProvider provider = ToastProvider();
      await tester.pumpWidget(host(provider));
      provider.show(ToastCode.alreadySaved);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('Already saved'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Already saved'), findsNothing);
      expect(provider.value, isNull);
      provider.dispose();
    });

    testWidgets('every toast carries an icon next to its text', (
      WidgetTester tester,
    ) async {
      final ToastProvider provider = ToastProvider();
      await tester.pumpWidget(host(provider));
      for (final ToastCode code in ToastCode.values) {
        provider.show(code, count: 2, secondCount: 1);
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          find.descendant(
            of: find.byType(ToastHost),
            matching: find.byType(Semantics),
          ),
          findsWidgets,
        );
        provider.dismiss();
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);
      }
      provider.dispose();
    });

    testWidgets('is announced as a live region', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ToastProvider provider = ToastProvider();
      await tester.pumpWidget(host(provider));
      provider.show(ToastCode.saveFailed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final SemanticsData data = tester
          .getSemantics(find.bySemanticsLabel("Couldn't save. Try again."))
          .getSemanticsData();
      expect(data.hasFlag(SemanticsFlag.isLiveRegion), isTrue);
      handle.dispose();
      provider.dispose();
    });

    testWidgets('a retry action calls back and dismisses', (
      WidgetTester tester,
    ) async {
      final ToastProvider provider = ToastProvider();
      int retries = 0;
      await tester.pumpWidget(host(provider));
      provider.show(ToastCode.ioError, retry: () => retries++);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('Retry'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(retries, 1);
      expect(provider.value, isNull);
      provider.dispose();
    });

    testWidgets('reduce motion removes the transition time', (
      WidgetTester tester,
    ) async {
      final ToastProvider provider = ToastProvider();
      await tester.pumpWidget(host(provider, reduce: true));
      provider.show(ToastCode.saved, count: 1);
      await tester.pump();
      expect(find.text('Saved 1 item'), findsOneWidget);
      provider.dispose();
      await tester.pump(_threeSeconds);
    });

    testWidgets('sits below the top safe area', (WidgetTester tester) async {
      final ToastProvider provider = ToastProvider();
      await tester.pumpWidget(
        harness(
          SizedBox(
            height: 500,
            child: ToastHost(
              provider: provider,
              child: const SizedBox.expand(),
            ),
          ),
          padding: const EdgeInsets.only(top: 40),
        ),
      );
      provider.show(ToastCode.saved, count: 1);
      await tester.pump(const Duration(milliseconds: 350));
      final double top = tester.getTopLeft(find.text('Saved 1 item')).dy;
      expect(top, greaterThanOrEqualTo(40));
      provider.dispose();
    });
  });

  group('showAppSheet', () {
    Widget launcher(Future<void> Function(BuildContext) open, {bool reduce = false}) {
      return harness(
        Builder(
          builder: (BuildContext context) => PrimaryButton(
            label: 'Open',
            onPressed: () => open(context),
          ),
        ),
        disableAnimations: reduce,
      );
    }

    testWidgets('opens with its title and actions', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      await tester.pumpWidget(
        launcher(
          (BuildContext context) => showAppSheet<void>(
            context,
            title: 'Choose a source',
            actions: <SheetAction>[
              SheetAction(label: 'Standard', icon: AppIcons.folder, onSelected: () {}),
              const SheetAction(label: 'Business', subtitle: 'Not connected'),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a source'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('Not connected'), findsOneWidget);
    });

    testWidgets('selecting an action closes the sheet, then calls back', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      final List<String> events = <String>[];
      await tester.pumpWidget(
        launcher(
          (BuildContext context) => showAppSheet<void>(
            context,
            title: 'Folder',
            actions: <SheetAction>[
              SheetAction(
                label: 'Disconnect',
                onSelected: () => events.add('selected'),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
      expect(events, <String>['selected']);
      expect(find.text('Folder'), findsNothing);
    });

    testWidgets('a tap on the scrim dismisses without calling back', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      int selected = 0;
      await tester.pumpWidget(
        launcher(
          (BuildContext context) => showAppSheet<void>(
            context,
            title: 'Folder',
            actions: <SheetAction>[
              SheetAction(label: 'Disconnect', onSelected: () => selected++),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Folder'), findsOneWidget);
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(find.text('Folder'), findsNothing);
      expect(selected, 0);
    });

    testWidgets('the system back button dismisses it', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      await tester.pumpWidget(
        launcher(
          (BuildContext context) => showAppSheet<void>(
            context,
            title: 'Folder',
            actions: const <SheetAction>[SheetAction(label: 'Close me')],
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Folder'), findsNothing);
    });

    testWidgets('slides up over 400 ms', (WidgetTester tester) async {
      useSurface(tester);
      await tester.pumpWidget(
        launcher(
          (BuildContext context) => showAppSheet<void>(
            context,
            title: 'Folder',
            actions: const <SheetAction>[SheetAction(label: 'One')],
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final double early = tester.getTopLeft(find.text('Folder')).dy;
      await tester.pump(const Duration(milliseconds: 400));
      final double settled = tester.getTopLeft(find.text('Folder')).dy;
      expect(early, greaterThan(settled));
    });

    testWidgets('reduce motion shows it with no slide', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      await tester.pumpWidget(
        launcher(
          (BuildContext context) => showAppSheet<void>(
            context,
            title: 'Folder',
            actions: const <SheetAction>[SheetAction(label: 'One')],
          ),
          reduce: true,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump();
      final double first = tester.getTopLeft(find.text('Folder')).dy;
      await tester.pump(const Duration(milliseconds: 500));
      final double later = tester.getTopLeft(find.text('Folder')).dy;
      expect(first, later);
    });

    testWidgets('has a 20 px top radius and respects the bottom safe area', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (BuildContext context) => PrimaryButton(
              label: 'Open',
              onPressed: () => showAppSheet<void>(
                context,
                title: 'Folder',
                actions: const <SheetAction>[SheetAction(label: 'One')],
              ),
            ),
          ),
          padding: const EdgeInsets.only(bottom: 34),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final Rect row = tester.getRect(find.text('One'));
      expect(900 - row.bottom, greaterThanOrEqualTo(34));
      final BoxDecoration decoration = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((DecoratedBox d) => d.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((BoxDecoration d) => d.borderRadius == AppRadii.sheetTopRadius);
      expect(decoration.color, AppColors.light.bgSecondary);
    });

    testWidgets('destructive actions use the error colour', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      await tester.pumpWidget(
        launcher(
          (BuildContext context) => showAppSheet<void>(
            context,
            title: 'Delete?',
            actions: const <SheetAction>[
              SheetAction(label: 'Delete', destructive: true),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Delete')).style?.color,
        AppColors.light.error,
      );
    });

    testWidgets('showConfirmSheet returns true only when confirmed', (
      WidgetTester tester,
    ) async {
      useSurface(tester);
      final List<bool> results = <bool>[];
      await tester.pumpWidget(
        launcher(
          (BuildContext context) async {
            results.add(
              await showConfirmSheet(
                context,
                title: 'Delete 1 item?',
                message: "They'll be removed from your gallery too.",
                confirmLabel: 'Delete',
                cancelLabel: 'Cancel',
              ),
            );
          },
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text("They'll be removed from your gallery too."), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();

      expect(results, <bool>[true, false, false]);
    });
  });
}
