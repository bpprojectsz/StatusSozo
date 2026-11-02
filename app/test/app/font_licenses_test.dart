import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/app/font_licenses.dart';
import 'package:statussozo/utils/license_collector.dart';

class _Bundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode('licence of $key')));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(LicenseRegistry.reset);
  tearDown(LicenseRegistry.reset);

  test('registers both fonts with their licence text', () async {
    registerFontLicenses(bundle: _Bundle());
    final List<PackageLicense> result = await collectLicenses();
    expect(result.map((PackageLicense l) => l.name), <String>[
      'Inter (font)',
      'Manrope (font)',
    ]);
    expect(
      result.first.paragraphs.single.text,
      'licence of assets/fonts/OFL-Inter.txt',
    );
  });

  test('the real bundled licence files are declared and readable', () async {
    registerFontLicenses();
    final List<PackageLicense> result = await collectLicenses();
    expect(result, hasLength(2));
    for (final PackageLicense license in result) {
      expect(
        license.paragraphs.map((LicenseParagraph p) => p.text).join(' '),
        contains('SIL Open Font License'),
      );
    }
  });
}
