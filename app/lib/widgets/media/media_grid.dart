import 'package:flutter/widgets.dart';
import 'package:statussozo/core/contracts/thumbnail_source.dart';
import 'package:statussozo/core/models/viewable_media.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/widgets/media/status_tile.dart';

/// The grid delegate used everywhere: tiles of at most 140 px with an 8 px gap.
const SliverGridDelegate mediaGridDelegate =
    SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: AppSizes.gridMaxTileExtent,
      mainAxisSpacing: AppSpacing.gridGap,
      crossAxisSpacing: AppSpacing.gridGap,
    );

/// The tiles as a sliver. Keep-alives are off and repaint boundaries are on, so
/// scrolling stays cheap on low-end phones.
class SliverMediaGrid extends StatelessWidget {
  const SliverMediaGrid({
    required this.items,
    required this.source,
    super.key,
    this.selectedIds = const <String>{},
    this.savedNames = const <String>{},
    this.selectionMode = false,
    this.onTap,
    this.onLongPress,
  });

  final List<ViewableMedia> items;
  final ThumbnailSource source;

  /// URIs of the selected items.
  final Set<String> selectedIds;

  /// File names that are already saved, for the saved badge.
  final Set<String> savedNames;
  final bool selectionMode;
  final void Function(int index)? onTap;
  final void Function(int index)? onLongPress;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: mediaGridDelegate,
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          final ViewableMedia media = items[index];
          return StatusTile(
            key: ValueKey<String>(media.uri),
            media: media,
            source: source,
            selected: selectedIds.contains(media.uri),
            selectionMode: selectionMode,
            saved: savedNames.contains(media.name),
            onTap: onTap == null ? null : () => onTap!(index),
            onLongPress: onLongPress == null ? null : () => onLongPress!(index),
          );
        },
        childCount: items.length,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
      ),
    );
  }
}

/// A ready scroll view around [SliverMediaGrid]: clamping physics, gutter
/// padding, an optional footer, and extra bottom padding that clears the
/// floating selection bar and the ad slot.
class MediaGridView extends StatelessWidget {
  const MediaGridView({
    required this.items,
    required this.source,
    super.key,
    this.selectedIds = const <String>{},
    this.savedNames = const <String>{},
    this.selectionMode = false,
    this.onTap,
    this.onLongPress,
    this.footer,
    this.bottomClearance = defaultBottomClearance,
    this.controller,
  });

  final List<ViewableMedia> items;
  final ThumbnailSource source;
  final Set<String> selectedIds;
  final Set<String> savedNames;
  final bool selectionMode;
  final void Function(int index)? onTap;
  final void Function(int index)? onLongPress;
  final Widget? footer;
  final double bottomClearance;
  final ScrollController? controller;

  /// Clears the floating selection bar.
  static const double defaultBottomClearance =
      AppSizes.buttonHeight + AppSpacing.xl + AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    final Widget? foot = footer;
    return ScrollConfiguration(
      behavior: const AppScrollBehavior(),
      child: CustomScrollView(
        controller: controller,
        physics: const ClampingScrollPhysics(),
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gutter,
            ),
            sliver: SliverMediaGrid(
              items: items,
              source: source,
              selectedIds: selectedIds,
              savedNames: savedNames,
              selectionMode: selectionMode,
              onTap: onTap,
              onLongPress: onLongPress,
            ),
          ),
          if (foot != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: foot,
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: bottomClearance)),
        ],
      ),
    );
  }
}
