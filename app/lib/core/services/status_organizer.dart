import 'package:statussozo/core/models/media_kind.dart';
import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/core/models/status_item.dart';

/// Pure list logic.
abstract final class StatusOrganizer {
  /// A new list, newest first. Ties are ordered by name descending, then by
  /// URI, so the order is fully deterministic.
  static List<StatusItem> newestFirst(List<StatusItem> items) {
    final List<StatusItem> sorted = List<StatusItem>.of(items);
    sorted.sort((StatusItem a, StatusItem b) {
      final int byTime = b.modifiedMs.compareTo(a.modifiedMs);
      if (byTime != 0) {
        return byTime;
      }
      final int byName = b.name.compareTo(a.name);
      if (byName != 0) {
        return byName;
      }
      return a.uri.compareTo(b.uri);
    });
    return sorted;
  }

  static List<StatusItem> photos(List<StatusItem> items) => items
      .where((StatusItem item) => item.kind == MediaKind.image)
      .toList(growable: false);

  static List<StatusItem> videos(List<StatusItem> items) => items
      .where((StatusItem item) => item.kind == MediaKind.video)
      .toList(growable: false);

  /// File names of saved items, used for the Saved badge and duplicate checks.
  static Set<String> savedNames(List<SavedItem> items) =>
      items.map((SavedItem item) => item.name).toSet();
}
