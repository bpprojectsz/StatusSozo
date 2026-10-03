/// The two kinds of media the app handles.
enum MediaKind {
  image,
  video;

  bool get isVideo => this == MediaKind.video;

  /// Maps a MIME type to a kind, or null when it is neither an image nor a video.
  static MediaKind? fromMime(String mime) {
    final String lower = mime.toLowerCase();
    if (lower.startsWith('image/')) {
      return MediaKind.image;
    }
    if (lower.startsWith('video/')) {
      return MediaKind.video;
    }
    return null;
  }
}
