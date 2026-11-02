import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the licenses of the two bundled fonts to Flutter's license registry,
/// so they appear on the open-source licenses screen.
void registerFontLicenses({AssetBundle? bundle}) {
  final AssetBundle source = bundle ?? rootBundle;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      <String>['Inter (font)'],
      await source.loadString('assets/fonts/OFL-Inter.txt'),
    );
    yield LicenseEntryWithLineBreaks(
      <String>['Manrope (font)'],
      await source.loadString('assets/fonts/OFL-Manrope.txt'),
    );
  });
}
