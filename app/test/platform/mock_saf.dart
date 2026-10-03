// Test helper: a scriptable stand-in for the native side of the SAF channel.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/platform/saf_channel.dart';

class MockSaf {
  MockSaf() {
    TestWidgetsFlutterBinding.ensureInitialized();
  }

  final MethodChannel channel = const MethodChannel(SafChannel.channelName);

  /// Every call received, in order.
  final List<MethodCall> calls = <MethodCall>[];

  /// Produces the reply for a call. Throw a [PlatformException] to simulate a
  /// native error. Null means every call returns null.
  Object? Function(MethodCall call)? responder;

  List<String> get methods =>
      calls.map((MethodCall call) => call.method).toList();

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          final Object? Function(MethodCall call)? reply = responder;
          return reply?.call(call);
        });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  }

  void reset() {
    calls.clear();
    responder = null;
  }
}
