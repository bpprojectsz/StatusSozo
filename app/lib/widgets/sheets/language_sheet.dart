import 'package:flutter/widgets.dart';
import 'package:statussozo/core/models/app_language.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/sheets/app_sheet.dart';

/// Lets the person choose the app language: System default first, then every
/// language written in its own name. The current choice carries a check.
/// [onSelected] receives the language code, or null for System default.
Future<void> showLanguageSheet(
  BuildContext context, {
  required String? current,
  required ValueChanged<String?> onSelected,
}) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return showAppSheet<void>(
    context,
    title: l10n.languageSheetTitle,
    actions: <SheetAction>[
      SheetAction(
        icon: current == null ? AppIcons.checkCircle : AppIcons.language,
        label: l10n.languageSystemDefault,
        onSelected: () => onSelected(null),
      ),
      for (final AppLanguage language in AppLanguages.all)
        SheetAction(
          icon: current == language.code
              ? AppIcons.checkCircle
              : AppIcons.language,
          label: language.nativeName,
          onSelected: () => onSelected(language.code),
        ),
    ],
  );
}
