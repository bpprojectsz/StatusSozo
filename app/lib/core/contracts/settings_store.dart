import 'package:flutter/foundation.dart';
import 'package:statussozo/core/models/app_settings.dart';

/// What a store returns on load.
@immutable
class StoredSettings {
  const StoredSettings({
    required this.settings,
    this.recovered = false,
    this.persistenceAvailable = true,
  });

  final AppSettings settings;

  /// True when stored data was unreadable and defaults were used instead.
  final bool recovered;

  /// False when the backing store itself failed; the app then keeps working
  /// in memory and warns the person.
  final bool persistenceAvailable;
}

/// Port for persistence.
abstract interface class SettingsStore {
  /// Loads settings. Never throws.
  Future<StoredSettings> load();

  /// Saves settings. Returns false on failure; never throws.
  Future<bool> save(AppSettings settings);
}
