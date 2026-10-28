// LogScrubber with French words (plan Task 8.4d): a run of 4 or more words
// from any shipped list, or a mix of lists, is redacted whatever the
// accents, normalization, case or separators; 1-3 words still pass, as in
// English.

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/wordlists.dart';
import 'package:signet/core/logging/log_scrubber.dart';

void main() {
  // Accented French words that are not also English words.
  final fr = [
    for (final w in WordList.french.words)
      if ((w.contains('é') || w.contains('è')) && !WordList.english.contains(w))
        w,
  ].take(8).toList();
  const en = ['abandon', 'ability', 'able', 'about'];
  String toNfd(String w) =>
      w.replaceAll('é', 'e\u0301').replaceAll('è', 'e\u0300');

  /// No word of [words] survives, in any spelling the input used.
  void expectGone(String out, List<String> words) {
    final lower = out.toLowerCase();
    for (final w in words) {
      for (final form in {w, WordList.french.fold(w)!, toNfd(w)}) {
        expect(lower, isNot(contains(form.toLowerCase())),
            reason: 'leaked "$form" in: $out');
      }
    }
  }

  final runs = <String, String Function(List<String>)>{
    'spaces': (w) => w.join(' '),
    'accent-free': (w) => w.map((x) => WordList.french.fold(x)!).join(' '),
    'NFD': (w) => w.map(toNfd).join(' '),
    'upper case': (w) => w.map((x) => x.toUpperCase()).join(' '),
    'hyphens': (w) => w.join('-'),
    'underscores': (w) => w.join('_'),
    'commas and "et"': (w) =>
        '${w.sublist(0, w.length - 1).join(', ')} et ${w.last}',
    'numbered, one per line': (w) =>
        [for (var i = 0; i < w.length; i++) '${i + 1}. ${w[i]}'].join('\n'),
    // French typography (review finding 2026-10-20).
    'en dashes': (w) => w.join('–'),
    'em dashes': (w) => w.join('—'),
    'middle dots': (w) => w.join('·'),
    'guillemets': (w) => w.map((x) => '«\u202F$x\u202F»').join(' '),
    'curly quotes': (w) => w.map((x) => '“$x”').join(', '),
    'typographic apostrophes': (w) => w.join('’'),
    'ellipses': (w) => w.join('…'),
    'no-break spaces': (w) => w.join('\u00A0'),
    'digits glued between words': (w) =>
        [for (var i = 0; i < w.length; i++) '${w[i]}${i + 1}'].join(),
    'zero-width inside a word': (w) =>
        [w[0], '${w[1].substring(0, 2)}\u200B${w[1].substring(2)}', ...w.skip(2)]
            .join(' '),
  };

  for (final MapEntry(key: style, value: render) in runs.entries) {
    test('4 French words, $style', () {
      final words = fr.take(4).toList();
      expectGone(LogScrubber.scrub('pake: ${render(words)}'), words);
    });

    test('8 French words, $style', () {
      expectGone(LogScrubber.scrub('words = ${render(fr)}'), fr);
    });
  }

  test('an accented word glued to a long ASCII run is redacted whole', () {
    // The base64 rule's ASCII boundary fell at the accent, leaving "élè"
    // (review finding 2026-10-20).
    const glued = 'élève1abaisser2abdiquer3abeille';
    final out = LogScrubber.scrub('w=$glued');
    expect(out, isNot(contains('é')));
    expect(out, isNot(contains('l')));
    expect(out, 'w=[redacted:${glued.length}]');
  });

  test('a run mixing English and French words is redacted', () {
    final mixed = [en[0], fr[0], en[1], fr[1]];
    expectGone(LogScrubber.scrub('w: ${mixed.join(' ')}'), mixed);
  });

  test('underscore runs are redacted word by word by the run rule', () {
    // The token redactor would also hide the whole token; the per-word
    // shape shows the run rule saw the underscores as separators.
    for (final words in [en, fr.take(4).toList()]) {
      final out = LogScrubber.scrub('k=${words.join('_')}');
      expectGone(out, words);
      expect(out, matches(RegExp(r'(\[redacted:\d+\]_){3}\[redacted:\d+\]')));
    }
  });

  test('1-3 French list words in prose pass, as English ones do', () {
    expect(WordList.french.contains('avec'), isFalse);
    final line = '${fr[0]} avec ${fr[1]} avec ${fr[2]}';
    final out = LogScrubber.scrub(line);
    expect(out, contains(fr[0]));
    expect(out, contains(fr[2]));
  });
}
