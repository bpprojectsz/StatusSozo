// A3: the screens, sheets, toasts and error states that languages_test.dart
// does not cover, in every language at normal and double text size.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/app_language.dart';
import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/providers/toast_provider.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/screens/licenses_screen.dart';
import 'package:statussozo/screens/viewer_screen.dart';
import 'package:statussozo/utils/app_log.dart';
import 'package:statussozo/utils/license_collector.dart';
import 'package:statussozo/widgets/feedback/error_state.dart';
import 'package:statussozo/widgets/feedback/toast_host.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/sheets/app_sheet.dart';
import 'package:statussozo/widgets/sheets/language_sheet.dart';
import 'package:statussozo/widgets/viewer/video_surface.dart';

import '../fakes/fakes.dart';
import '../widgets/harness.dart';
import 'screen_harness.dart';

/// A page whose build context the test can use to open sheets.
class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  late Rig rig;
  late PlatformRecorder platform;
  void testScreen(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => screenTest(description, () => rig, body);

  setUp(() {
    rig = Rig();
    platform = PlatformRecorder()..install();
    AppLog.clear();
    VideoSurface.debugReset();
  });
  tearDown(() {
    platform.uninstall();
    rig.dispose();
  });

  void expectClean(WidgetTester tester, String what, AppLanguage language) {
    expect(tester.takeException(), isNull, reason: '$what in ${language.code}');
  }

  void expectLocale(
    WidgetTester tester,
    AppLanguage language,
    Finder inside,
  ) {
    final BuildContext context = tester.element(inside.first);
    expect(AppLocalizations.of(context).localeName, language.code);
    expect(
      Directionality.of(context),
      language.rtl ? TextDirection.rtl : TextDirection.ltr,
    );
  }

  for (final AppLanguage language in AppLanguages.all) {
    for (final double scale in <double>[1, 2]) {
      final String where = '${language.code} at ${scale}x';
      final Locale locale = Locale(language.code);

      Future<void> pumpApp(WidgetTester tester, Widget home) async {
        useSurface(tester, height: 2600);
        await tester.pumpWidget(
          screenApp(rig, home, locale: locale, textScale: scale),
        );
        await tester.pump(const Duration(milliseconds: 600));
      }

      testScreen('the viewer, status mode, in $where', (
        WidgetTester tester,
      ) async {
        final List<StatusItem> items = <StatusItem>[
          statusItem('a.jpg'),
          statusItem('b.mp4', mime: 'video/mp4'),
        ];
        await pumpApp(
          tester,
          ViewerScreen(items: items, initialIndex: 0, mode: ViewerMode.status),
        );
        expectClean(tester, 'viewer (status)', language);
        expectLocale(tester, language, find.byType(ViewerScreen));
      });

      testScreen('the viewer, saved mode, in $where', (
        WidgetTester tester,
      ) async {
        final List<SavedItem> items = <SavedItem>[
          savedItem('a.jpg'),
          savedItem('b.mp4', mime: 'video/mp4'),
        ];
        await pumpApp(
          tester,
          ViewerScreen(items: items, initialIndex: 0, mode: ViewerMode.saved),
        );
        expectClean(tester, 'viewer (saved)', language);
        expectLocale(tester, language, find.byType(ViewerScreen));
      });

      testScreen('licenses and a license detail in $where', (
        WidgetTester tester,
      ) async {
        await pumpApp(tester, const LicensesScreen());
        expectClean(tester, 'licenses', language);
        expectLocale(tester, language, find.byType(LicensesScreen));
        await pumpApp(
          tester,
          LicenseDetailScreen(
            PackageLicense(
              name: 'example_package',
              paragraphs: <LicenseParagraph>[
                LicenseParagraph('Permission is hereby granted.', 0),
                LicenseParagraph('', 0),
                LicenseParagraph('An indented line.', 2),
              ],
            ),
          ),
        );
        expectClean(tester, 'license detail', language);
        expectLocale(tester, language, find.byType(LicenseDetailScreen));
      });

      testScreen('all six sheets in $where', (WidgetTester tester) async {
        await pumpApp(tester, const _Host());
        final BuildContext context = tester.element(find.byType(_Host));
        final AppLocalizations l10n = AppLocalizations.of(context);

        final List<Future<Object?> Function()> sheets =
            <Future<Object?> Function()>[
              // 1. Language picker.
              () => showLanguageSheet(
                context,
                current: 'de',
                onSelected: (String? _) {},
              ),
              // 2. Source picker on Home.
              () => showAppSheet<void>(
                context,
                title: l10n.sourceSheetTitle,
                actions: <SheetAction>[
                  SheetAction(
                    icon: AppIcons.folder,
                    label: l10n.sourceStandard,
                    subtitle: l10n.commonConnected,
                  ),
                  SheetAction(
                    icon: AppIcons.folder,
                    label: l10n.sourceBusiness,
                    subtitle: l10n.accessTitleRenewal,
                  ),
                ],
              ),
              // 3. Folder actions in Settings.
              () => showAppSheet<void>(
                context,
                title: l10n.sourceStandard,
                actions: <SheetAction>[
                  SheetAction(
                    icon: AppIcons.folderLink,
                    label: l10n.folderActionChoose,
                  ),
                  SheetAction(
                    icon: AppIcons.close,
                    label: l10n.folderActionDisconnect,
                    destructive: true,
                  ),
                ],
              ),
              // 4. Delete confirmation (Saved and the saved viewer).
              () => showConfirmSheet(
                context,
                title: l10n.deleteTitle(3),
                message: l10n.deleteMessage,
                confirmLabel: l10n.commonDelete,
                cancelLabel: l10n.commonCancel,
                confirmIcon: AppIcons.delete,
              ),
              // 5. Single delete confirmation.
              () => showConfirmSheet(
                context,
                title: l10n.deleteTitle(1),
                message: l10n.deleteMessage,
                confirmLabel: l10n.commonDelete,
                cancelLabel: l10n.commonCancel,
                confirmIcon: AppIcons.delete,
              ),
              // 6. Clear the debug log.
              () => showConfirmSheet(
                context,
                title: l10n.debugLogsClearTitle,
                message: l10n.debugLogsClearMessage,
                confirmLabel: l10n.debugLogsClear,
                cancelLabel: l10n.commonCancel,
                confirmIcon: AppIcons.delete,
              ),
            ];
        expect(sheets.length, 6);

        for (int i = 0; i < sheets.length; i++) {
          final Future<Object?> opened = sheets[i]();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          expectClean(tester, 'sheet ${i + 1}', language);
          expectLocale(tester, language, find.byType(_Host));
          // Close it again with the barrier (the system back button).
          await tester.binding.handlePopRoute();
          await tester.pump(const Duration(milliseconds: 600));
          await opened;
          expectClean(tester, 'closing sheet ${i + 1}', language);
        }
      });

      testScreen('every toast in $where', (WidgetTester tester) async {
        await pumpApp(tester, const _Host());
        final BuildContext context = tester.element(find.byType(_Host));
        final AppLocalizations l10n = AppLocalizations.of(context);
        for (final ToastCode code in ToastCode.values) {
          rig.services.toasts.show(code, count: 3, secondCount: 2);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expectClean(tester, 'toast ${code.name}', language);
          final ToastMessage? shown = rig.services.toasts.value;
          expect(shown, isNotNull, reason: code.name);
          expect(
            find.text(toastText(l10n, shown!)),
            findsOneWidget,
            reason: '${code.name} in ${language.code}',
          );
          // Let it auto-dismiss (sticky ones are cleared by hand) and let the
          // duplicate window pass before the next one.
          rig.services.toasts.dismiss();
          await tester.pump(const Duration(seconds: 2));
        }
      });

      testScreen('every error state in $where', (WidgetTester tester) async {
        for (final AppErrorKind kind in AppErrorKind.values) {
          for (final bool compact in <bool>[false, true]) {
            await pumpApp(
              tester,
              ErrorState(
                error: AppError(kind),
                compact: compact,
                onRetry: () {},
                onReport: () {},
              ),
            );
            expectClean(
              tester,
              'error ${kind.name} (compact: $compact)',
              language,
            );
            expectLocale(tester, language, find.byType(ErrorState));
            final AppLocalizations l10n = AppLocalizations.of(
              tester.element(find.byType(ErrorState)),
            );
            expect(find.text(errorTitle(l10n, kind)), findsOneWidget);
          }
        }
      });
    }
  }
}
