/// Where files are about to be written.
enum StorageTarget {
  /// The shared storage that holds the gallery (saving).
  gallery,

  /// The app's cache folder (share copies).
  cache,
}

/// Port for asking how much room is left. **No method may throw.**
abstract interface class StorageSpace {
  /// Free bytes at [target], or null when it cannot be read.
  Future<int?> freeBytes(StorageTarget target);
}
