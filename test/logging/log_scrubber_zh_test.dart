// LogScrubber and zh-1 (v0.5.0 plan Task 3.7): a run of 4 or more zh-1
// words is redacted in characters (either script, mixed, glued at either
// parity or separated), in pinyin (toneless, tone marks, tone digits,
// spaced, hyphenated or glued), in both at once, and inside \u and %
// escapes, with variation selectors and compatibility ideographs. Chinese
// prose is left alone.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/zh_wordlist.dart';
import 'package:signet/core/logging/log_scrubber.dart';

final _marker = RegExp(r'\[redacted:\d+\]');
final _han = RegExp(r'\p{Script=Han}', unicode: true);
final _latin = RegExp(r'\p{Script=Latin}', unicode: true);

/// What is left of [out] once the redactions are taken out.
String _left(String out) => out.replaceAll(_marker, '');

/// `bā gē` as `ba1 ge1`.
String _toneDigits(String pinyin) {
  const marks = {
    'ā': 'a1', 'á': 'a2', 'ǎ': 'a3', 'à': 'a4', //
    'ē': 'e1', 'é': 'e2', 'ě': 'e3', 'è': 'e4', //
    'ī': 'i1', 'í': 'i2', 'ǐ': 'i3', 'ì': 'i4', //
    'ō': 'o1', 'ó': 'o2', 'ǒ': 'o3', 'ò': 'o4', //
    'ū': 'u1', 'ú': 'u2', 'ǔ': 'u3', 'ù': 'u4', //
    'ǖ': 'v1', 'ǘ': 'v2', 'ǚ': 'v3', 'ǜ': 'v4', 'ü': 'v5',
  };
  return pinyin.split(' ').map((syllable) {
    var tone = '5';
    final base = StringBuffer();
    for (final ch in syllable.split('')) {
      final m = marks[ch];
      if (m == null) {
        base.write(ch);
      } else {
        base.write(m[0]);
        tone = m[1];
      }
    }
    return '$base$tone';
  }).join(' ');
}

/// Tone marks decomposed (NFD), as macOS and some keyboards write them.
String _nfd(String pinyin) {
  const marks = {
    'ā': 'ā', 'á': 'á', 'ǎ': 'ǎ', 'à': 'à', //
    'ē': 'ē', 'é': 'é', 'ě': 'ě', 'è': 'è', //
    'ī': 'ī', 'í': 'í', 'ǐ': 'ǐ', 'ì': 'ì', //
    'ō': 'ō', 'ó': 'ó', 'ǒ': 'ǒ', 'ò': 'ò', //
    'ū': 'ū', 'ú': 'ú', 'ǔ': 'ǔ', 'ù': 'ù', //
    'ü': 'ü', 'ǖ': 'ǖ', 'ǘ': 'ǘ', //
    'ǚ': 'ǚ', 'ǜ': 'ǜ',
  };
  return pinyin.split('').map((c) => marks[c] ?? c).join();
}

String _escaped(String text) => [
      for (final unit in text.codeUnits)
        '\\u${unit.toRadixString(16).padLeft(4, '0')}',
    ].join();

