import 'package:flutter/foundation.dart';

/// One package and the license text that applies to it.
@immutable
class PackageLicense {
  const PackageLicense({required this.name, required this.paragraphs});

  final String name;
  final List<LicenseParagraph> paragraphs;
}

/// Reads every license registered with Flutter (packages, the framework and
/// bundled fonts), grouped by package name and sorted by name.
Future<List<PackageLicense>> collectLicenses() async {
  final Map<String, List<LicenseParagraph>> byPackage =
      <String, List<LicenseParagraph>>{};
  await for (final LicenseEntry entry in LicenseRegistry.licenses) {
    final List<LicenseParagraph> paragraphs = entry.paragraphs.toList();
    for (final String package in entry.packages) {
      final List<LicenseParagraph> list = byPackage.putIfAbsent(
        package,
        () => <LicenseParagraph>[],
      );
      if (list.isNotEmpty) {
        // A blank paragraph separates two licenses of the same package.
        list.add(const LicenseParagraph('', 0));
      }
      list.addAll(paragraphs);
    }
  }
  final List<PackageLicense> result = <PackageLicense>[
    for (final MapEntry<String, List<LicenseParagraph>> e in byPackage.entries)
      PackageLicense(name: e.key, paragraphs: e.value),
  ]..sort(
    (PackageLicense a, PackageLicense b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );
  return result;
}
