// The 8 PAKE words in any shipped language (plan Task 8.4b; spike
// .devloop/spikes/word-language.md §3). The key is always derived from the
// English rendering of the words' indices, so a package made with English
// words opens with the same words typed in French, and nothing an older
// Signet wrote changes.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/crypto/wordlists.dart';

void main() {
  const english = <String>[
    'abandon', 'ability', 'able', 'about', //
    'above', 'absent', 'absorb', 'abstract',
  ];
  List<String> inFrench(List<String> words) => [
        for (final w in words)
          WordList.french.wordAt(WordList.english.indexOf(w)!),
      ];
  String stripAccents(String w) => WordList.fold(w)!;
  String toNfd(String w) =>
      w.replaceAll('é', 'e\u0301').replaceAll('è', 'e\u0300');

  final secret = List<int>.generate(32, (i) => i + 1);
  Future<String> lpr(List<String> pakeWords) => TransportPackage.encodeLpr(
        label: 'Mom',
        role: PairRole.a,
        pairedAt: DateTime.utc(2026, 1, 1),
        silentHaptics: false,
        sharedSecret: secret,
        pakeWords: pakeWords,
        nonceRandom: Random(42),
      );

  // Strings that are words in both lists, at different indices.
  final shared = [
    for (final w in WordList.english.words)
      if (WordList.french.contains(w)) w,
  ];

  group('pakeCandidates', () {
    test('English words give one candidate, themselves', () {
      expect(TransportPackage.pakeCandidates(english), [english]);
    });

    test('French words give their English rendering', () {
      expect(TransportPackage.pakeCandidates(inFrench(english)), [english]);
    });

    test('accent-free, NFD, padded and upper-case French all count', () {
      final fr = inFrench(english);
      for (final variant in [
        fr.map(stripAccents).toList(),
        fr.map(toNfd).toList(),
        fr.map((w) => '  ${w.toUpperCase()} ').toList(),
      ]) {
        expect(TransportPackage.pakeCandidates(variant), [english]);
      }
    });

    test('words valid in both lists give both readings, English first', () {
      final words = shared.take(8).toList();
      final candidates = TransportPackage.pakeCandidates(words);
      expect(candidates, hasLength(2));
      expect(candidates.first, words);
      expect(
        candidates.last,
        [
          for (final w in words)
            WordList.english.wordAt(WordList.french.indexOf(w)!),
        ],
      );
    });

    test('a phrase mixing two lists is refused without naming a word', () {
      final mixed = [...english.take(4), ...inFrench(english).skip(4)];
      // Only if the French half is not also English (true for this phrase).
      expect(WordList.english.contains(mixed[5]), isFalse);
      expect(
        () => TransportPackage.pakeCandidates(mixed),
        throwsA(isA<InvalidPakeException>().having(
          (e) => e.message,
          'message',
          allOf(contains('one language'), isNot(contains(mixed[5]))),
        )),
      );
    });

    test('an unknown word is reported by its position, never its text', () {
      final bad = [...english]..[3] = 'zzqx';
      expect(
        () => TransportPackage.pakeCandidates(bad),
        throwsA(isA<InvalidPakeException>().having(
          (e) => e.message,
          'message',
          allOf(contains('Word 4'), isNot(contains('zzqx'))),
        )),
      );
    });

    test('the wrong number of words is refused', () {
      expect(
        () => TransportPackage.pakeCandidates(english.take(7).toList()),
        throwsA(isA<InvalidPakeException>()),
      );
    });
  });

  group('normalizePakeWords (what encoders key on)', () {
    test('English input is unchanged', () {
      expect(TransportPackage.normalizePakeWords(english), english);
    });

    test('French input becomes the English rendering', () {
      expect(TransportPackage.normalizePakeWords(inFrench(english)), english);
    });
  });

  group('decoding with words in another language', () {
    test('a package made with English words opens with them in French',
        () async {
      final wire = await lpr(english);
      final fr = inFrench(english);
      for (final words in [
        fr,
        fr.map(stripAccents).toList(),
        fr.map(toNfd).toList(),
      ]) {
        final opened =
            await TransportPackage.decodeLpr(wire, pakeWords: words);
        expect(opened.sharedSecret, secret);
      }
    });

    test('encoding with French words is byte-identical to English', () async {
      expect(await lpr(inFrench(english)), await lpr(english));
    });

    test('an ambiguous phrase opens under whichever reading made it',
        () async {
      final words = shared.take(8).toList();
      final readings = TransportPackage.pakeCandidates(words);
      for (final reading in readings) {
        final wire = await lpr(reading);
        final opened =
            await TransportPackage.decodeLpr(wire, pakeWords: words);
        expect(opened.sharedSecret, secret);
      }
    });

    test('wrong words in French still fail authentication', () async {
      final wire = await lpr(english);
      final wrong = inFrench([...english]..[0] = 'absurd');
      await expectLater(
        TransportPackage.decodeLpr(wire, pakeWords: wrong),
        throwsA(isA<InvalidPakeException>()),
      );
    });

    test('LDP: the receiver gets the verified English words for its response',
        () async {
      final senderKey = Uint8List.fromList(List<int>.generate(32, (i) => 9 + i));
      final receiverKey =
          Uint8List.fromList(List<int>.generate(32, (i) => 77 + i));
      final request = await TransportPackage.encodeLdpRequest(
        publicKey: senderKey,
        labelHint: 'Jake',
        pakeWords: english,
        nonceRandom: Random(1),
      );
      final ldp = await TransportPackage.decodeLdpStrict(
        request,
        pakeWords: inFrench(english).map(stripAccents).toList(),
      );
      expect(ldp.verifiedPakeWords, english);

      final response = await TransportPackage.encodeLdpResponse(
        publicKey: receiverKey,
        pakeWords: ldp.verifiedPakeWords,
        nonceRandom: Random(2),
      );
      final back =
          await TransportPackage.decodeLdpStrict(response, pakeWords: english);
      expect(back.publicKey, receiverKey);
    });

    test('LDP: an ambiguous phrase yields the reading that verified',
        () async {
      final words = shared.take(8).toList();
      final frReading = TransportPackage.pakeCandidates(words).last;
      final request = await TransportPackage.encodeLdpRequest(
        publicKey: Uint8List(32)..[0] = 9,
        labelHint: '',
        pakeWords: frReading,
        nonceRandom: Random(3),
      );
      final ldp =
          await TransportPackage.decodeLdpStrict(request, pakeWords: words);
      expect(ldp.verifiedPakeWords, frReading);
      expect(listEquals(ldp.verifiedPakeWords, words), isFalse);
    });
  });
}
