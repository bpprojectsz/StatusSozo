import 'package:flutter/foundation.dart';
import 'package:statussozo/core/contracts/settings_store.dart';
import 'package:statussozo/core/models/app_settings.dart';

/// What the settings provider publishes.
@immutable
class SettingsState {
  SettingsState({
    required this.settings,
    this.loaded = false,
    this.persistenceWarning = false,
    this.recovered = false,
  });

  final AppSettings settings;

  /// True once [SettingsProvider.load] has finished.
  final bool loaded;

  /// True while settings cannot be written to disk.
  final bool persistenceWarning;

  /// True when stored data was unreadable and defaults were used. Cleared by
  /// [SettingsProvider.consumeRecovered].
  final bool recovered;

  SettingsState copyWith({
    AppSettings? settings,
    bool? loaded,
    bool? persistenceWarning,
    bool? recovered,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      loaded: loaded ?? this.loaded,
      persistenceWarning: persistenceWarning ?? this.persistenceWarning,
      recovered: recovered ?? this.recovered,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SettingsState &&
      other.settings == settings &&
      other.loaded == loaded &&
      other.persistenceWarning == persistenceWarning &&
      other.recovered == recovered;

  @override
  int get hashCode =>
      Object.hash(settings, loaded, persistenceWarning, recovered);
}

/// Source of truth for persisted settings.
class SettingsProvider extends ValueNotifier<SettingsState> {
  SettingsProvider(this._store)
    : super(SettingsState(settings: AppSettings.defaults()));

  final SettingsStore _store;
  Future<void> _pending = Future<void>.value();
  bool _disposed = false;

  AppSettings get settings => value.settings;

  /// Loads from the store. Call once at startup, before any [update].
  Future<void> load() async {
    final StoredSettings stored = await _store.load();
    if (_disposed) {
      return;
    }
    value = SettingsState(
      settings: stored.settings,
      loaded: true,
      persistenceWarning: !stored.persistenceAvailable,
      recovered: stored.recovered,
    );
  }

  /// Applies [change] in memory first, so the UI never waits on disk, then
  /// saves. The returned future completes when the write has finished. A failed
  /// write sets [SettingsState.persistenceWarning] and keeps the in-memory
  /// value. Writes are serialised and always store the latest settings.
  Future<void> update(AppSettings Function(AppSettings current) change) {
    value = value.copyWith(settings: change(value.settings));
    final Future<void> write = _pending.then((_) => _persist());
    _pending = write;
    return write;
  }

  Future<void> _persist() async {
    final bool ok = await _store.save(value.settings);
    if (_disposed) {
      return;
    }
    if (!ok && !value.persistenceWarning) {
      value = value.copyWith(persistenceWarning: true);
    } else if (ok && value.persistenceWarning) {
      value = value.copyWith(persistenceWarning: false);
    }
  }

  /// Returns true exactly once after a recovery, so its toast fires once.
  bool consumeRecovered() {
    if (!value.recovered) {
      return false;
    }
    value = value.copyWith(recovered: false);
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
