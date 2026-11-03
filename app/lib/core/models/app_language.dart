import 'package:flutter/foundation.dart';

/// A language the app is translated into. The name is written in the language
/// itself, so a person can always find their own language.
@immutable
class AppLanguage {
  const AppLanguage(this.code, this.nativeName, {this.rtl = false});

  final String code;
  final String nativeName;

  /// Written right to left.
  final bool rtl;
}

/// Every language the app ships, in the order the language sheet lists them.
abstract final class AppLanguages {
  static const List<AppLanguage> all = <AppLanguage>[
    AppLanguage('en', 'English'),
    AppLanguage('es', 'Español'),
    AppLanguage('fr', 'Français'),
    AppLanguage('de', 'Deutsch'),
    AppLanguage('pt', 'Português'),
    AppLanguage('ar', 'العربية', rtl: true),
    AppLanguage('hi', 'हिन्दी'),
    AppLanguage('ja', '日本語'),
    AppLanguage('ko', '한국어'),
    AppLanguage('zh', '中文'),
    AppLanguage('he', 'עברית', rtl: true),
  ];

  static final List<String> codes = <String>[
    for (final AppLanguage l in all) l.code,
  ];

  /// The language with [code], or null when the app is not translated into it.
  static AppLanguage? byCode(String? code) {
    for (final AppLanguage language in all) {
      if (language.code == code) {
        return language;
      }
    }
    return null;
  }

  /// Whether [code] is written right to left.
  static bool isRtl(String? code) => byCode(code)?.rtl ?? false;
}
