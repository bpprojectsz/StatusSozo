import 'package:flutter/foundation.dart';
import 'package:statussozo/core/models/json_fields.dart';
import 'package:statussozo/core/models/media_kind.dart';
import 'package:statussozo/core/models/viewable_media.dart';

/// An item in a status folder.
@immutable
class StatusItem implements ViewableMedia {
  const StatusItem({
    required this.uri,
    required this.name,
    required this.mime,
    required this.sizeBytes,
    required this.modifiedMs,
  });

  factory StatusItem.fromJson(Map<String, Object?> json) {
    return StatusItem(
      uri: readString(json, 'uri'),
      name: readString(json, 'name'),
      mime: readString(json, 'mime'),
      sizeBytes: readInt(json, 'size'),
      modifiedMs: readInt(json, 'modified'),
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

  /// Last-modified time in epoch milliseconds.
  final int modifiedMs;

  /// Stable identity used by selection.
  String get id => uri;

  @override
  MediaKind get kind => MediaKind.fromMime(mime) ?? MediaKind.image;

  StatusItem copyWith({
    String? uri,
    String? name,
    String? mime,
    int? sizeBytes,
    int? modifiedMs,
  }) {
    return StatusItem(
      uri: uri ?? this.uri,
      name: name ?? this.name,
      mime: mime ?? this.mime,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      modifiedMs: modifiedMs ?? this.modifiedMs,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'uri': uri,
    'name': name,
    'mime': mime,
    'size': sizeBytes,
    'modified': modifiedMs,
  };

  @override
  bool operator ==(Object other) =>
      other is StatusItem &&
      other.uri == uri &&
      other.name == name &&
      other.mime == mime &&
      other.sizeBytes == sizeBytes &&
      other.modifiedMs == modifiedMs;

  @override
  int get hashCode => Object.hash(uri, name, mime, sizeBytes, modifiedMs);

  @override
  String toString() => 'StatusItem($name, $mime, $sizeBytes bytes)';
}