void main() {
  final random = Random(37);
  final codes = [
    for (var i = 0; i < 60; i++)
      [for (var k = 0; k < 4; k++) zhWordlist[random.nextInt(2048)]],
  ];

  final formats = <String, String Function(List<ZhWord>)>{
    'simplified, spaced': (c) => c.map((w) => w.simplified).join(' '),
    'simplified, glued': (c) => c.map((w) => w.simplified).join(),
    'traditional, glued': (c) => c.map((w) => w.traditional).join(),
    'scripts mixed': (c) => [
          for (var i = 0; i < 4; i++)
            i.isEven ? c[i].simplified : c[i].traditional,
        ].join(),
    'CJK punctuation': (c) => c.map((w) => w.simplified).join('、'),
    'fullwidth spaces': (c) => c.map((w) => w.simplified).join('　'),
    'numbered lines': (c) =>
        [for (var i = 0; i < 4; i++) '${i + 1}. ${c[i].simplified}'].join('\n'),
    'pinyin syllables': (c) => c.map((w) => w.key).join(' '),
    'pinyin words': (c) => c.map((w) => w.key.replaceAll(' ', '')).join(' '),
    'pinyin hyphens': (c) => c.map((w) => w.key.replaceAll(' ', '-')).join(' '),
    'pinyin tone marks': (c) => c.map((w) => w.pinyin).join(' '),
    'pinyin tone digits': (c) => c.map((w) => _toneDigits(w.pinyin)).join(' '),
    'pinyin tone digits glued': (c) =>
        c.map((w) => _toneDigits(w.pinyin).replaceAll(' ', '')).join(),
    'characters and pinyin': (c) => [
          for (var i = 0; i < 4; i++)
            i.isEven ? c[i].simplified : c[i].key,
        ].join(' '),
    r'\u escapes': (c) => _escaped(c.map((w) => w.simplified).join()),
    r'\u escapes, spaced': (c) =>
        c.map((w) => _escaped(w.simplified)).join(' '),
    '% escapes': (c) => Uri.encodeComponent(c.map((w) => w.simplified).join()),
    'variation selectors': (c) => c
        .map((w) => w.simplified)
        .join()
        .split('')
        .map((ch) => '$ch︀')
        .join(),
    'zero-width spaces': (c) => c.map((w) => w.simplified).join('​'),
    // From the scrubber review:
    'Han list numbers': (c) => [
          for (var i = 0; i < 4; i++) '${'一二三四'[i]}、${c[i].simplified}',
        ].join('\n'),
    'ordinal labels': (c) => [
          for (var i = 0; i < 4; i++) '第${'一二三四'[i]}个：${c[i].simplified}',
        ].join('，'),
    'list with 和': (c) => '${c.take(3).map((w) => w.simplified).join('、')}'
        '和${c[3].simplified}',
    'list with and': (c) => '${c.take(3).map((w) => w.simplified).join(', ')}'
        ' and ${c[3].simplified}',
    'numbered tone digits': (c) => [
          for (var i = 0; i < 4; i++) '${i + 1}. ${_toneDigits(c[i].pinyin)}',
        ].join('\n'),
    'tone digits, commas': (c) =>
        c.map((w) => _toneDigits(w.pinyin).replaceAll(' ', '')).join(', '),
    'NFD tone marks': (c) => c.map((w) => _nfd(w.pinyin)).join(' '),
    'NFD tone marks, uppercase': (c) =>
        c.map((w) => _nfd(w.pinyin).toUpperCase()).join(' '),
    'u: for ü': (c) => c.map((w) => w.key.replaceAll('v', 'u:')).join(', '),
    'characters spaced': (c) =>
        c.map((w) => w.simplified.split('').join(' ')).join(' '),
    'characters comma-spaced': (c) =>
        c.map((w) => w.simplified.split('').join(',')).join(','),
    'Zhuyin': (c) => c.map((w) => w.zhuyin).join(', '),
    'Zhuyin toneless, glued per word': (c) => c
        .map((w) => w.zhuyin.replaceAll(RegExp('[ˊˇˋ˙ ]'), ''))
        .join(' '),
    'HTML entities': (c) => [
          for (final r in c.map((w) => w.simplified).join().runes) '&#$r;',
        ].join(),
    'HTML hex entities': (c) => [
          for (final r in c.map((w) => w.simplified).join().runes)
            '&#x${r.toRadixString(16)};',
        ].join(),
    r'double-escaped \u': (c) =>
        _escaped(c.map((w) => w.simplified).join()).replaceAll(r'\u', r'\\u'),
  };

  group('4 zh-1 words are redacted', () {
    for (final MapEntry(key: name, value: format) in formats.entries) {
      test(name, () {
        for (final code in codes) {
          final input = format(code);
          // The label before the first word ("一、", "第一个：") stays.
          final left = _left(LogScrubber.scrub(input))
              .replaceFirst(RegExp('^第?一个?[、：]'), '');
          expect(left, isNot(contains(_han)), reason: '$input -> $left');
          expect(left, isNot(contains(_latin)), reason: '$input -> $left');
          expect(left, isNot(contains(RegExp(r'\\u[0-9a-f]{4}'))),
              reason: '$input -> $left');
          expect(left, isNot(contains(RegExp('%[0-9A-F]{2}'))),
              reason: '$input -> $left');
        }
      });
    }
  });

  test('u: is read as ü (a word with ü is in the code)', () {
    final lv = zhWordlist.firstWhere((w) => w.key.contains('v'));
    final input = [lv, ...codes.first.take(3)]
        .map((w) => _toneDigits(w.pinyin).replaceAll('v', 'u:'))
        .join(' ');
    final left = _left(LogScrubber.scrub(input));
    expect(left, isNot(contains(_latin)), reason: '$input -> $left');
  });

  test('a pinyin word an earlier pass redacted still counts in the run', () {
    // A long tone-digit word looks like base64 to the mechanical pass.
    final long = zhWordlist
        .firstWhere((w) => _toneDigits(w.pinyin).replaceAll(' ', '').length >= 16);
    for (final code in codes.take(20)) {
      final words = [...code.take(2), long, ...code.skip(2).take(2)];
      final input =
          words.map((w) => _toneDigits(w.pinyin).replaceAll(' ', '')).join(', ');
      final left = _left(LogScrubber.scrub(input));
      expect(left, isNot(contains(_latin)), reason: '$input -> $left');
      expect(left, isNot(contains(RegExp('[0-9]'))), reason: '$input -> $left');
    }
  });

  test('malformed and hostile escapes never throw', () {
    for (final input in [
      '%F4%90%80%80', '%ED%A0%80', '%C0%80', '%E0%80%80', '%F8%88%80%80%80',
      r'\u{110000}', r'\u{}', r'\uD800', '&#1114112;', '&#x;', '&#;',
    ]) {
      expect(() => LogScrubber.scrub('x $input y'), returnsNormally,
          reason: input);
    }
  });

  test('a long run of escape starts is quick', () {
    final sw = Stopwatch()..start();
    LogScrubber.scrub(r'\u{' * 200000);
    LogScrubber.scrub('${r'\u{1' * 100000}}');
    LogScrubber.scrub('&#' * 200000);
    LogScrubber.scrub('%E5' * 200000);
    expect(sw.elapsedMilliseconds, lessThan(5000));
  });

  test('at either parity: text glued before the words stays', () {
    for (final code in codes) {
      final words = code.map((w) => w.simplified).join();
      for (final before in ['码', '验证码：', '码 ']) {
        final out = LogScrubber.scrub('$before$words');
        expect(_left(out), before, reason: out);
      }
    }
  });

  test('glued to Latin text', () {
    for (final code in codes) {
      final words = code.map((w) => w.simplified).join();
      final out = LogScrubber.scrub('error$words.done');
      expect(_left(out), 'error.done', reason: out);
    }
  });

  test('inside a longer message', () {
    final code = codes.first.map((w) => w.simplified).join(' ');
    final out = LogScrubber.scrub('FormatException: words were $code, '
        'expected 4');
    expect(out, contains('FormatException'));
    expect(_left(out), isNot(contains(_han)));
  });

  test('a compatibility ideograph reads as the character it stands for', () {
    // U+F901 is the compatibility form of 更, in 更衣室.
    final words = ['更衣室', ...codes.first.take(3).map((w) => w.simplified)];
    final out = LogScrubber.scrub(words.join());
    expect(_left(out), isEmpty, reason: out);
  });

  test('3 words are not a run', () {
    for (final code in codes.take(10)) {
      final three = code.take(3).toList();
      for (final input in [
        three.map((w) => w.simplified).join(),
        three.map((w) => w.simplified).join(' '),
        three.map((w) => w.key).join(' '),
      ]) {
        expect(LogScrubber.scrub(input), isNot(contains(_marker)),
            reason: input);
      }
    }
  });

  test('a character that is no word breaks the run: prose', () {
    final c = codes.first.map((w) => w.simplified).toList();
    // 的 between the second and third word.
    final input = '${c[0]}${c[1]}的${c[2]}${c[3]}';
    expect(LogScrubber.scrub(input), input);
  });

  test('Chinese prose: no interface string loses a character', () {
    for (final file in ['lib/l10n/app_zh.arb', 'lib/l10n/app_zh_Hant.arb']) {
      final catalog =
          jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>;
      for (final MapEntry(:key, :value) in catalog.entries) {
        if (key.startsWith('@') || value is! String) continue;
        final out = LogScrubber.scrub(value);
        expect(_han.allMatches(out).length, _han.allMatches(value).length,
            reason: '$file $key: $out');
      }
    }
  });

  test('a long Chinese log is quick', () {
    final catalog = jsonDecode(File('lib/l10n/app_zh.arb').readAsStringSync())
        as Map<String, dynamic>;
    final prose = catalog.values.whereType<String>().join('\n');
    final text = List.filled((200000 / prose.length).ceil(), prose).join('\n');
    final unspaced = text.replaceAll(RegExp(r'\s'), '');
    final sw = Stopwatch()..start();
    LogScrubber.scrub(text);
    LogScrubber.scrub(unspaced);
    expect(sw.elapsedMilliseconds, lessThan(5000));
  });
}
