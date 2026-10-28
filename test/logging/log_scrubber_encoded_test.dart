// LogScrubber and list words behind escapes, entities, markup, letter list
// markers, ligatures and joiners (v0.5.0 plan Task 0.6): the Latin pass
// reads them through the decoded view the zh-1 pass uses, and redacts the
// original text, escapes and all.

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/wordlists.dart';
import 'package:signet/core/logging/log_scrubber.dart';

void main() {
  const en = ['abandon', 'ability', 'able', 'about'];
  final fr = [
    for (final w in WordList.french.words)
      if (!WordList.english.contains(w) && w.contains('é')) w,
  ].take(4).toList();

  void expectGone(String input, List<String> words) {
    final out = LogScrubber.scrub(input);
    final lower = out.toLowerCase();
    for (final w in words) {
      expect(lower, isNot(contains(w)), reason: '$input -> $out');
    }
    expect(out, contains('[redacted:'), reason: '$input -> $out');
  }

  final joiners = <String, String>{
    r'\n': r'\n',
    r'\r\n': r'\r\n',
    r'\t': r'\t',
    r'\\n (escaped twice)': r'\\n',
    r'、': r'、',
    r'\u000A': r'\u000A',
    '%0A': '%0A',
    '%20': '%20',
    '%E3%80%81': '%E3%80%81',
    '&nbsp;': '&nbsp;',
    '&#12289;': '&#12289;',
    '<br>': '<br>',
    '<br />': '<br />',
    // From the review of the first version:
    '&nbsp without its semicolon': '&nbsp',
    '&#160 without its semicolon': '&#160',
    '&mdash;': ' &mdash; ',
    '&middot;': '&middot;',
    '&NewLine;': '&NewLine;',
    '</p><p>': '</p><p>',
    '</li><li>': '</li><li>',
    '<br clear="all">': '<br clear="all">',
    r'\x20': r'\x20',
    r'\x0A': r'\x0A',
    r'\f': r'\f',
    r'\v': r'\v',
    r'\012 (octal)': r'\012',
    r'\U0000000A': r'\U0000000A',
    '%u000A': '%u000A',
    '&amp;nbsp; (encoded twice)': '&amp;nbsp;',
    '&lt;br&gt; (encoded twice)': '&lt;br&gt;',
    '%250A (encoded twice)': '%250A',
  };

  for (final MapEntry(key: name, value: joiner) in joiners.entries) {
    test('words joined by $name', () {
      expectGone(en.join(joiner), en);
      expectGone("'${en.join(joiner)}'", en);
      expectGone('words: ${fr.join(joiner)}', fr);
    });
  }

  test('letter and Roman-numeral list markers', () {
    for (final markers in [
      ['a)', 'b)', 'c)', 'd)'].map((m) => '$m\u200B').toList(),
      ['\uFF41）', '\uFF42）', '\uFF43）', '\uFF44）'],
      ['[a]', '[b]', '[c]', '[d]'],
      ['a:', 'b:', 'c:', 'd:'],
      ['*a)', '*b)', '*c)', '*d)'],
      ['\u2022a)', '\u2022b)', '\u2022c)', '\u2022d)'],
      ['I.', 'II.', 'III.', 'IV.'],
      ['i)', 'ii)', 'iii)', 'iv)'],
      ['a)', 'b)', 'c)', 'd)'],
      ['A.', 'B.', 'C.', 'D.'],
      ['Ⅰ.', 'Ⅱ.', 'Ⅲ.', 'Ⅳ.'],
    ]) {
      expectGone(
          [for (var i = 0; i < 4; i++) '${markers[i]} ${en[i]}'].join('\n'),
          en);
    }
  });

  test('markers glued to the word', () {
    expectGone(
        [for (var i = 0; i < 4; i++) '${'abcd'[i]})${en[i]}'].join('\n'), en);
    expectGone(
        [for (var i = 0; i < 4; i++) '${'abcd'[i]}.${en[i]}'].join('\n'), en);
  });

  test('an HTML list of words', () {
    expectGone('<ul>${en.map((w) => '<li>$w</li>').join()}</ul>', en);
    expectGone('<ol>${[...en, 'above', 'absent', 'absorb', 'abstract'].map((w) => '<li>$w</li>').join()}</ol>',
        [...en, 'above', 'absent', 'absorb', 'abstract']);
  });

  test('joiners inside words, as entities and inline tags', () {
    expectGone(en.map((w) => '${w.substring(0, 3)}&shy;${w.substring(3)}').join(' '), en);
    expectGone(en.map((w) => '${w.substring(0, 3)}<wbr>${w.substring(3)}').join(' '), en);
    expectGone(en.map((w) => '<b>${w.substring(0, 3)}</b>${w.substring(3)}').join(' '), en);
  });

  test('French accents written as entities', () {
    final escaped = [for (final w in fr) w.replaceAll('é', '&eacute;')];
    expectGone(escaped.join(' '), [...fr, ...escaped]);
    expectGone(escaped.join('&nbsp;'), [...fr, ...escaped]);
  });

  test('the tail of a run is found even when the head was found first', () {
    const eight = ['abandon', 'ability', 'able', 'about', 'above', 'absent', 'absorb', 'abstract'];
    for (final split in [5, 6]) {
      final input = '${eight.take(split).join(' ')}\\n${eight.skip(split).join(' ')}';
      expectGone(input, eight);
    }
  });

  test('a colon after u does not glue two words', () {
    expectGone(r'abandon\nmenu:ability\nable', ['abandon', 'menu', 'ability', 'able']);
  });

  test('decoding never invents a code path around the words', () {
    expectGone('package:x%2Fabandon%2Fability%2Fable%2Fabout.dart', en);
  });

  test('a long run of backslashes is quick', () {
    final sw = Stopwatch()..start();
    LogScrubber.scrub('\\' * 100000);
    LogScrubber.scrub('${'\\' * 50000}n abandon');
    expect(sw.elapsedMilliseconds, lessThan(3000));
  });

  test('ligatures from a PDF copy', () {
    final fi = [
      for (final w in WordList.english.words)
        if (w.contains('fi')) w,
    ].take(4).toList();
    expect(fi, hasLength(4));
    expectGone(fi.map((w) => w.replaceFirst('fi', 'ﬁ')).join(' '), [
      for (final w in fi) w.replaceFirst('fi', 'ﬁ'),
      ...fi,
    ]);
  });

  test('joiners inside a word', () {
    for (final joiner in ['͏', '᠎']) {
      final words = [for (final w in en) '${w.substring(0, 3)}$joiner${w.substring(3)}'];
      final out = LogScrubber.scrub(words.join(' '));
      for (final w in en) {
        expect(out.replaceAll(joiner, ''), isNot(contains(w)), reason: out);
      }
    }
  });

  test('3 words behind escapes are still left alone', () {
    final input = en.take(3).join(r'\n');
    expect(LogScrubber.scrub(input), input);
  });

  test('a sentence with a single letter is not a list', () {
    const input = 'I need a coffee before the meeting.';
    expect(LogScrubber.scrub(input), input);
  });
}
