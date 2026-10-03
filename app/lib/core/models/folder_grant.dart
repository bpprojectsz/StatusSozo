import 'package:flutter/foundation.dart';
import 'package:statussozo/core/models/json_fields.dart';
import 'package:statussozo/core/models/status_source.dart';

/// A persisted folder permission for one source.
@immutable
class FolderGrant {
  const FolderGrant({
    required this.source,
    required this.treeUri,
    required this.grantedAtMs,
  });

  factory FolderGrant.fromJson(Map<String, Object?> json) {
    final String sourceId = readString(json, 'source');
    final StatusSource? source = StatusSource.fromId(sourceId);
    if (source == null) {
      throw FormatException('Unknown source "$sourceId"');
    }
    return FolderGrant(
      source: source,
      treeUri: readString(json, 'treeUri'),
      grantedAtMs: readInt(json, 'grantedAt'),
    );
  }

  final StatusSource source;

  /// The tree URI returned by the system folder picker.
  final String treeUri;

  /// When the grant was made, in epoch milliseconds.
  final int grantedAtMs;

  FolderGrant copyWith({
    StatusSource? source,
    String? treeUri,
    int? grantedAtMs,
  }) {
    return FolderGrant(
      source: source ?? this.source,
      treeUri: treeUri ?? this.treeUri,
      grantedAtMs: grantedAtMs ?? this.grantedAtMs,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'source': source.id,
    'treeUri': treeUri,
    'grantedAt': grantedAtMs,
  };

  @override
  bool operator ==(Object other) =>
      other is FolderGrant &&
      other.source == source &&
      other.treeUri == treeUri &&
      other.grantedAtMs == grantedAtMs;

  @override
  int get hashCode => Object.hash(source, treeUri, grantedAtMs);

  @override
  String toString() => 'FolderGrant(${source.id})';
}
