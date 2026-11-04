import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:statussozo/app/app_scope.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/providers/folder_access_provider.dart';
import 'package:statussozo/core/providers/status_list_provider.dart';
import 'package:statussozo/core/providers/toast_provider.dart';
import 'package:statussozo/core/services/interstitial_policy.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/screens/access_screen.dart';
import 'package:statussozo/screens/saved_screen.dart';
import 'package:statussozo/screens/screen_text.dart';
import 'package:statussozo/screens/settings_screen.dart';
import 'package:statussozo/screens/viewer_screen.dart';
import 'package:statussozo/widgets/ads/ad_slot.dart';
import 'package:statussozo/widgets/feedback/empty_state.dart';
import 'package:statussozo/widgets/feedback/error_state.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/layout/app_nav_bar.dart';
import 'package:statussozo/widgets/layout/screen_scaffold.dart';
import 'package:statussozo/widgets/media/media_grid.dart';
import 'package:statussozo/widgets/media/selection_bar.dart';
import 'package:statussozo/widgets/primitives/app_chip.dart';
import 'package:statussozo/widgets/primitives/loading_indicator.dart';
import 'package:statussozo/widgets/primitives/nav_icon_button.dart';
import 'package:statussozo/widgets/primitives/segmented_tabs.dart';
import 'package:statussozo/widgets/sheets/app_sheet.dart';

enum _MediaTab { photos, videos }

