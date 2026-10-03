import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/result.dart';

/// Port for the gallery folders the app saves into.
abstract interface class SavedRepository {
  /// Lists the items this app has saved.
  Future<Result<List<SavedItem>>> list();

  /// Copies [item] into the gallery.
  Future<Result<SavedItem>> save(StatusItem item);

  /// Removes a saved item from the gallery.
  Future<Result<void>> delete(SavedItem item);
}
