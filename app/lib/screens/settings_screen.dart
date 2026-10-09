import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:statussozo/app/app_scope.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/providers/folder_access_provider.dart';
import 'package:statussozo/core/providers/toast_provider.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/screens/access_screen.dart';
import 'package:statussozo/screens/screen_text.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/layout/app_nav_bar.dart';
import 'package:statussozo/widgets/layout/screen_scaffold.dart';
import 'package:statussozo/widgets/primitives/app_card.dart';
import 'package:statussozo/widgets/primitives/app_chip.dart';
import 'package:statussozo/widgets/primitives/app_group.dart';
import 'package:statussozo/widgets/primitives/app_row.dart';
import 'package:statussozo/widgets/primitives/section_header.dart';
import 'package:statussozo/widgets/primitives/segmented_tabs.dart';
import 'package:statussozo/widgets/sheets/app_sheet.dart';

/// Settings: inset grouped cards with uppercase section headers.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _open(BuildContext context, Future<bool> Function() action) async {
    final services = AppScope.of(context);
    final bool ok = await action();
    if (!ok) {
      services.toasts.show(ToastCode.linkFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = AppColors.of(context);
    final AppTextStyles styles = AppTextStyles.of(context);

    return ScreenScaffold(
      navBar: AppNavBar.pushed(
        title: l10n.settingsTitle,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: ScrollConfiguration(
        behavior: const AppScrollBehavior(),
        child: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.gutter,
            end: AppSpacing.gutter,
            bottom: AppSpacing.xl,
          ),
          children: <Widget>[
            SectionHeader(l10n.settingsSectionAppearance),
            ListenableBuilder(
              listenable: services.theme,
              builder: (BuildContext context, Widget? _) {
                return AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: SegmentedTabs<ThemePreference>(
                    semanticLabel: l10n.settingsTheme,
                    value: services.theme.value,
                    onChanged: (ThemePreference p) =>
                        unawaited(services.theme.setPreference(p)),
                    segments: <SegmentItem<ThemePreference>>[
                      SegmentItem<ThemePreference>(
                        value: ThemePreference.system,
                        label: l10n.themeSystem,
                      ),
                      SegmentItem<ThemePreference>(
                        value: ThemePreference.light,
                        label: l10n.themeLight,
                      ),
                      SegmentItem<ThemePreference>(
                        value: ThemePreference.dark,
                        label: l10n.themeDark,
                      ),
                    ],
                  ),
                );
              },
            ),
            SectionHeader(l10n.settingsSectionFolders),
            ListenableBuilder(
              listenable: Listenable.merge(<Listenable>[
                services.folderAccess,
                services.settings,
              ]),
              builder: (BuildContext context, Widget? _) {
                return AppGroup(
                  children: <Widget>[
                    for (final StatusSource source in StatusSource.values)
                      _FolderRow(source: source),
                  ],
                );
              },
            ),
            SectionHeader(l10n.settingsSectionSupport),
            AppGroup(
              children: <Widget>[
                AppRow(
                  icon: AppIcons.rate,
                  label: l10n.settingsRate,
                  showChevron: true,
                  onPressed: () => unawaited(
                    _open(context, services.links.openStoreListing),
                  ),
                ),
                AppRow(
                  icon: AppIcons.mail,
                  label: l10n.settingsFeedback,
                  showChevron: true,
                  onPressed: () => unawaited(
                    _open(
                      context,
                      () => composeFeedback(
                        links: services.links,
                        l10n: l10n,
                        version: services.appVersion,
                      ),
                    ),
                  ),
                ),
                AppRow(
                  icon: AppIcons.privacy,
                  label: l10n.settingsPrivacy,
                  showChevron: true,
                  onPressed: () => unawaited(
                    _open(
                      context,
                      () => services.links.openUrl(
                        Uri.parse(AppConfig.privacyUrl),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SectionHeader(l10n.settingsSectionAbout),
            AppGroup(
              dividerInset: AppSpacing.md,
              children: <Widget>[
                AppRow(
                  label: l10n.settingsVersion,
                  trailing: Text(
                    services.appVersion,
                    style: styles.footnote,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                l10n.settingsDisclaimer(l10n.appName),
                style: styles.footnote.copyWith(color: colors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One folder row: its connection chip and, on tap, the folder actions.
class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.source});

  final StatusSource source;

  AccessStatus _status(AccessStatus status, AppSettings settings) {
    if (status != AccessStatus.unknown) {
      return status;
    }
    return settings.grants.containsKey(source)
        ? AccessStatus.connected
        : AccessStatus.notConnected;
  }

  void _openSheet(BuildContext context, AccessStatus status) {
    final services = AppScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    unawaited(
      showAppSheet<void>(
        context,
        title: sourceName(l10n, source),
        actions: <SheetAction>[
          SheetAction(
            icon: AppIcons.folderLink,
            label: l10n.folderActionChoose,
            onSelected: () => Navigator.of(context).push(
              AppPageRoute<void>(
                builder: (_) =>
                    AccessScreen(mode: AccessMode.reconnect, source: source),
              ),
            ),
          ),
          if (status != AccessStatus.notConnected)
            SheetAction(
              icon: AppIcons.close,
              label: l10n.folderActionDisconnect,
              destructive: true,
              onSelected: () {
                unawaited(
                  services.folderAccess.disconnect(source).then((_) {
                    services.toasts.show(ToastCode.folderDisconnected);
                  }),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AccessStatus status = _status(
      services.folderAccess.value.statusOf(source),
      services.settings.settings,
    );
    final Widget chip = switch (status) {
      AccessStatus.connected => AppChip(
        label: l10n.commonConnected,
        tone: AppChipTone.success,
      ),
      AccessStatus.needsRenewal => AppChip(
        label: l10n.accessTitleRenewal,
        tone: AppChipTone.warning,
      ),
      AccessStatus.unknown ||
      AccessStatus.notConnected => AppChip(label: l10n.commonNotConnected),
    };
    return AppRow(
      icon: AppIcons.folder,
      label: sourceName(l10n, source),
      trailing: chip,
      onPressed: () => _openSheet(context, status),
    );
  }
}
