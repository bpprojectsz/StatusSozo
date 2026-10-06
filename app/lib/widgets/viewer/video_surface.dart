import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:statussozo/core/contracts/video_playback.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/widgets/primitives/loading_indicator.dart';
import 'package:statussozo/widgets/primitives/secondary_button.dart';

/// Builds the controls for a live session. It is rebuilt whenever the session
/// state changes, so callers never subscribe to a notifier that may be
/// disposed.
typedef VideoControlsBuilder =
    Widget Function(
      BuildContext context,
      VideoSession session,
      VideoState state,
    );

/// A video page.
///
/// A [VideoSession] exists only while [active] is true and is disposed the
/// moment it is not. Across all surfaces at most one session is alive at a
/// time: starting a session first disposes the previous one. It shows the
/// [poster] and a loading indicator until the video is ready, autoplays, and
/// shows a localised error with a retry on failure.
class VideoSurface extends StatefulWidget {
  const VideoSurface({
    required this.uri,
    required this.factory,
    required this.active,
    super.key,
    this.poster,
    this.onTap,
    this.controlsBuilder,
  });

  final String uri;
  final VideoSessionFactory factory;
  final bool active;
  final Widget? poster;
  final VoidCallback? onTap;
  final VideoControlsBuilder? controlsBuilder;

  /// Forgets the surface that owns the live session. For tests only.
  @visibleForTesting
  static void debugReset() => _VideoSurfaceState._current = null;

  @override
  State<VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<VideoSurface> {
  static _VideoSurfaceState? _current;

  VideoSession? _session;
  VideoState _state = const VideoState();
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _start();
    }
  }

  @override
  void didUpdateWidget(VideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) {
      _stop();
    } else if (!oldWidget.active ||
        oldWidget.uri != widget.uri ||
        !identical(oldWidget.factory, widget.factory)) {
      _stop();
      _start();
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _start() {
    final _VideoSurfaceState? prior = _current;
    if (prior != null && !identical(prior, this)) {
      prior._stop(rebuild: true);
    }
    _current = this;
    final VideoSession session = widget.factory.create(widget.uri);
    _session = session;
    final int generation = ++_generation;
    session.state.addListener(_onState);
    unawaited(_run(session, generation));
  }

  Future<void> _run(VideoSession session, int generation) async {
    // Let the current build finish before the session can notify.
    await Future<void>.value();
    if (!_isCurrent(session, generation)) {
      return;
    }
    await session.initialise();
    if (!_isCurrent(session, generation)) {
      return;
    }
    final VideoState state = session.state.value;
    if (state.initialised && !state.hasError) {
      await session.play();
    }
  }

  bool _isCurrent(VideoSession session, int generation) =>
      mounted && identical(_session, session) && _generation == generation;

  void _onState() {
    final VideoSession? session = _session;
    if (session == null || !mounted) {
      return;
    }
    setState(() => _state = session.state.value); // ui-local
  }

  /// Disposes the session. When called from another surface during a build,
  /// [rebuild] defers the rebuild until the build has finished.
  void _stop({bool rebuild = false}) {
    if (identical(_current, this)) {
      _current = null;
    }
    final VideoSession? session = _session;
    if (session == null) {
      return;
    }
    _session = null;
    _generation++;
    session.state.removeListener(_onState);
    session.dispose();
    _state = const VideoState();
    if (rebuild) {
      scheduleMicrotask(() {
        if (mounted) {
          setState(() {}); // ui-local
        }
      });
    }
  }

  void _retry() {
    _stop();
    _start();
    setState(() {}); // ui-local
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppTextStyles styles = AppTextStyles.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final VideoSession? session = _session;
    final VideoState state = _state;
    final Widget? poster = widget.poster;
    final VideoControlsBuilder? controls = widget.controlsBuilder;

    final bool ready = session != null && state.initialised && !state.hasError;
    final bool failed = session != null && state.hasError;
    final bool loading = session != null && !state.initialised && !failed;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (poster != null && !ready) poster,
          if (ready) SizedBox.expand(child: session.buildSurface()),
          if (loading)
            Center(child: AppLoadingIndicator(color: colors.onScrim)),
          if (failed)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      l10n.viewerVideoFailed,
                      textAlign: TextAlign.center,
                      style: styles.body.copyWith(color: colors.onScrim),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SecondaryButton(
                      label: l10n.commonRetry,
                      expand: false,
                      onPressed: _retry,
                    ),
                  ],
                ),
              ),
            ),
          if (ready && controls != null) controls(context, session, state),
        ],
      ),
    );
  }
}
