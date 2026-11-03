import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/models/app_language.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';

Map<String, Object?> _read(String code) {
  final File file = File('lib/l10n/app_$code.arb');
  expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
  return json.decode(file.readAsStringSync()) as Map<String, Object?>;
}

Iterable<String> _messageKeys(Map<String, Object?> arb) =>
    arb.keys.where((String k) => !k.startsWith('@'));

/// Placeholder names: ASCII identifiers directly inside braces.
Set<String> _placeholders(String message) => RegExp(
  r'\{([A-Za-z_][A-Za-z0-9_]*)\s*[,}]',
).allMatches(message).map((RegExpMatch m) => m.group(1)!).toSet();

/// The branch names of every plural block in [message].
List<List<String>> _pluralBranches(String message) {
  final List<List<String>> blocks = <List<String>>[];
  for (final RegExpMatch m in RegExp(
    r'\{\w+\s*,\s*plural\s*,',
  ).allMatches(message)) {
    int depth = 1;
    int i = m.end;
    final List<String> names = <String>[];
    final StringBuffer buffer = StringBuffer();
    while (i < message.length && depth > 0) {
      final String c = message[i];
      if (c == '{') {
        if (depth == 1) {
          names.add(buffer.toString().trim());
          buffer.clear();
        }
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 1) {
          buffer.clear();
        }
      } else if (depth == 1) {
        buffer.write(c);
      }
      i++;
    }
    blocks.add(names);
  }
  return blocks;
}

void main() {
  final Map<String, Object?> english = _read('en');
  final List<String> keys = _messageKeys(english).toList();
  const Set<String> categories = <String>{
    'zero',
    'one',
    'two',
    'few',
    'many',
    'other',
  };

  test('the app is translated into exactly the declared languages', () {
    expect(
      AppLocalizations.supportedLocales
          .map((l) => l.languageCode)
          .toList()
        ..sort(),
      (List<String>.of(AppLanguages.codes)..sort()),
    );
  });

  for (final String code in AppLanguages.codes.where((String c) => c != 'en')) {
    group('app_$code.arb', () {
      final Map<String, Object?> arb = _read(code);

      test('declares its own locale', () {
        expect(arb['@@locale'], code);
      });

      test('has exactly the English keys', () {
        expect(_messageKeys(arb).toSet(), keys.toSet());
      });

      test('has no empty or padded values', () {
        for (final String key in keys) {
          final String value = arb[key]! as String;
          expect(value, isNotEmpty, reason: key);
          expect(value, value.trim(), reason: '$key has padding');
        }
      });

      test('uses the same placeholders as English', () {
        for (final String key in keys) {
          expect(
            _placeholders(arb[key]! as String),
            _placeholders(english[key]! as String),
            reason: key,
          );
        }
      });

      test('plural blocks match English and use valid branches', () {
        for (final String key in keys) {
          final List<List<String>> mine = _pluralBranches(arb[key]! as String);
          final List<List<String>> theirs = _pluralBranches(
            english[key]! as String,
          );
          expect(mine.length, theirs.length, reason: '$key plural count');
          for (final List<String> names in mine) {
            expect(names, contains('other'), reason: key);
            for (final String name in names) {
              expect(
                categories.contains(name) || RegExp(r'^=\d+$').hasMatch(name),
                isTrue,
                reason: '$key has branch "$name"',
              );
            }
          }
        }
      });

      test('keeps the .Statuses folder name', () {
        for (final String key in <String>[
          'toastWrongFolder',
          'errorWrongFolderMessage',
        ]) {
          expect(arb[key]! as String, contains('.Statuses'), reason: key);
        }
      });
    });
  }
}
