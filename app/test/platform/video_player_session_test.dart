import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/contracts/video_playback.dart';
import 'package:statussozo/platform/video_player_session.dart';
import 'package:video_player/video_player.dart';

void main() {
  group('VideoPlayerSession.stateFromValue', () {
    test('an uninitialised controller is idle', () {
      final VideoState state = VideoPlayerSession.stateFromValue(
        const VideoPlayerValue(duration: Duration.zero),
      );
      expect(state.initialised, isFalse);
      expect(state.playing, isFalse);
      expect(state.ended, isFalse);
      expect(state.hasError, isFalse);
    });

    test('a playing video maps position and duration', () {
      final VideoState state = VideoPlayerSession.stateFromValue(
        const VideoPlayerValue(
          duration: Duration(seconds: 10),
          position: Duration(seconds: 3),
          isInitialized: true,
          isPlaying: true,
        ),
      );
      expect(state.initialised, isTrue);
      expect(state.playing, isTrue);
      expect(state.position, const Duration(seconds: 3));
      expect(state.duration, const Duration(seconds: 10));
      expect(state.ended, isFalse);
    });

    test('reaching the end marks it ended and not playing', () {
      final VideoState state = VideoPlayerSession.stateFromValue(
        const VideoPlayerValue(
          duration: Duration(seconds: 10),
          position: Duration(seconds: 10),
          isInitialized: true,
          isPlaying: true,
        ),
      );
      expect(state.ended, isTrue);
      expect(state.playing, isFalse);
    });

    test('an erroneous controller reports an error', () {
      final VideoState state = VideoPlayerSession.stateFromValue(
        const VideoPlayerValue.erroneous('boom'),
      );
      expect(state.hasError, isTrue);
    });
  });
}
