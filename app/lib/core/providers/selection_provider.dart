import 'package:flutter/foundation.dart';

@immutable
class SelectionState {
  SelectionState({required this.active, Set<String> ids = const <String>{}})
    : ids = Set<String>.unmodifiable(ids);

  const SelectionState.none() : active = false, ids = const <String>{};

  final bool active;
  final Set<String> ids;

  int get count => ids.length;

  bool isSelected(String id) => ids.contains(id);

  @override
  bool operator ==(Object other) =>
      other is SelectionState &&
      other.active == active &&
      setEquals(other.ids, ids);

  @override
  int get hashCode => Object.hash(active, Object.hashAllUnordered(ids));
}

/// Multi-select. Two instances exist, one for Home and one for Saved.
class SelectionProvider extends ValueNotifier<SelectionState> {
  SelectionProvider() : super(const SelectionState.none());

  /// Selects or deselects [id]. The first toggle activates selection mode and
  /// removing the last id leaves it.
  void toggle(String id) {
    final Set<String> next = <String>{...value.ids};
    if (!next.remove(id)) {
      next.add(id);
    }
    value = next.isEmpty
        ? const SelectionState.none()
        : SelectionState(active: true, ids: next);
  }

  /// Selects every id in [ids].
  void selectAll(Iterable<String> ids) {
    final Set<String> all = ids.toSet();
    value = all.isEmpty
        ? const SelectionState.none()
        : SelectionState(active: true, ids: all);
  }

  /// Leaves selection mode.
  void clear() {
    if (value.active || value.ids.isNotEmpty) {
      value = const SelectionState.none();
    }
  }

  /// Drops selected ids that no longer exist, for example after a refresh.
  void retainOnly(Iterable<String> validIds) {
    if (!value.active) {
      return;
    }
    final Set<String> valid = validIds.toSet();
    final Set<String> kept = value.ids.where(valid.contains).toSet();
    if (setEquals(kept, value.ids)) {
      return;
    }
    value = kept.isEmpty
        ? const SelectionState.none()
        : SelectionState(active: true, ids: kept);
  }
}
