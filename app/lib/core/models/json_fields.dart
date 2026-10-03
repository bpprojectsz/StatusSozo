/// Strict and tolerant readers for JSON-shaped maps used by the models.

/// Returns [json] [key] as a string, or throws [FormatException].
String readString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Expected a string for "$key"', value);
}

/// Returns [json] [key] as an integer, or throws [FormatException].
int readInt(Map<String, Object?> json, String key) {
  final int? value = tryReadInt(json, key);
  if (value == null) {
    throw FormatException('Expected an integer for "$key"', json[key]);
  }
  return value;
}

/// Returns [json] [key] as an integer, or null when missing or not integral.
int? tryReadInt(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is int) {
    return value;
  }
  if (value is double && value.isFinite && value == value.truncateToDouble()) {
    return value.toInt();
  }
  return null;
}

/// Returns [json] [key] as a string, or null when missing or not a string.
String? tryReadString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  return value is String ? value : null;
}

/// Copies [source] keeping only the entries that have string keys.
Map<String, Object?> stringKeyed(Map<Object?, Object?> source) {
  return <String, Object?>{
    for (final MapEntry<Object?, Object?> entry in source.entries)
      if (entry.key case final String key) key: entry.value,
  };
}
