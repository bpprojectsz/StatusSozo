import 'package:flutter/widgets.dart';
import 'package:statussozo/core/contracts/thumbnail_source.dart';
import 'package:statussozo/core/models/viewable_media.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/widgets/icons/app_icon.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/media/media_thumbnail.dart';
import 'package:statussozo/widgets/primitives/pressable.dart';

/// The accessibility label of a tile: kind, saved and selected.
String tileLabel(
  AppLocalizations l10n, {
  required bool isVideo,
  required bool saved,
  required bool selected,
}) {
  if (isVideo) {
    if (saved && selected) {
      return l10n.tileLabelVideoSavedSelected;
    }
    if (saved) {
      return l10n.tileLabelVideoSaved;
    }
    if (selected) {
      return l10n.tileLabelVideoSelected;
    }
    return l10n.tileLabelVideo;
  }
  if (saved && selected) {
    return l10n.tileLabelPhotoSavedSelected;
  }
  if (saved) {
    return l10n.tileLabelPhotoSaved;
  }
  if (selected) {
    return l10n.tileLabelPhotoSelected;
  }
  return l10n.tileLabelPhoto;
}

/// One grid tile: a square thumbnail with radius 12.
///
/// * A video badge sits bottom-start (play icon on a scrim chip).
/// * A saved badge sits bottom-end (check icon on a success chip).
/// * A selection mark sits top-end: a 24 px ring while in selection mode,
///   filled with the accent and a check when selected.
/// * Selected tiles get an `accentSoft` wash and a 2 px accent ring.
class StatusTile extends StatelessWidget {
  const StatusTile({
    required this.media,
    required this.source,
    super.key,
    this.selected = false,
    this.selectionMode = false,
    this.saved = false,
    this.onTap,
    this.onLongPress,
  });

  final ViewableMedia media;
  final ThumbnailSource source;
  final bool selected;
  final bool selectionMode;
  final bool saved;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isVideo = media.kind.isVideo;

    final Widget tile = AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: AppRadii.thumbRadius,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: AppRadii.thumbRadius,
            border: selected
                ? Border.all(
                    color: colors.accent,
                    width: AppSizes.selectionRing,
                  )
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              MediaThumbnail(media: media, source: source),
              if (selected)
                ColoredBox(color: colors.accentSoft.withValues(alpha: 0.55)),
              if (isVideo)
                PositionedDirectional(
                  bottom: AppSpacing.xs,
                  start: AppSpacing.xs,
                  child: _Badge(
                    background: colors.scrim,
                    icon: AppIcons.play,
                    iconColor: colors.onScrim,
                    mirrorInRtl: true,
                  ),
                ),
              if (saved)
                PositionedDirectional(
                  bottom: AppSpacing.xs,
                  end: AppSpacing.xs,
                  child: _Badge(
                    background: colors.success,
                    icon: AppIcons.check,
                    iconColor: colors.onScrim,
                  ),
                ),
              if (selectionMode)
                PositionedDirectional(
                  top: AppSpacing.xs,
                  end: AppSpacing.xs,
                  child: _SelectionMark(selected: selected, colors: colors),
                ),
            ],
          ),
        ),
      ),
    );

    return Pressable(
      fill: true,
      onPressed: onTap,
      onLongPress: onLongPress,
      semanticLabel: tileLabel(
        l10n,
        isVideo: isVideo,
        saved: saved,
        selected: selected,
      ),
      child: tile,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.background,
    required this.icon,
    required this.iconColor,
    this.mirrorInRtl = false,
  });

  final Color background;
  final AppIconData icon;
  final Color iconColor;
  final bool mirrorInRtl;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.pillRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm - AppSpacing.xxs,
          vertical: AppSpacing.xs,
        ),
        child: AppIcon(
          icon,
          size: AppSizes.iconBadge,
          color: iconColor,
          mirrorInRtl: mirrorInRtl,
        ),
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected, required this.colors});

  final bool selected;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.selectionBadge,
      height: AppSizes.selectionBadge,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? colors.accent : colors.scrim,
          border: Border.all(
            color: selected ? colors.accent : colors.onScrim,
            width: AppSizes.selectionRing,
          ),
        ),
        child: selected
            ? Center(
                child: AppIcon(
                  AppIcons.check,
                  size: AppSizes.iconBadge,
                  color: colors.accentOn,
                ),
              )
            : null,
      ),
    );
  }
}
