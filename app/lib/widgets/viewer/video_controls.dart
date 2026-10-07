import 'package:flutter/widgets.dart';
import 'package:statussozo/core/contracts/video_playback.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/utils/formatters.dart';
import 'package:statussozo/widgets/icons/app_icon.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/primitives/pressable.dart';

/// Custom video controls: a 64 px circle that plays, pauses or replays, a
/// scrubber with a 4 px track (6 px while dragging), a 14 px thumb and a 48 px
/// touch height, and elapsed and total time in tabular figures.
///
/// The scrubber is a slider for screen readers with increase and decrease
/// actions. Media controls keep a left-to-right time axis in every language.
class VideoControls extends StatelessWidget {
  const VideoControls({
    required this.state,
    required this.onPlayPause,
    required this.onSeek,
    required this.onReplay,
    super.key,
  });

  final VideoState state;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppTextStyles styles = AppTextStyles.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);

    final (AppIconData icon, String label) = state.ended
        ? (AppIcons.replay, l10n.viewerReplay)
        : state.playing
        ? (AppIcons.pause, l10n.viewerPause)
        : (AppIcons.play, l10n.viewerPlay);
    final TextStyle timeStyle = styles.tabular.copyWith(color: colors.onScrim);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Pressable(
            semanticLabel: label,
            onPressed: state.ended ? onReplay : onPlayPause,
            child: SizedBox(
              width: AppSizes.playCircle,
              height: AppSizes.playCircle,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.scrim,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AppIcon(
                    icon,
                    size: AppSpacing.xl,
                    color: colors.onScrim,
                    mirrorInRtl: icon == AppIcons.play,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: <Widget>[
                Text(formatDuration(state.position), style: timeStyle),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _Scrubber(state: state, onSeek: onSeek)),
                const SizedBox(width: AppSpacing.sm),
                Text(formatDuration(state.duration), style: timeStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Scrubber extends StatefulWidget {
  const _Scrubber({required this.state, required this.onSeek});

  final VideoState state;
  final ValueChanged<Duration> onSeek;

  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
  static const Duration _step = Duration(seconds: 5);

  bool _dragging = false;
  double _dragFraction = 0;

  double _fractionAt(double dx, double width) =>
      width <= 0 ? 0 : (dx / width).clamp(0.0, 1.0).toDouble();

  Duration _positionAt(double fraction) => Duration(
    microseconds: (widget.state.duration.inMicroseconds * fraction).round(),
  );

  void _beginDrag(double fraction) {
    setState(() { _dragging = true; _dragFraction = fraction; }); // ui-local
  }

  void _updateDrag(double fraction) {
    setState(() => _dragFraction = fraction); // ui-local
  }

  void _endDrag() {
    setState(() => _dragging = false); // ui-local
  }

  Duration _clamped(Duration value, Duration total) {
    if (value < Duration.zero) {
      return Duration.zero;
    }
    return value > total ? total : value;
  }

  void _seekBy(Duration delta) {
    final int total = widget.state.duration.inMicroseconds;
    final int target = (widget.state.position + delta).inMicroseconds;
    widget.onSeek(Duration(microseconds: target.clamp(0, total)));
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final VideoState state = widget.state;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double fraction = _dragging ? _dragFraction : state.progress;
        final double trackHeight = _dragging
            ? AppSizes.scrubTrackActive
            : AppSizes.scrubTrack;
        final double thumbX = fraction * (width - AppSizes.scrubThumb);

        return Semantics(
          slider: true,
          label: l10n.viewerPosition,
          value: l10n.viewerElapsed(
            formatDuration(state.position),
            formatDuration(state.duration),
          ),
          increasedValue: l10n.viewerElapsed(
            formatDuration(_clamped(state.position + _step, state.duration)),
            formatDuration(state.duration),
          ),
          decreasedValue: l10n.viewerElapsed(
            formatDuration(_clamped(state.position - _step, state.duration)),
            formatDuration(state.duration),
          ),
          excludeSemantics: true,
          onIncrease: () => _seekBy(_step),
          onDecrease: () => _seekBy(-_step),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (TapUpDetails d) => widget.onSeek(
              _positionAt(_fractionAt(d.localPosition.dx, width)),
            ),
            onHorizontalDragStart: (DragStartDetails d) =>
                _beginDrag(_fractionAt(d.localPosition.dx, width)),
            onHorizontalDragUpdate: (DragUpdateDetails d) =>
                _updateDrag(_fractionAt(d.localPosition.dx, width)),
            onHorizontalDragEnd: (DragEndDetails d) {
              widget.onSeek(_positionAt(_dragFraction));
              _endDrag();
            },
            onHorizontalDragCancel: _endDrag,
            child: SizedBox(
              height: AppSizes.touchTarget,
              child: Stack(
                alignment: AlignmentDirectional.centerStart,
                clipBehavior: Clip.none,
                children: <Widget>[
                  SizedBox(
                    height: trackHeight,
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.onScrim.withValues(alpha: 0.3),
                        borderRadius: AppRadii.pillRadius,
                      ),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: SizedBox(
                      height: trackHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.onScrim,
                          borderRadius: AppRadii.pillRadius,
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: thumbX,
                    child: SizedBox(
                      width: AppSizes.scrubThumb,
                      height: AppSizes.scrubThumb,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.onScrim,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
