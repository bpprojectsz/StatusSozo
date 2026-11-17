import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/models/app_language.dart';

void main() {
  test('Android locales_config.xml lists exactly the shipped languages', () {
    final String xml = File(
      'android/app/src/main/res/xml/locales_config.xml',
    ).readAsStringSync();
    final List<String> listed = RegExp(
      r'<locale android:name="([^"]+)"',
    ).allMatches(xml).map((RegExpMatch m) => m.group(1)!).toList();
    expect(listed..sort(), List<String>.of(AppLanguages.codes)..sort());
  });

  test('the manifest points at locales_config', () {
    final String manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:localeConfig="@xml/locales_config"'));
  });
}
