import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:statussozo/app/app_scope.dart';
import 'package:statussozo/core/providers/toast_provider.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/screens/screen_text.dart';
import 'package:statussozo/utils/app_log.dart';
import 'package:statussozo/widgets/feedback/empty_state.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/layout/app_nav_bar.dart';
import 'package:statussozo/widgets/layout/screen_scaffold.dart';
import 'package:statussozo/widgets/primitives/app_group.dart';
import 'package:statussozo/widgets/primitives/nav_icon_button.dart';
import 'package:statussozo/widgets/sheets/app_sheet.dart';

/// The on-device debug log: newest first, with Send report and Clear. The log
/// never leaves the device unless the person sends the report email.
class DebugLogsScreen extends StatelessWidget {
  const DebugLogsScreen({super.key});

  Future<void> _send(BuildContext context) async {
    final services = AppScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool ok = await composeReport(
      links: services.links,
      l10n: l10n,
      version: services.appVersion,
    );
    if (!ok) {
      services.toasts.show(ToastCode.linkFailed);
    }
  }

  Future<void> _clear(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed = await showConfirmSheet(
      context,
      title: l10n.debugLogsClearTitle,
      message: l10n.debugLogsClearMessage,
      confirmLabel: l10n.debugLogsClear,
      cancelLabel: l10n.commonCancel,
      confirmIcon: AppIcons.delete,
    );
    if (confirmed) {
      AppLog.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTextStyles styles = AppTextStyles.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: AppLog.revision,
      builder: (BuildContext context, int _, Widget? child) {
        final List<String> entries = AppLog.entries.reversed.toList();
        return ScreenScaffold(
          navBar: AppNavBar.pushed(
            title: l10n.debugLogsTitle,
            onBack: () => Navigator.of(context).pop(),
            actions: <Widget>[
              NavIconButton(
                icon: AppIcons.mail,
                semanticLabel: l10n.debugLogsSend,
                onPressed: () => unawaited(_send(context)),
              ),
              NavIconButton(
                icon: AppIcons.delete,
                semanticLabel: l10n.debugLogsClear,
                onPressed: entries.isEmpty
                    ? null
                    : () => unawaited(_clear(context)),
              ),
            ],
          ),
          body: entries.isEmpty
              ? EmptyState(
                  icon: AppIcons.debug,
                  title: l10n.debugLogsEmptyTitle,
                  message: l10n.debugLogsEmptyMessage,
                )
              : ScrollConfiguration(
                  behavior: const AppScrollBehavior(),
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsetsDirectional.only(
                      start: AppSpacing.gutter,
                      end: AppSpacing.gutter,
                      bottom: AppSpacing.xl,
                    ),
                    children: <Widget>[
                      AppGroup(
                        dividerInset: AppSpacing.md,
                        children: <Widget>[
                          for (final String line in entries)
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Text(line, style: styles.footnote),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
