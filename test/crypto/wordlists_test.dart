// Shipped BIP-39 word lists and the input fold (plan Task 8.4a; spike
// .devloop/spikes/word-language.md §1). Every list is an 11-bit index space,
// so the fold must never let two words of one list collide, and NFC, NFD
// and accent-free input must give the same index.

import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/bip39_english_wordlist.dart';
import 'package:signet/core/crypto/bip39_french_wordlist.dart';
import 'package:signet/core/crypto/wordlists.dart';

/// Upstream bitcoin/bips `bip-0039/<lang>.txt`, one word per line with a
/// trailing newline, as published.
const _upstreamSha256 = {
  'en': '2f5eed53a4727b4bf8880d8f3f199efc90e58503646d9ff8eff3a2ed3b24dbda',
  'fr': 'ebc3959ab7801a1df6bac4fa7d970652f1df76b683cd2f4003c941c63d517e59',
};

/// The upstream files are decomposed; the French list only uses è and é.
String _toNfd(String w) =>
    w.replaceAll('é', 'e\u0301').replaceAll('è', 'e\u0300');

Future<String> _sha256Hex(String s) async {
  final hash = await Sha256().hash(utf8.encode(s));
  return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

void main() {
  test('shipped lists are English then French', () {
    expect(WordList.shipped.map((l) => l.id), ['en', 'fr']);
    expect(WordList.english.words, same(bip39EnglishWordlist));
    expect(WordList.french.words, same(bip39FrenchWordlist));
  });

  for (final list in WordList.shipped) {
    group('${list.id} list', () {
      test('matches the upstream file', () async {
        expect(list.words, hasLength(2048));
        final file = '${list.words.map(_toNfd).join('\n')}\n';
        expect(await _sha256Hex(file), _upstreamSha256[list.id]);
      });

      test('uses no letters the fold does not cover', () {
        for (final w in list.words) {
          expect(list.fold(w), isNotNull, reason: w);
        }
      });

      test('no two words share a folded form or their first 4 letters', () {
        final folded = list.words.map(list.fold).toList();
        expect(folded.toSet(), hasLength(2048));
        expect(
          folded.map((w) => w!.substring(0, w.length < 4 ? w.length : 4)).toSet(),
          hasLength(2048),
        );
      });

      test('indexOf finds every word at its own index, in NFC and NFD', () {
        for (var i = 0; i < 2048; i++) {
          expect(list.indexOf(list.words[i]), i);
          expect(list.indexOf(_toNfd(list.words[i])), i);
        }
      });

      test('wordAt is the inverse of indexOf', () {
        expect(list.wordAt(0), list.words.first);
        expect(list.wordAt(2047), list.words.last);
      });
    });
  }

  group('fold', () {
    test('lowercases, trims nothing else, and drops accents', () {
      expect(WordList.english.fold('Élève'), 'eleve');
      expect(WordList.english.fold('ÉLÈVE'), 'eleve');
      expect(WordList.english.fold('e\u0301le\u0300ve'), 'eleve');
      expect(WordList.english.fold('abandon'), 'abandon');
    });

    test('removes zero-width and soft-hyphen characters', () {
      expect(WordList.english.fold('aban\u200Bdon'), 'abandon');
      expect(WordList.english.fold('aban\u00ADdon'), 'abandon');
      expect(WordList.english.fold('\uFEFFabandon'), 'abandon');
      expect(WordList.english.fold('aban\u2060don'), 'abandon');
      expect(WordList.english.fold('abandon\u200F'), 'abandon'); // RLM
      expect(WordList.english.fold('\u200Eabandon'), 'abandon'); // LRM
    });

    test('rejects anything that is not a plain Latin word', () {
      for (final bad in [
        '',
        'abandon ability',
        'aban-don',
        'abandon1',
        'ａｂａｎｄｏｎ', // fullwidth
        'аbandon', // Cyrillic а
        'a\u0304bandon', // NFD macron: rejected like precomposed ā
        'ābandon',
        'straße',
      ]) {
        expect(WordList.english.fold(bad), isNull, reason: bad);
      }
    });

    test('compatibility letters Dart lowercases onto a-z reach that word', () {
      // Harmless: the word they look like, never a different one.
      expect(WordList.english.fold('İnfant'), 'infant');
      expect(WordList.english.fold('\u212Aey'), 'key'); // Kelvin sign
    });

    test('accent-free and wrongly-accented input reach the same French word',
        () {
      final i = WordList.french.indexOf('élève');
      expect(i, isNotNull);
      expect(WordList.french.indexOf('eleve'), i);
      expect(WordList.french.indexOf('élêve'), i);
      expect(WordList.french.indexOf('ELEVE'), i);
    });
  });

  test('a word outside the list has no index', () {
    expect(WordList.english.indexOf('élève'), isNull);
    expect(WordList.french.indexOf('zebra'), isNull);
    expect(WordList.english.indexOf('notaword'), isNull);
  });
}
