// LogScrubber with CJK and other non-ASCII text between words (v0.5.0 plan
// Task 0.1): a run of 4 or more English or French list words is redacted
// whatever joins the words, as long as it is not a Latin letter or more
// than one 1-2 digit list number: CJK and fullwidth punctuation, Han or kana
// glued to the words, circled, Han and non-ASCII list numbers, symbols and
// emoji. v0.4.0 let
// "abandon、ability、able、about" through.

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/wordlists.dart';
import 'package:signet/core/logging/log_scrubber.dart';

void main() {
  const en = [
    'abandon', 'ability', 'able', 'about', //
    'above', 'absent', 'absorb', 'abstract',
  ];
  // French words that are not also English words, accented ones first.
  final frWords = [
    for (final w in WordList.french.words)
      if (!WordList.english.contains(w)) w,
  ];
  final fr = [
    ...frWords.where((w) => w.contains('é')).take(4),
    ...frWords.where((w) => !w.contains('é')).take(4),
  ];

  void expectGone(String out, List<String> words) {
    final lower = out.toLowerCase();
    for (final w in words) {
      expect(lower, isNot(contains(w)), reason: 'leaked "$w" in: $out');
    }
  }

  String circled(int i) => String.fromCharCode(0x2460 + i);
  String fullwidthDigit(int i) => String.fromCharCode(0xFF11 + i);
  const hanNumerals = ['一', '二', '三', '四', '五', '六', '七', '八'];

  final runs = <String, String Function(List<String>)>{
    // CJK punctuation.
    'enumeration commas 、': (w) => w.join('、'),
    'fullwidth commas ，': (w) => w.join('，'),
    'ideographic full stops 。': (w) => w.join('。'),
    'fullwidth full stops ．': (w) => w.join('．'),
    'fullwidth semicolons ；': (w) => w.join('；'),
    'fullwidth colons ：': (w) => w.join('：'),
    'ideographic spaces': (w) => w.join('　'),
    'fullwidth parentheses': (w) => w.map((x) => '（$x）').join(),
    'fullwidth square brackets and braces': (w) =>
        w.map((x) => '［$x］｛｝').join(),
    'corner brackets 「」': (w) => w.map((x) => '「$x」').join(),
    'white corner brackets 『』': (w) => w.map((x) => '『$x』').join(),
    'angle brackets 《》': (w) => w.map((x) => '《$x》').join(),
    'single angle brackets 〈〉': (w) => w.map((x) => '〈$x〉').join(),
    'lenticular brackets 【】 and 〖〗': (w) =>
        w.map((x) => '【$x】〖〗').join(),
    'tortoise shell brackets 〔〕': (w) => w.map((x) => '〔$x〕').join(),
    'double prime quotes 〝〞': (w) => w.map((x) => '〝$x〞').join(),
    'katakana middle dots ・': (w) => w.join('・'),
    'halfwidth katakana middle dots ･': (w) => w.join('･'),
    'halfwidth punctuation ｡､｢｣': (w) => w.map((x) => '｢$x｣').join('､'),
    'hyphenation points ‧': (w) => w.join('‧'),
    'fullwidth exclamation marks': (w) => w.join('！'),
    'fullwidth question marks': (w) => w.join('？'),
    'wave dashes 〜': (w) => w.join('〜'),
    'fullwidth tildes ～': (w) => w.join('～'),
    'fullwidth hyphens, slashes and bars': (w) =>
        '${w[0]}－${w[1]}／${w[2]}｜${w.skip(3).join('－')}',
    'small form punctuation ﹑﹒﹔': (w) => w.join('﹑﹒﹔'),
    'vertical forms ︑': (w) => w.join('︑'),
    // Han and kana glued to the words.
    'Han conjunction 和 glued between words': (w) => w.join('和'),
    'kana particle と glued between words': (w) => w.join('と'),
    'Han text glued before the run': (w) => '验证码${w.join(' ')}',
    'Japanese sentence around the run': (w) => 'コードは${w.join(' ')}です',
    // List numbers.
    'fullwidth numbers, one per line': (w) => [
          for (var i = 0; i < w.length; i++) '${fullwidthDigit(i)}．${w[i]}'
        ].join('\n'),
    'fullwidth numbers with ）': (w) => [
          for (var i = 0; i < w.length; i++) '${fullwidthDigit(i)}）${w[i]}'
        ].join(' '),
    'Arabic-Indic numbers': (w) => [
          for (var i = 0; i < w.length; i++)
            '${String.fromCharCode(0x0661 + i)} ${w[i]}'
        ].join(' '),
    'Devanagari numbers': (w) => [
          for (var i = 0; i < w.length; i++)
            '${String.fromCharCode(0x0967 + i)}. ${w[i]}'
        ].join(' '),
    'Thai numbers': (w) => [
          for (var i = 0; i < w.length; i++)
            '${String.fromCharCode(0x0E51 + i)} ${w[i]}'
        ].join(' '),
    'NFD kana glued before the run': (w) =>
        'キーワート\u3099${w.join('、')}',
    'circled numbers': (w) =>
        [for (var i = 0; i < w.length; i++) '${circled(i)}${w[i]}'].join(' '),
    'Han numerals with 、': (w) => [
          for (var i = 0; i < w.length; i++) '${hanNumerals[i]}、${w[i]}'
        ].join('\n'),
    // CJK commas before a list-final "and".
    'fullwidth commas and a final "and"': (w) =>
        '${w.sublist(0, w.length - 1).join('，')} and ${w.last}',
    'vertical commas and a final "and"': (w) =>
        '${w.sublist(0, w.length - 1).join('︑')} and ${w.last}',
    'enumeration commas and a final "and"': (w) =>
        '${w.sublist(0, w.length - 1).join('、')} and ${w.last}',
    // Symbols, bullets and emoji (same gap, found in review).
    'ASCII exclamation and question marks': (w) => w.join('?! '),
    'markdown bullets': (w) => w.map((x) => '* $x').join('\n'),
    'bullets •': (w) => w.map((x) => '• $x').join('\n'),
    'backticks': (w) => w.map((x) => '`$x`').join(' '),
    'ampersands, equals, hashes, angle brackets': (w) =>
        '${w[0]}&${w[1]}=${w[2]}#<${w.skip(3).join('>')}',
    'Unicode hyphens and minus ‐‑−': (w) => w.join('‐‑−'),
    'emoji': (w) => w.join(' 🔑 '),
    'variation selector after each word': (w) =>
        w.map((x) => '$x️').join(' '),
  };

  for (final MapEntry(key: style, value: render) in runs.entries) {
    for (final (name, words) in [('English', en), ('French', fr)]) {
      test('4 $name words, $style', () {
        final w = words.take(4).toList();
        expectGone(LogScrubber.scrub('words: ${render(w)}'), w);
      });
      test('8 $name words, $style', () {
        expectGone(LogScrubber.scrub('words: ${render(words)}'), words);
      });
    }
  }

  test('a longer number between list words breaks the run', () {
    const line = 'able 123456 about、above、absent';
    expect(LogScrubber.scrub(line), line);
  });

  test('fullwidth Latin words are recognised', () {
    String wide(String w) => String.fromCharCodes(
        w.codeUnits.map((c) => c >= 0x61 && c <= 0x7A ? c + 0xFEE0 : c));
    final line = en.take(4).map(wide).join('　');
    final out = LogScrubber.scrub(line);
    for (final w in en.take(4)) {
      expect(out, isNot(contains(wide(w))), reason: out);
    }
  });

  test('3 list words joined by CJK punctuation pass', () {
    const line = 'about、able、above';
    expect(LogScrubber.scrub(line), line);
  });

  test('3 list words in Chinese prose pass', () {
    const line = '请点击「about」，然后选择「able」或「above」。';
    expect(LogScrubber.scrub(line), line);
  });

  // The accepted cost: Chinese text between English words separates, so 4
  // list words scattered through one Chinese line are redacted.
  test('4 list words scattered through Chinese prose are redacted', () {
    const line = '请点击「about」，然后选择「able」或「above」，再按 absent。';
    expectGone(LogScrubber.scrub(line), ['about', 'able', 'above', 'absent']);
  });

  test('a long unspaced CJK line with a redaction scrubs quickly', () {
    final line = '${'验证码' * 7000}${en.take(4).join('、')}${'验证码' * 7000}';
    final sw = Stopwatch()..start();
    final out = LogScrubber.scrub(line);
    sw.stop();
    expectGone(out, en.take(4).toList());
    // Quadratic before the fix: about 10 s for 8,000 characters on a
    // desktop. Linear now: milliseconds. The bound only catches the
    // quadratic case.
    expect(sw.elapsedMilliseconds, lessThan(5000));
  });

  test('list words split by a word of no list pass', () {
    expect(WordList.english.contains('signet'), isFalse);
    const line = 'able、about、above、signet、absent、absorb';
    expect(LogScrubber.scrub(line), line);
  });
}
