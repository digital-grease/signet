// zh-1, the frozen Chinese word list (plan Task 2.5; spike
// .devloop/spikes/chinese-words.md "Checked-in list"). The checksum is the
// trust anchor: tool/zh_wordlist/freeze.py prints the same digest, and any
// change to the list is a new list id, never an edit.

import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/zh_wordlist.dart';

/// SHA-256 of the spec serialization: UTF-8, NFC, one line per index in
/// index order, fields joined by U+0009, multi-valued fields by U+002C, LF.
const _frozenSha256 =
    '13c5f616df16fb69bbe4e2332f17cf071ccb85db6be2734b2a1f078696203dc0';

String _serialize(List<ZhWord> list) => list
    .map((w) => '${[
          w.simplified,
          w.traditional,
          w.otherForms.join(','),
          w.pinyin,
          w.zhuyin,
          w.key,
          w.readings.join(','),
        ].join('\t')}\n')
    .join();

Future<String> _sha256Hex(String s) async {
  final hash = await Sha256().hash(utf8.encode(s));
  return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Tone-marked vowels (precomposed) to their base letter; ü stays ü.
const _toneless = {
  'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a', //
  'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e', //
  'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i', //
  'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o', //
  'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u', //
  'ǖ': 'ü', 'ǘ': 'ü', 'ǚ': 'ü', 'ǜ': 'ü', //
};

String _keyOf(String pinyin) => pinyin
    .split('')
    .map((c) => _toneless[c] ?? c)
    .join()
    .replaceAll('ü', 'v');

bool _isHan(int rune) =>
    (rune >= 0x4E00 && rune <= 0x9FFF) || (rune >= 0x3400 && rune <= 0x4DBF);

void main() {
  test('has 2048 entries and matches the frozen checksum', () async {
    expect(zhWordlist, hasLength(2048));
    expect(await _sha256Hex(_serialize(zhWordlist)), _frozenSha256);
  });

  test('every written form names one entry, across scripts', () {
    final owner = <String, int>{};
    for (var i = 0; i < zhWordlist.length; i++) {
      final w = zhWordlist[i];
      for (final f in {w.simplified, w.traditional, ...w.otherForms}) {
        expect(owner.putIfAbsent(f, () => i), i,
            reason: '$f is a form of entries ${owner[f]} and $i');
      }
    }
  });

  test('keys are unique, follow the pinyin and set the order', () {
    final keys = zhWordlist.map((w) => w.key).toList();
    expect(keys.toSet(), hasLength(keys.length));
    for (var i = 1; i < keys.length; i++) {
      expect(keys[i - 1].compareTo(keys[i]), lessThan(0),
          reason: '${keys[i - 1]} before ${keys[i]}');
    }
    for (final w in zhWordlist) {
      expect(w.key, _keyOf(w.pinyin), reason: w.simplified);
      expect(RegExp(r'^[a-z]+( [a-z]+){1,2}$').hasMatch(w.key), isTrue,
          reason: w.key);
      expect(w.readings, [w.key], reason: w.simplified);
    }
  });

  test('two or three Han characters, one syllable each in pinyin and Zhuyin',
      () {
    for (final w in zhWordlist) {
      final n = w.simplified.runes.length;
      expect(n, inInclusiveRange(2, 3), reason: w.simplified);
      for (final f in [w.simplified, w.traditional, ...w.otherForms]) {
        expect(f.runes.length, n, reason: f);
        expect(f.runes.every(_isHan), isTrue, reason: f);
      }
      expect(w.pinyin.split(' '), hasLength(n), reason: w.pinyin);
      expect(w.zhuyin.split(' '), hasLength(n), reason: w.zhuyin);
    }
  });

  test('stored precomposed: no combining marks in any field', () {
    final combining = RegExp('[̀-ͯ]');
    for (final w in zhWordlist) {
      expect(combining.hasMatch(_serialize([w])), isFalse,
          reason: w.simplified);
    }
  });
}
