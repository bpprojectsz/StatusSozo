import 'package:flutter/foundation.dart';
import 'package:statussozo/core/models/json_fields.dart';
import 'package:statussozo/core/models/media_kind.dart';
import 'package:statussozo/core/models/status_source.dart';
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
    required this.source,
  });

  /// [source] is the folder the item was read from. The native rows do not
  /// carry it, so the repository passes it; a stored `source` id is the
  /// fallback, and the standard source the last resort.
  factory StatusItem.fromJson(
    Map<String, Object?> json, {
    StatusSource? source,
  }) {
    return StatusItem(
      uri: readString(json, 'uri'),
      name: readString(json, 'name'),
      mime: readString(json, 'mime'),
      sizeBytes: readInt(json, 'size'),
      modifiedMs: readInt(json, 'modified'),
      source:
          source ??
          StatusSource.fromId(tryReadString(json, 'source')) ??
          StatusSource.standard,
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

  /// Which messaging app's folder this item lives in.
  final StatusSource source;

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
    StatusSource? source,
  }) {
    return StatusItem(
      uri: uri ?? this.uri,
      name: name ?? this.name,
      mime: mime ?? this.mime,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      modifiedMs: modifiedMs ?? this.modifiedMs,
      source: source ?? this.source,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'uri': uri,
    'name': name,
    'mime': mime,
    'size': sizeBytes,
    'modified': modifiedMs,
    'source': source.id,
  };

  @override
  bool operator ==(Object other) =>
      other is StatusItem &&
      other.uri == uri &&
      other.name == name &&
      other.mime == mime &&
      other.sizeBytes == sizeBytes &&
      other.modifiedMs == modifiedMs &&
      other.source == source;

  @override
  int get hashCode =>
      Object.hash(uri, name, mime, sizeBytes, modifiedMs, source);

  @override
  String toString() => 'StatusItem($name, $mime, $sizeBytes bytes)';
}
