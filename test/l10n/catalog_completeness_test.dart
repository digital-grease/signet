// Every catalog translates every key, with the same placeholders (v0.5.0
// release gate, plan Task 5.1: zero untranslated keys). Falling back to
// English silently would put English security copy in a Chinese UI.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// The placeholders English declares for [key] that its text uses.
Set<String> _declared(Map<String, dynamic> en, String key) {
  final meta = en['@$key'];
  final declared = meta is Map ? meta['placeholders'] : null;
  if (declared is! Map) return const <String>{};
  final text = en[key] as String;
  return {
    for (final name in declared.keys.cast<String>())
      if (text.contains('{$name')) name,
  };
}

void main() {
  final en = _arb('lib/l10n/app_en.arb');
  final keys = [for (final k in en.keys) if (!k.startsWith('@')) k];
  final catalogs = Directory('lib/l10n')
      .listSync()
      .whereType<File>()
      .map((f) => f.path)
      .where((p) => p.endsWith('.arb') && !p.endsWith('app_en.arb'))
      .toList()
    ..sort();

  test('there is more than one catalog', () {
    expect(catalogs, isNotEmpty);
  });

  for (final path in catalogs) {
    group(path, () {
      final arb = _arb(path);

      test('has every key', () {
        expect([for (final k in keys) if (!arb.containsKey(k)) k], isEmpty);
      });

      test('has no key English lacks', () {
        expect(
          [for (final k in arb.keys) if (!k.startsWith('@') && !en.containsKey(k)) k],
          isEmpty,
        );
      });

      test('keeps every placeholder', () {
        for (final k in keys) {
          final v = arb[k];
          if (v is! String) continue;
          for (final name in _declared(en, k)) {
            expect(v, contains('{$name'), reason: '$k lost {$name}');
          }
        }
      });
    });
  }
}
