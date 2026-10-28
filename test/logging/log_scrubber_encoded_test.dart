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
