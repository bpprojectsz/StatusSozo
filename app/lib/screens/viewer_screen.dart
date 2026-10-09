import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:statussozo/app/app_scope.dart';
import 'package:statussozo/core/contracts/video_playback.dart';
import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/models/viewable_media.dart';
import 'package:statussozo/core/providers/saved_library_provider.dart';
import 'package:statussozo/core/providers/toast_provider.dart';
import 'package:statussozo/core/result.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/media/media_thumbnail.dart';
import 'package:statussozo/widgets/primitives/loading_indicator.dart';
import 'package:statussozo/widgets/primitives/nav_icon_button.dart';
import 'package:statussozo/widgets/primitives/primary_button.dart';
import 'package:statussozo/widgets/primitives/secondary_button.dart';
import 'package:statussozo/widgets/sheets/app_sheet.dart';
import 'package:statussozo/widgets/viewer/video_controls.dart';
import 'package:statussozo/widgets/viewer/video_surface.dart';
import 'package:statussozo/widgets/viewer/viewer_overlay.dart';
import 'package:statussozo/widgets/viewer/zoomable_image.dart';

/// Whether the viewer shows statuses (with a Save button) or saved items (with
/// a Delete action).
enum ViewerMode { status, saved }

/// The full-screen viewer: a pager over photos and videos.
///
/// * Paging is locked while an image is zoomed.
/// * Images load through the thumbnail source's `readImage`, with an error
///   state and a prefetch of the neighbouring pages.
/// * Only the current page may host a video session.
/// * The top overlay has Close, "{n} of {total}" and Share; the bottom has Save
///   (status mode, disabled and labelled "Saved" once saved) or Delete (saved
///   mode, through the confirm sheet). A tap toggles the overlays.
/// * System bars are hidden while it is open and restored on exit.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({
    required this.items,
    required this.initialIndex,
    required this.mode,
    super.key,
  });

  final List<ViewableMedia> items;
  final int initialIndex;
  final ViewerMode mode;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late final List<ViewableMedia> _items = List<ViewableMedia>.of(widget.items);
  late int _current = widget.items.isEmpty
      ? 0
      : widget.initialIndex.clamp(0, widget.items.length - 1);
  late final PageController _pager = PageController(initialPage: _current);
  final Map<String, Future<Result<Uint8List>>> _bytes =
      <String, Future<Result<Uint8List>>>{};
  bool _overlay = true;
  bool _zoomed = false;
  bool _prefetched = false;

  @override
  void initState() {
    super.initState();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prefetched) {
      _prefetched = true;
      _prefetch(_current);
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  Future<Result<Uint8List>> _future(int index) {
    final services = AppScope.of(context);
    final ViewableMedia media = _items[index];
    return _bytes.putIfAbsent(
      media.uri,
      () => services.thumbnails.readImage(media),
    );
  }

  void _prefetch(int index) {
    for (int i = index - 1; i <= index + 1; i++) {
      if (i >= 0 && i < _items.length && !_items[i].kind.isVideo) {
        _future(i);
      }
    }
    final Set<String> keep = <String>{
      for (int i = index - 1; i <= index + 1; i++)
        if (i >= 0 && i < _items.length) _items[i].uri,
    };
    _bytes.removeWhere((String uri, Future<Result<Uint8List>> _) => !keep.contains(uri));
  }

  void _onPage(int index) {
    setState(() { // ui-local
      _current = index;
      _zoomed = false;
    });
    _prefetch(index);
  }

  void _toggleOverlay() {
    setState(() => _overlay = !_overlay); // ui-local
  }

  void _setZoomed(bool zoomed) {
    setState(() => _zoomed = zoomed); // ui-local
  }

  void _retry(String uri) {
    setState(() => _bytes.remove(uri)); // ui-local
  }

  Future<void> _share() async {
    final services = AppScope.of(context);
    final Result<void> result = await services.share.share(
      <ViewableMedia>[_items[_current]],
    );
    if (result.errorOrNull != null) {
      services.toasts.show(ToastCode.shareFailed);
    }
  }

  void _save() {
    final services = AppScope.of(context);
    final ViewableMedia item = _items[_current];
    if (item is StatusItem) {
      unawaited(services.save.save(<StatusItem>[item]));
    }
  }

  Future<void> _delete() async {
    final services = AppScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ViewableMedia item = _items[_current];
    if (item is! SavedItem) {
      return;
    }
    final bool confirmed = await showConfirmSheet(
      context,
      title: l10n.deleteTitle(1),
      message: l10n.deleteMessage,
      confirmLabel: l10n.commonDelete,
      cancelLabel: l10n.commonCancel,
      confirmIcon: AppIcons.delete,
    );
    if (!confirmed) {
      return;
    }
    final DeleteOutcome outcome = await services.savedLibrary.delete(
      <SavedItem>[item],
    );
    if (!mounted) {
      return;
    }
    if (outcome.deleted == 0) {
      services.toasts.show(ToastCode.deleteFailed);
      return;
    }
    services.toasts.show(ToastCode.deleted, count: 1);
    if (_items.length == 1) {
      Navigator.of(context).pop();
      return;
    }
    final int removedAt = _current;
    setState(() { // ui-local
      _items.removeAt(removedAt);
      _bytes.remove(item.uri);
      _current = removedAt.clamp(0, _items.length - 1);
      _zoomed = false;
    });
    if (_pager.hasClients) {
      _pager.jumpToPage(_current);
    }
    _prefetch(_current);
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = AppColors.of(context);
    final AppTextStyles styles = AppTextStyles.of(context);

    return ColoredBox(
      color: colors.viewerBg,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          PageView.builder(
            controller: _pager,
            physics: _zoomed
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            itemCount: _items.length,
            onPageChanged: _onPage,
            itemBuilder: (BuildContext context, int index) {
              final ViewableMedia media = _items[index];
              if (media.kind.isVideo) {
                return VideoSurface(
                  key: ValueKey<String>(media.uri),
                  uri: media.uri,
                  factory: services.videoFactory,
                  active: index == _current,
                  onTap: _toggleOverlay,
                  poster: MediaThumbnail(
                    media: media,
                    source: services.thumbnails,
                  ),
                  controlsBuilder:
                      (
                        BuildContext context,
                        VideoSession session,
                        VideoState state,
                      ) => _VideoControlsLayer(
                        visible: _overlay,
                        session: session,
                        state: state,
                      ),
                );
              }
              return _ImagePage(
                key: ValueKey<String>(media.uri),
                future: _future(index),
                onZoomChanged: _setZoomed,
                onTap: _toggleOverlay,
                onRetry: () => _retry(media.uri),
              );
            },
          ),
          ViewerOverlay(
            visible: _overlay,
            top: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  NavIconButton(
                    icon: AppIcons.close,
                    semanticLabel: l10n.semCloseViewer,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        l10n.viewerCounter(_current + 1, _items.length),
                        style: styles.tabular.copyWith(color: colors.onScrim),
                      ),
                    ),
                  ),
                  NavIconButton(
                    icon: AppIcons.share,
                    semanticLabel: l10n.commonShare,
                    onPressed: _share,
                  ),
                ],
              ),
            ),
            bottom: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: widget.mode == ViewerMode.status
                  ? ListenableBuilder(
                      listenable: services.savedLibrary,
                      builder: (BuildContext context, Widget? _) {
                        final bool saved = services.savedLibrary.value.names
                            .contains(_items[_current].name);
                        return PrimaryButton(
                          label: saved ? l10n.commonSaved : l10n.commonSave,
                          icon: saved ? AppIcons.check : AppIcons.save,
                          onPressed: saved ? null : _save,
                        );
                      },
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        NavIconButton(
                          icon: AppIcons.delete,
                          semanticLabel: l10n.commonDelete,
                          onPressed: _delete,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Video controls that sit above the bottom action area and fade with the
/// overlay.
class _VideoControlsLayer extends StatelessWidget {
  const _VideoControlsLayer({
    required this.visible,
    required this.session,
    required this.state,
  });

  final bool visible;
  final VideoSession session;
  final VideoState state;

  static const double _clearance = AppSizes.buttonHeight + AppSpacing.xl;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: _clearance),
        child: IgnorePointer(
          ignoring: !visible,
          child: ExcludeSemantics(
            excluding: !visible,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: AppMotion.resolve(context, AppMotion.viewerControls),
              curve: AppMotion.easeOut,
              child: VideoControls(
                state: state,
                onPlayPause: () => unawaited(
                  state.playing ? session.pause() : session.play(),
                ),
                onSeek: (Duration position) =>
                    unawaited(session.seekTo(position)),
                onReplay: () => unawaited(_replay()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _replay() async {
    await session.seekTo(Duration.zero);
    await session.play();
  }
}

class _ImagePage extends StatelessWidget {
  const _ImagePage({
    required this.future,
    required this.onZoomChanged,
    required this.onTap,
    required this.onRetry,
    super.key,
  });

  final Future<Result<Uint8List>> future;
  final ValueChanged<bool> onZoomChanged;
  final VoidCallback onTap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = AppColors.of(context);
    final AppTextStyles styles = AppTextStyles.of(context);

    return FutureBuilder<Result<Uint8List>>(
      future: future,
      builder:
          (BuildContext context, AsyncSnapshot<Result<Uint8List>> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(child: AppLoadingIndicator(color: colors.onScrim));
            }
            final Uint8List? bytes = snapshot.data?.valueOrNull;
            if (snapshot.hasError || bytes == null) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          l10n.viewerLoadFailed,
                          textAlign: TextAlign.center,
                          style: styles.body.copyWith(color: colors.onScrim),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SecondaryButton(
                          label: l10n.commonRetry,
                          expand: false,
                          onPressed: onRetry,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return ZoomableImage(
              bytes: bytes,
              onZoomChanged: onZoomChanged,
              onTap: onTap,
            );
          },
    );
  }
}
