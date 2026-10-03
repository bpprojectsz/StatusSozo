import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A snapshot of a video session.
@immutable
class VideoState {
  const VideoState({
    this.initialised = false,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.ended = false,
    this.hasError = false,
  });

  final bool initialised;
  final bool playing;
  final Duration position;
  final Duration duration;
  final bool ended;
  final bool hasError;

  /// Playback progress from 0 to 1.
  double get progress {
    if (duration.inMilliseconds <= 0) {
      return 0;
    }
    return (position.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  VideoState copyWith({
    bool? initialised,
    bool? playing,
    Duration? position,
    Duration? duration,
    bool? ended,
    bool? hasError,
  }) {
    return VideoState(
      initialised: initialised ?? this.initialised,
      playing: playing ?? this.playing,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      ended: ended ?? this.ended,
      hasError: hasError ?? this.hasError,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VideoState &&
      other.initialised == initialised &&
      other.playing == playing &&
      other.position == position &&
      other.duration == duration &&
      other.ended == ended &&
      other.hasError == hasError;

  @override
  int get hashCode =>
      Object.hash(initialised, playing, position, duration, ended, hasError);
}

/// One playing video. At most one is alive at a time.
abstract interface class VideoSession {
  ValueListenable<VideoState> get state;

  Future<void> initialise();

  Future<void> play();

  Future<void> pause();

  Future<void> seekTo(Duration position);

  /// The video picture. Valid after [initialise] succeeds.
  Widget buildSurface();

  /// Releases the underlying player.
  void dispose();
}

/// The only place video sessions are created.
abstract interface class VideoSessionFactory {
  VideoSession create(String uri);
}
