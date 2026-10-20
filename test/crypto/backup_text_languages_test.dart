// BackupText.read with the 8 words in French (plan Task 8.4c): the words
// may be accented, accent-free or decomposed (NFD), on one line or spread
// over several, but all from one list.

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/backup_bundle.dart';
import 'package:signet/core/crypto/wordlists.dart';

void main() {
  const english = <String>[
    'abandon', 'ability', 'able', 'about', //
    'above', 'absent', 'absorb', 'abstract',
  ];
  final french = [
    for (final w in english) WordList.french.wordAt(WordList.english.indexOf(w)!),
  ];
  // Pick a phrase that really has accents, so the NFD and accent-free
  // cases test something.
  final accented = [
    for (final w in WordList.french.words)
      if (w.contains('é') || w.contains('è')) w,
  ].take(8).toList();
  String toNfd(String w) =>
      w.replaceAll('é', 'e\u0301').replaceAll('è', 'e\u0300');

  test('French words on one line are read in their own spelling', () {
    expect(BackupText.read(accented.join(' ')).pakeWords, accented);
    expect(BackupText.read(french.join(' ')).pakeWords, french);
  });

  test('accent-free, NFD and upper-case French are read as the same words',
      () {
    for (final line in [
      accented.map((w) => WordList.fold(w)!).join(' '),
      accented.map(toNfd).join(' '),
      accented.map((w) => w.toUpperCase()).join(' '),
    ]) {
      expect(BackupText.read(line).pakeWords, accented, reason: line);
    }
  });

  test('French words numbered one per line are found', () {
    final text = [
      for (var i = 0; i < 8; i++) '${i + 1}. ${accented[i]}',
    ].join('\n');
    expect(BackupText.read(text).pakeWords, accented);
  });

  test('a zero-width character inside a word does not split it', () {
    final words = [...accented]..[2] = '${accented[2].substring(0, 2)}'
        '\u200B${accented[2].substring(2)}';
    // On one line, and numbered one per line (split on non-letters).
    expect(BackupText.read(words.join(' ')).pakeWords, accented);
    final numbered = [
      for (var i = 0; i < 8; i++) '${i + 1}. ${words[i]}',
    ].join('\n');
    expect(BackupText.read(numbered).pakeWords, accented);
  });

  test('English words still read exactly as before', () {
    expect(BackupText.read(english.join(' ')).pakeWords, english);
  });

  test('a line mixing English and French words is not the 8 words', () {
    final mixed = [...english.take(4), ...accented.skip(4)];
    expect(BackupText.read(mixed.join(' ')).pakeWords, isNull);
  });
}
