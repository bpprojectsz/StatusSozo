import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/app/image_cache_limit.dart';
import 'package:statussozo/core/app_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the cap is 50 MB', () {
    expect(AppConfig.imageCacheBytes, 50 * 1024 * 1024);
  });

  test('limitImageCache lowers a larger cache to the cap', () {
    final ImageCache cache = ImageCache()
      ..maximumSizeBytes = 100 * 1024 * 1024;
    limitImageCache(cache);
    expect(cache.maximumSizeBytes, AppConfig.imageCacheBytes);
  });

  test('without an argument it limits the app image cache', () {
    final int before = PaintingBinding.instance.imageCache.maximumSizeBytes;
    addTearDown(
      () => PaintingBinding.instance.imageCache.maximumSizeBytes = before,
    );
    limitImageCache();
    expect(
      PaintingBinding.instance.imageCache.maximumSizeBytes,
      AppConfig.imageCacheBytes,
    );
  });
}
