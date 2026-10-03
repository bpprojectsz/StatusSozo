import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:statussozo/core/contracts/video_playback.dart';
import 'package:statussozo/utils/app_log.dart';
import 'package:video_player/video_player.dart';

/// [VideoSession] over `video_player`, playing straight from a content URI
/// (Android only, which matches the app's target).
class VideoPlayerSession implements VideoSession {
  VideoPlayerSession(String uri, {VideoPlayerController? controller})
    : _controller = controller ?? VideoPlayerController.contentUri(Uri.parse(uri));

  final VideoPlayerController _controller;
  final ValueNotifier<VideoState> _state = ValueNotifier<VideoState>(
    const VideoState(),
  );
  bool _disposed = false;

  /// Maps a controller value to a [VideoState].
  @visibleForTesting
  static VideoState stateFromValue(VideoPlayerValue value) {
    final bool ready = value.isInitialized;
    final bool ended =
        ready &&
        value.duration > Duration.zero &&
        value.position >= value.duration;
    return VideoState(
      initialised: ready,
      playing: value.isPlaying && !ended,
      position: value.position,
      duration: value.duration,
      ended: ended,
      hasError: value.hasError,
    );
  }

  @override
  ValueListenable<VideoState> get state => _state;

  void _sync() {
    if (_disposed) {
      return;
    }
    _state.value = stateFromValue(_controller.value);
  }

  @override
  Future<void> initialise() async {
    if (_disposed) {
      return;
    }
    _controller.addListener(_sync);
    try {
      await _controller.initialize();
    } on Object catch (error) {
      AppLog.warn('video', 'could not initialise', error);
      if (!_disposed) {
        _state.value = _state.value.copyWith(hasError: true);
      }
      return;
    }
    _sync();
  }

  @override
  Future<void> play() async {
    if (_disposed || !_state.value.initialised) {
      return;
    }
    if (_state.value.ended) {
      await _controller.seekTo(Duration.zero);
    }
    await _controller.play();
  }

  @override
  Future<void> pause() async {
    if (_disposed || !_state.value.initialised) {
      return;
    }
    await _controller.pause();
  }

  @override
  Future<void> seekTo(Duration position) async {
    if (_disposed || !_state.value.initialised) {
      return;
    }
    await _controller.seekTo(position);
  }

  @override
  Widget buildSurface() {
    final double ratio = _controller.value.aspectRatio;
    return Center(
      child: AspectRatio(
        aspectRatio: ratio > 0 ? ratio : 1,
        child: VideoPlayer(_controller),
      ),
    );
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _controller.removeListener(_sync);
    unawaited(_controller.dispose());
    _state.dispose();
  }
}

/// The only place video controllers are created.
class VideoPlayerSessionFactory implements VideoSessionFactory {
  const VideoPlayerSessionFactory();

  @override
  VideoSession create(String uri) => VideoPlayerSession(uri);
}
