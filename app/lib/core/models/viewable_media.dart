import 'package:statussozo/core/models/media_kind.dart';

/// The shape shared by anything the grid, thumbnails and viewer can show.
abstract interface class ViewableMedia {
  String get uri;
  String get name;
  MediaKind get kind;
  String get mime;
  int get sizeBytes;
}
