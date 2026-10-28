// Relationship.wordLanguage (v0.5.0 plan Task 1.3): stored per contact,
// read as English when missing (every contact saved before v0.5.0), and an
// id this version does not know is kept as it came.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/wordlists.dart';
import 'package:signet/core/models/relationship.dart';

void main() {
  final mom = Relationship(
    id: 'abc',
    label: 'Mom',
    pairedAt: DateTime.utc(2026, 4, 16),
    role: PairRole.a,
  );

  test('the default is the English list', () {
    expect(Relationship.defaultWordLanguage, WordList.english.id);
    expect(mom.wordLanguage, 'en');
    expect(mom.wordList, same(WordList.english));
    expect(
        Relationship.fresh(label: 'Mom', role: PairRole.a).wordLanguage, 'en');
  });

  test('a contact saved before v0.5.0 reads as English', () {
    final legacy = jsonEncode(<String, dynamic>{
      'id': 'abc',
      'label': 'Mom',
      'pairedAtMs': DateTime.utc(2026, 4, 16).millisecondsSinceEpoch,
      'role': 'a',
      'silentHaptics': false,
    });
    final read = Relationship.fromJson(legacy);
    expect(read.wordLanguage, 'en');
    expect(read.wordLanguageChangedAt, isNull);
    expect(read, mom);
  });

  test('French round-trips through JSON, with the change date', () {
    final fr = mom.copyWith(
      wordLanguage: 'fr',
      wordLanguageChangedAt: DateTime.utc(2026, 11, 2, 9, 30),
    );
    final read = Relationship.fromJson(fr.toJson());
    expect(read, fr);
    expect(read.wordList, same(WordList.french));
    expect(read.wordLanguageChangedAt, DateTime.utc(2026, 11, 2, 9, 30));
    expect(read == mom, isFalse);
  });

  test('an unknown id is kept, and has no list', () {
    final newer = mom.copyWith(wordLanguage: 'zh-9');
    final read = Relationship.fromJson(newer.toJson());
    expect(read.wordLanguage, 'zh-9');
    expect(read.knownWordList, isNull);
    // Callers check knownWordList before showing words; this fallback only
    // keeps code that needs some list (a backup's PAKE words) working.
    expect(read.wordList, same(WordList.english));
  });

  test('a non-string wordLanguage in JSON reads as English', () {
    final map = jsonDecode(mom.toJson()) as Map<String, dynamic>
      ..['wordLanguage'] = 7;
    expect(Relationship.fromJson(jsonEncode(map)).wordLanguage, 'en');
  });

  test('equality and hashCode see the language and its change date', () {
    final fr = mom.copyWith(wordLanguage: 'fr');
    expect(fr == mom.copyWith(wordLanguage: 'en'), isFalse);
    expect(fr, mom.copyWith(wordLanguage: 'fr'));
    expect(fr.hashCode, mom.copyWith(wordLanguage: 'fr').hashCode);
    final dated = fr.copyWith(wordLanguageChangedAt: DateTime.utc(2026));
    expect(dated == fr, isFalse);
    expect(dated,
        fr.copyWith(wordLanguageChangedAt: DateTime.utc(2026).toLocal()));
  });

  test('a damaged tag is damaged, unknown and never a list', () {
    final damaged =
        mom.copyWith(wordLanguage: Relationship.damagedWordLanguage);
    expect(damaged.wordLanguageDamaged, isTrue);
    expect(damaged.knownWordList, isNull);
    expect(mom.copyWith(wordLanguage: 'zh-9').wordLanguageDamaged, isFalse);
  });

  test('copyWith keeps the language unless told otherwise (rekey)', () {
    final fr = mom.copyWith(wordLanguage: 'fr');
    final rekeyed = fr.copyWith(role: PairRole.b, pairedAt: DateTime.utc(2027));
    expect(rekeyed.wordLanguage, 'fr');
  });

  test('toString shows the language and still not the label', () {
    final text = mom.copyWith(wordLanguage: 'fr').toString();
    expect(text, contains('wordLanguage: fr'));
    expect(text, isNot(contains('Mom')));
  });
}
