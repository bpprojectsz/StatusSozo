import 'package:statussozo/core/contracts/storage_space.dart';
import 'package:statussozo/platform/saf_channel.dart';

/// [StorageSpace] over the native channel.
class NativeStorageSpace implements StorageSpace {
  NativeStorageSpace(this._channel);

  final SafChannel _channel;

  @override
  Future<int?> freeBytes(StorageTarget target) => _channel.freeSpace(
    switch (target) {
      StorageTarget.gallery => 'gallery',
      StorageTarget.cache => 'cache',
    },
  );
}
