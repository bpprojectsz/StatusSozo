import 'package:flutter/painting.dart';
import 'package:statussozo/core/app_config.dart';

/// Caps Flutter's decoded-image cache at [AppConfig.imageCacheBytes]. Called
/// once at start-up, before the first frame. [cache] is for tests.
void limitImageCache([ImageCache? cache]) {
  final ImageCache target = cache ?? PaintingBinding.instance.imageCache;
  target.maximumSizeBytes = AppConfig.imageCacheBytes;
}
