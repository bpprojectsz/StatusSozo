import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:statussozo/app/app_scope.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/core/providers/saved_library_provider.dart';
import 'package:statussozo/core/providers/status_list_provider.dart';
import 'package:statussozo/core/providers/toast_provider.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/screens/viewer_screen.dart';
import 'package:statussozo/widgets/feedback/empty_state.dart';
import 'package:statussozo/widgets/feedback/error_state.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/layout/app_nav_bar.dart';
import 'package:statussozo/widgets/layout/screen_scaffold.dart';
import 'package:statussozo/widgets/media/media_grid.dart';
import 'package:statussozo/widgets/media/selection_bar.dart';
import 'package:statussozo/widgets/primitives/loading_indicator.dart';
import 'package:statussozo/widgets/primitives/nav_icon_button.dart';
import 'package:statussozo/widgets/sheets/app_sheet.dart';

/// The saved library: the same grid and selection mechanics as Home, with Share
/// and Delete in the selection bar (Delete asks for confirmation first) and a
/// footnote that explains where the files live in the gallery.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh when opened. The current list stays visible meanwhile.
    scheduleMicrotask(() {
      if (mounted) {
        unawaited(AppScope.of(context).savedLibrary.refresh());
      }
    });
  }

  List<SavedItem> _selected() {
    final services = AppScope.of(context);
    final Set<String> ids = services.savedSelection.value.ids;
    return services.savedLibrary.value.items
        .where((SavedItem i) => ids.contains(i.id))
        .toList();
  }

  void _openViewer(List<SavedItem> items, int index) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => ViewerScreen(
          items: items,
          initialIndex: index,
          mode: ViewerMode.saved,
        ),
      ),
    );
  }

  void _onTap(List<SavedItem> items, int index) {
    final services = AppScope.of(context);
    if (services.savedSelection.value.active) {
      services.haptics.selection();
      services.savedSelection.toggle(items[index].id);
    } else {
      _openViewer(items, index);
    }
  }

  void _onLongPress(List<SavedItem> items, int index) {
    final services = AppScope.of(context);
    if (!services.savedSelection.value.active) {
      services.haptics.selection();
      services.savedSelection.toggle(items[index].id);
    }
  }

  Future<void> _share() async {
    final services = AppScope.of(context);
    final result = await services.share.share(_selected());
    if (result.errorOrNull != null) {
      services.toasts.show(ToastCode.shareFailed);
    }
  }

  Future<void> _delete() async {
    final services = AppScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<SavedItem> items = _selected();
    if (items.isEmpty) {
      return;
    }
    final bool confirmed = await showConfirmSheet(
      context,
      title: l10n.deleteTitle(items.length),
      message: l10n.deleteMessage,
      confirmLabel: l10n.commonDelete,
      cancelLabel: l10n.commonCancel,
      confirmIcon: AppIcons.delete,
    );
    if (!confirmed) {
      return;
    }
    final DeleteOutcome outcome = await services.savedLibrary.delete(items);
    services.savedSelection.clear();
    if (outcome.deleted > 0) {
      services.toasts.show(ToastCode.deleted, count: outcome.deleted);
    }
    if (outcome.failed > 0) {
      services.toasts.show(ToastCode.deleteFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = AppColors.of(context);
    final AppTextStyles styles = AppTextStyles.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        services.savedLibrary,
        services.savedSelection,
      ]),
      builder: (BuildContext context, Widget? _) {
        final SavedLibraryState library = services.savedLibrary.value;
        final selection = services.savedSelection.value;

        final Widget navBar = selection.active
            ? AppNavBar.selection(
                count: selection.count,
                onClose: services.savedSelection.clear,
                actions: <Widget>[
                  NavIconButton(
                    icon: AppIcons.checkCircle,
                    semanticLabel: l10n.commonSelectAll,
                    onPressed: () => services.savedSelection.selectAll(
                      library.items.map((SavedItem i) => i.id),
                    ),
                  ),
                ],
              )
            : AppNavBar.pushed(
                title: l10n.savedTitle,
                onBack: () => Navigator.of(context).pop(),
              );

        final Widget body;
        if (library.items.isEmpty && library.phase == ListPhase.error) {
          body = ErrorState(
            error: library.error ?? const AppError(AppErrorKind.unexpected),
            onRetry: () => unawaited(services.savedLibrary.refresh()),
          );
        } else if (library.items.isEmpty &&
            (library.phase == ListPhase.loading ||
                library.phase == ListPhase.idle)) {
          body = const Center(child: AppLoadingIndicator());
        } else if (library.items.isEmpty) {
          body = EmptyState(
            icon: AppIcons.saved,
            title: l10n.savedEmptyTitle,
            message: l10n.savedEmptyMessage,
          );
        } else {
          body = MediaGridView(
            items: library.items,
            source: services.thumbnails,
            selectedIds: selection.ids,
            selectionMode: selection.active,
            onTap: (int i) => _onTap(library.items, i),
            onLongPress: (int i) => _onLongPress(library.items, i),
            footer: Text(
              l10n.savedFooter(AppConfig.saveSubfolder),
              textAlign: TextAlign.center,
              style: styles.footnote.copyWith(color: colors.textTertiary),
            ),
          );
        }

        return PopScope(
          canPop: !selection.active,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop) {
              services.savedSelection.clear();
            }
          },
          child: ScreenScaffold(
            navBar: navBar,
            body: body,
            floating: SelectionBar(
              visible: selection.active,
              primaryLabel: l10n.commonShare,
              onPrimary: () => unawaited(_share()),
              actions: <Widget>[
                NavIconButton(
                  icon: AppIcons.delete,
                  semanticLabel: l10n.commonDelete,
                  onPressed: () => unawaited(_delete()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
