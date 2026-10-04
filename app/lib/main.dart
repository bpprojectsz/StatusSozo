import 'package:flutter/widgets.dart';
import 'package:statussozo/spike/spike_screen.dart';

// Temporary entry point for the E1 device check. Replaced by the real
// entry point in batch 12.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SpikeApp());
}
