import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/utils/license_collector.dart';

void main() {
  setUp(LicenseRegistry.reset);
  tearDown(LicenseRegistry.reset);

  test('groups by package, sorts by name and separates repeated licenses', () async {
    LicenseRegistry.addLicense(() async* {
      yield const LicenseEntryWithLineBreaks(<String>['zeta', 'Alpha'], 'Text one');
      yield const LicenseEntryWithLineBreaks(<String>['alpha'], 'Text two');
    });
    final List<PackageLicense> result = await collectLicenses();
    expect(result.map((PackageLicense l) => l.name), <String>[
      'alpha',
      'Alpha',
      'zeta',
    ]);
    final PackageLicense alpha = result.first;
    expect(alpha.paragraphs.map((LicenseParagraph p) => p.text), <String>[
      'Text two',
    ]);
    expect(result[1].paragraphs.single.text, 'Text one');
  });

  test('merges two entries for the same package with a blank separator', () async {
    LicenseRegistry.addLicense(() async* {
      yield const LicenseEntryWithLineBreaks(<String>['pkg'], 'First');
      yield const LicenseEntryWithLineBreaks(<String>['pkg'], 'Second');
    });
    final List<PackageLicense> result = await collectLicenses();
    expect(result.single.paragraphs.map((LicenseParagraph p) => p.text), <String>[
      'First',
      '',
      'Second',
    ]);
  });

  test('is empty when nothing is registered', () async {
    expect(await collectLicenses(), isEmpty);
  });
}
