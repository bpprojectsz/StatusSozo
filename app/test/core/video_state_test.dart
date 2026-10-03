import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/contracts/video_playback.dart';

import '../fakes/fakes.dart';

void main() {
  group('VideoState', () {
    test('starts idle', () {
      const VideoState s = VideoState();
      expect(s.initialised, isFalse);
      expect(s.playing, isFalse);
      expect(s.position, Duration.zero);
      expect(s.duration, Duration.zero);
      expect(s.ended, isFalse);
      expect(s.hasError, isFalse);
    });

    test('progress is zero without a duration', () {
      expect(const VideoState(position: Duration(seconds: 3)).progress, 0);
    });

    test('progress is position over duration, clamped', () {
      expect(
        const VideoState(
          position: Duration(seconds: 5),
          duration: Duration(seconds: 10),
        ).progress,
        0.5,
      );
      expect(
        const VideoState(
          position: Duration(seconds: 15),
          duration: Duration(seconds: 10),
        ).progress,
        1,
      );
    });

    test('copyWith, equality and hash', () {
      const VideoState a = VideoState(playing: true);
      expect(a.copyWith(), a);
      expect(a.copyWith().hashCode, a.hashCode);
      expect(a.copyWith(playing: false), isNot(a));
    });
  });

  group('fake video factory', () {
    test('tracks alive sessions', () {
      final FakeVideoSessionFactory factory = FakeVideoSessionFactory();
      final VideoSession one = factory.create('content://one');
      expect(factory.alive, 1);
      final VideoSession two = factory.create('content://two');
      expect(factory.alive, 2);
      expect(factory.maxAlive, 2);
      one.dispose();
      two.dispose();
      two.dispose();
      expect(factory.alive, 0);
      expect(factory.maxAlive, 2);
    });

    test('initialise, play, pause and seek update state', () async {
      final FakeVideoSessionFactory factory = FakeVideoSessionFactory();
      final VideoSession session = factory.create('content://x');
      await session.initialise();
      expect(session.state.value.initialised, isTrue);
      await session.play();
      expect(session.state.value.playing, isTrue);
      await session.seekTo(const Duration(seconds: 4));
      expect(session.state.value.position, const Duration(seconds: 4));
      await session.pause();
      expect(session.state.value.playing, isFalse);
      session.dispose();
    });

    test('failed initialise sets hasError', () async {
      final FakeVideoSessionFactory factory = FakeVideoSessionFactory()
        ..failInitialise = true;
      final VideoSession session = factory.create('content://x');
      await session.initialise();
      expect(session.state.value.hasError, isTrue);
      session.dispose();
    });
  });
}
