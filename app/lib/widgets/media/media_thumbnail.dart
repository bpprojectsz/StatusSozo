import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:statussozo/core/contracts/thumbnail_source.dart';
import 'package:statussozo/core/models/viewable_media.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/widgets/icons/app_icon.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';

/// One thumbnail. It asks the [ThumbnailSource] once (the source caches), shows
/// the bytes with a 200 ms fade, and while waiting shows a flat `bgTertiary`
/// fill with no shimmer and no skeleton. When the file cannot be decoded it
/// shows a centred image or video icon on the same fill, so a tile is never an
/// empty box.
class MediaThumbnail extends StatefulWidget {
  const MediaThumbnail({
    required this.media,
    required this.source,
    super.key,
    this.px = AppSizes.thumbnailRequestPx,
  });

  final ViewableMedia media;
  final ThumbnailSource source;

  /// Longest edge requested from the source, in pixels.
  final int px;

  @override
  State<MediaThumbnail> createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends State<MediaThumbnail> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(MediaThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.uri != widget.media.uri ||
        oldWidget.px != widget.px ||
        !identical(oldWidget.source, widget.source)) {
      _future = _load();
    }
  }

  Future<Uint8List?> _load() => widget.source.thumbnail(widget.media, widget.px);

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final Widget fallback = Center(
      child: AppIcon(
        widget.media.kind.isVideo ? AppIcons.video : AppIcons.image,
        size: AppSizes.iconHero,
        color: colors.textTertiary,
      ),
    );

    return ColoredBox(
      color: colors.bgTertiary,
      child: FutureBuilder<Uint8List?>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox.expand();
          }
          final Uint8List? bytes = snapshot.data;
          if (snapshot.hasError || bytes == null) {
            return fallback;
          }
          return SizedBox.expand(
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: widget.px,
              excludeFromSemantics: true,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? trace) =>
                      fallback,
              frameBuilder:
                  (
                    BuildContext context,
                    Widget child,
                    int? frame,
                    bool wasSynchronouslyLoaded,
                  ) {
                    return AnimatedOpacity(
                      opacity: frame == null && !wasSynchronouslyLoaded ? 0 : 1,
                      duration: AppMotion.resolve(context, AppMotion.tab),
                      curve: AppMotion.easeOut,
                      child: child,
                    );
                  },
            ),
          );
        },
      ),
    );
  }
}
