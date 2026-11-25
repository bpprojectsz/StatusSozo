import 'package:flutter/widgets.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/sheets/app_sheet.dart';

/// Lets the person choose System, Light or Dark. The current choice carries a
/// check. Uses the same words as the Theme control in Settings.
Future<void> showThemeSheet(
  BuildContext context, {
  required ThemePreference current,
  required ValueChanged<ThemePreference> onSelected,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  String label(ThemePreference p) => switch (p) {
    ThemePreference.system => l10n.themeSystem,
    ThemePreference.light => l10n.themeLight,
    ThemePreference.dark => l10n.themeDark,
  };
  return showAppSheet<void>(
    context,
    title: l10n.settingsTheme,
    actions: <SheetAction>[
      for (final ThemePreference p in ThemePreference.values)
        SheetAction(
          icon: current == p ? AppIcons.checkCircle : AppIcons.theme,
          label: label(p),
          onSelected: () => onSelected(p),
        ),
    ],
  );
}