/// The main screen: Photos and Videos tabs, the source chip, the grid, and a
/// floating selection bar. It contains no business logic: it reads providers
/// and calls their methods.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _MediaTab _tab = _MediaTab.photos;
  Timer? _poll;
  double _pull = 0;
  bool _pulling = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(AppConfig.autoRefreshInterval, (Timer _) => _tick());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Silently re-reads the folder while Home is showing, so a status the
  /// messaging app downloads later appears without any action.
  void _tick() {
    if (!mounted) {
      return;
    }
    final AppLifecycleState? lifecycle =
        WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return;
    }
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    final services = AppScope.of(context);
    final StatusListState list = services.statusList.value;
    if (list.phase != ListPhase.ready || list.refreshing) {
      return;
    }
    unawaited(services.statusList.refresh(silent: true));
  }

  bool _onScroll(ScrollNotification n) {
    if (n is OverscrollNotification &&
        n.dragDetails != null &&
        n.overscroll < 0) {
      _pull -= n.overscroll;
      if (_pull >= AppConfig.pullToRefreshDistance && !_pulling) {
        _pull = 0;
        unawaited(_pullRefresh());
      }
    } else if (n is ScrollEndNotification) {
      _pull = 0;
    }
    return false;
  }

  Future<void> _pullRefresh() async {
    final services = AppScope.of(context);
    services.haptics.light();
    setState(() => _pulling = true); // ui-local
    await Future.wait<void>(<Future<void>>[
      services.statusList.refresh(silent: true),
      Future<void>.delayed(AppConfig.pullIndicatorMinimum),
    ]);
    if (mounted) {
      setState(() => _pulling = false); // ui-local
    }
  }

  List<StatusItem> _tabItems(StatusListState list) =>
      _tab == _MediaTab.photos ? list.photos : list.videos;

  void _setTab(_MediaTab tab) {
    if (tab == _tab) {
      return;
    }
    AppScope.of(context).homeSelection.clear();
    setState(() => _tab = tab); // ui-local
  }

  void _push(Widget screen) {
    Navigator.of(context).push(AppPageRoute<void>(builder: (_) => screen));
  }

  void _openViewer(List<StatusItem> items, int index) {
    _push(
      ViewerScreen(
        items: items,
        initialIndex: index,
        mode: ViewerMode.status,
      ),
    );
  }

  void _onTap(List<StatusItem> items, int index) {
    final services = AppScope.of(context);
    if (services.homeSelection.value.active) {
      services.haptics.selection();
      services.homeSelection.toggle(items[index].id);
    } else {
      _openViewer(items, index);
    }
  }

  void _onLongPress(List<StatusItem> items, int index) {
    final services = AppScope.of(context);
    if (!services.homeSelection.value.active) {
      services.haptics.selection();
      services.homeSelection.toggle(items[index].id);
    }
  }

  List<StatusItem> _selectedItems() {
    final services = AppScope.of(context);
    final Set<String> ids = services.homeSelection.value.ids;
    return services.statusList.value.items
        .where((StatusItem i) => ids.contains(i.id))
        .toList();
  }

  Future<void> _saveSelected() async {
    final services = AppScope.of(context);
    final List<StatusItem> items = _selectedItems();
    services.homeSelection.clear();
    await services.save.save(items);
    final int saved = services.save.value.last?.saved.length ?? 0;
    if (saved > 0) {
      unawaited(
        services.ads.maybeShowInterstitial(
          InterstitialTrigger.batchSave,
          items: saved,
        ),
      );
    }
  }

  Future<void> _shareSelected() async {
    final services = AppScope.of(context);
    final result = await services.share.share(_selectedItems());
    if (result.errorOrNull != null) {
      services.toasts.show(ToastCode.shareFailed);
    }
  }

  void _connect(StatusSource source) {
    _push(AccessScreen(mode: AccessMode.reconnect, source: source));
  }

  Future<void> _report() async {
    final services = AppScope.of(context);
    await composeReport(
      links: services.links,
      l10n: AppLocalizations.of(context),
      version: services.appVersion,
    );
  }

  void _openSourceSheet() {
    final services = AppScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    unawaited(
      showAppSheet<void>(
        context,
        title: l10n.sourceSheetTitle,
        actions: <SheetAction>[
          for (final StatusSource source in StatusSource.values)
            SheetAction(
              icon: AppIcons.folder,
              label: sourceName(l10n, source),
              subtitle: switch (services.folderAccess.value.statusOf(source)) {
                AccessStatus.connected => l10n.commonConnected,
                AccessStatus.needsRenewal => l10n.accessTitleRenewal,
                AccessStatus.unknown ||
                AccessStatus.notConnected => l10n.commonNotConnected,
              },
              onSelected: () {
                if (services.folderAccess.value.statusOf(source) ==
                    AccessStatus.connected) {
                  unawaited(services.source.select(source));
                } else {
                  _connect(source);
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _content({
    required StatusListState list,
    required AccessStatus access,
    required StatusSource source,
    required List<StatusItem> tabItems,
    required Set<String> selectedIds,
    required bool selectionMode,
  }) {
    final services = AppScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);

    if (access == AccessStatus.needsRenewal) {
      return ErrorState(
        error: const AppError(AppErrorKind.accessLost),
        onRetry: () => _connect(source),
      );
    }
    switch (list.phase) {
      case ListPhase.idle:
        return EmptyState(
          icon: AppIcons.folderLink,
          title: l10n.accessTitleFirst,
          message: l10n.accessBody(l10n.appName),
          actionLabel: l10n.accessChooseFolder,
          onAction: () => _connect(source),
        );
      case ListPhase.loading:
        return const Center(child: AppLoadingIndicator());
      case ListPhase.error:
        return ErrorState(
          error: list.error ?? const AppError(AppErrorKind.unexpected),
          onRetry: () => unawaited(services.statusList.refresh()),
          onReport: () => unawaited(_report()),
        );
      case ListPhase.ready:
        if (tabItems.isEmpty) {
          return EmptyState(
            title: l10n.homeEmptyTitle,
            message: l10n.homeEmptyMessage,
            actionLabel: l10n.commonRefresh,
            onAction: () => unawaited(services.statusList.refresh()),
          );
        }
        return Stack(
          children: <Widget>[
            NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: MediaGridView(
                items: tabItems,
                source: services.thumbnails,
                selectedIds: selectedIds,
                selectionMode: selectionMode,
                savedNames: services.savedLibrary.value.names,
                onTap: (int i) => _onTap(tabItems, i),
                onLongPress: (int i) => _onLongPress(tabItems, i),
              ),
            ),
            if (_pulling)
              const Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: IgnorePointer(child: AppLoadingIndicator()),
                ),
              ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        services.statusList,
        services.folderAccess,
        services.source,
        services.homeSelection,
        services.savedLibrary,
      ]),
      builder: (BuildContext context, Widget? _) {
        final StatusListState list = services.statusList.value;
        final selection = services.homeSelection.value;
        final StatusSource source = services.source.value;
        final List<StatusItem> tabItems = _tabItems(list);
        final AccessStatus access = services.folderAccess.value.statusOf(
          source,
        );
        final bool bothConnected =
            services.folderAccess.connectedSources.length > 1;

        final Widget navBar = selection.active
            ? AppNavBar.selection(
                count: selection.count,
                onClose: services.homeSelection.clear,
                actions: <Widget>[
                  NavIconButton(
                    icon: AppIcons.checkCircle,
                    semanticLabel: l10n.commonSelectAll,
                    onPressed: () => services.homeSelection.selectAll(
                      tabItems.map((StatusItem i) => i.id),
                    ),
                  ),
                ],
              )
            : AppNavBar.home(
                actions: <Widget>[
                  NavIconButton(
                    icon: AppIcons.saved,
                    semanticLabel: l10n.navSaved,
                    onPressed: () => _push(const SavedScreen()),
                  ),
                  NavIconButton(
                    icon: AppIcons.settings,
                    semanticLabel: l10n.navSettings,
                    onPressed: () => _push(const SettingsScreen()),
                  ),
                ],
              );

        return PopScope(
          canPop: !selection.active,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop) {
              services.homeSelection.clear();
            }
          },
          child: ScreenScaffold(
            navBar: navBar,
            bottomEmbed: AdSlot(
              service: services.ads.service,
              enabled: services.ads.isEnabled,
            ),
            floating: SelectionBar(
              visible: selection.active,
              primaryLabel: l10n.selectionSave(selection.count),
              onPrimary: () => unawaited(_saveSelected()),
              actions: <Widget>[
                NavIconButton(
                  icon: AppIcons.share,
                  semanticLabel: l10n.commonShare,
                  onPressed: () => unawaited(_shareSelected()),
                ),
              ],
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (bothConnected)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.gutter,
                      AppSpacing.sm,
                      AppSpacing.gutter,
                      0,
                    ),
                    child: SegmentedTabs<StatusSource>(
                      semanticLabel: l10n.semSwitchSource,
                      value: source,
                      onChanged: (StatusSource next) =>
                          unawaited(services.source.select(next)),
                      segments: <SegmentItem<StatusSource>>[
                        for (final StatusSource s in StatusSource.values)
                          SegmentItem<StatusSource>(
                            value: s,
                            label: sourceName(l10n, s),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        flex: 2,
                        child: SegmentedTabs<_MediaTab>(
                          semanticLabel: l10n.tabPhotos,
                          value: _tab,
                          onChanged: _setTab,
                          segments: <SegmentItem<_MediaTab>>[
                            SegmentItem<_MediaTab>(
                              value: _MediaTab.photos,
                              label: l10n.tabPhotos,
                              count: list.photos.length,
                            ),
                            SegmentItem<_MediaTab>(
                              value: _MediaTab.videos,
                              label: l10n.tabVideos,
                              count: list.videos.length,
                            ),
                          ],
                        ),
                      ),
                      if (!bothConnected) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Semantics(
                            label: l10n.semSwitchSource,
                            container: true,
                            child: AppChip(
                              label: sourceName(l10n, source),
                              icon: AppIcons.folder,
                              onPressed: _openSourceSheet,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: _content(
                    list: list,
                    access: access,
                    source: source,
                    tabItems: tabItems,
                    selectedIds: selection.ids,
                    selectionMode: selection.active,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
