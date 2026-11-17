import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/models/app_language.dart';

void main() {
  group('AppLanguages.resolve picks the first translated language', () {
    test('every shipped language resolves to itself', () {
      for (final String code in AppLanguages.codes) {
        expect(AppLanguages.resolve(<String>[code]), code);
      }
    });

    test('regional variants resolve by language code', () {
      // pt-BR, es-MX, zh-TW, en-GB and he-IL arrive here as their codes.
      expect(AppLanguages.resolve(<String>['pt']), 'pt');
      expect(AppLanguages.resolve(<String>['es']), 'es');
      expect(AppLanguages.resolve(<String>['zh']), 'zh');
      expect(AppLanguages.resolve(<String>['en']), 'en');
      expect(AppLanguages.resolve(<String>['he']), 'he');
    });

    test('an unsupported language alone gives English', () {
      expect(AppLanguages.resolve(<String>['sw']), 'en');
      expect(AppLanguages.resolve(<String>['xx']), 'en');
    });

    test('an unsupported language first falls through to the next', () {
      expect(AppLanguages.resolve(<String>['sw', 'fr']), 'fr');
      expect(AppLanguages.resolve(<String>['xx', 'yy', 'ar']), 'ar');
    });

    test('the phone order wins when several are supported', () {
      expect(AppLanguages.resolve(<String>['de', 'fr']), 'de');
    });

    test('an empty list gives English', () {
      expect(AppLanguages.resolve(const <String>[]), 'en');
    });
  });
}
