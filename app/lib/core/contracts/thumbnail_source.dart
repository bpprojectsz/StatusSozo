import 'dart:typed_data';

import 'package:statussozo/core/models/viewable_media.dart';
import 'package:statussozo/core/result.dart';

/// Port for pixels.
abstract interface class ThumbnailSource {
  /// JPEG bytes no larger than [px] on the longest edge, or null when the file
  /// cannot be decoded.
  Future<Uint8List?> thumbnail(ViewableMedia media, int px);

  /// Full-size bytes for the viewer.
  Future<Result<Uint8List>> readImage(ViewableMedia media);
}
