import 'package:flutter/foundation.dart';
import 'package:statussozo/core/models/json_fields.dart';
import 'package:statussozo/core/models/media_kind.dart';
import 'package:statussozo/core/models/viewable_media.dart';

/// An item saved to the gallery.
@immutable
class SavedItem implements ViewableMedia {
  const SavedItem({
    required this.uri,
    required this.name,
    required this.mime,
    required this.sizeBytes,
    required this.savedAtMs,
  });

  factory SavedItem.fromJson(Map<String, Object?> json) {
    return SavedItem(
      uri: readString(json, 'uri'),
      name: readString(json, 'name'),
      mime: readString(json, 'mime'),
      sizeBytes: readInt(json, 'size'),
      savedAtMs: readInt(json, 'added'),
    );
  }

  @override
  final String uri;
  @override
  final String name;
  @override
  final String mime;
  @override
  final int sizeBytes;

  /// Time the item was added to the gallery, in epoch milliseconds.
  final int savedAtMs;

  /// Stable identity used by selection.
  String get id => uri;

  @override
  MediaKind get kind => MediaKind.fromMime(mime) ?? MediaKind.image;

  SavedItem copyWith({
    String? uri,
    String? name,
    String? mime,
    int? sizeBytes,
    int? savedAtMs,
  }) {
    return SavedItem(
      uri: uri ?? this.uri,
      name: name ?? this.name,
      mime: mime ?? this.mime,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      savedAtMs: savedAtMs ?? this.savedAtMs,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'uri': uri,
    'name': name,
    'mime': mime,
    'size': sizeBytes,
    'added': savedAtMs,
  };

  @override
  bool operator ==(Object other) =>
      other is SavedItem &&
      other.uri == uri &&
      other.name == name &&
      other.mime == mime &&
      other.sizeBytes == sizeBytes &&
      other.savedAtMs == savedAtMs;

  @override
  int get hashCode => Object.hash(uri, name, mime, sizeBytes, savedAtMs);

  @override
  String toString() => 'SavedItem($name, $mime, $sizeBytes bytes)';
}
