import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/bip39_english_wordlist.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/pairing.dart';
import 'package:signet/core/crypto/totp_words.dart';
import 'package:signet/core/crypto/verification.dart';

void main() {
  final secret = utf8.encode('12345678901234567890123456789012');
  final wordSet = bip39EnglishWordlist.toSet();

  // ===========================================================================
  // Fixed output vectors
  // ===========================================================================
  //
  // TotpWords is Signet's own primitive (no equivalent of RFC 6238 to crib
  // from). These vectors are SNAPSHOTS of the current implementation pinned
  // here as the ground-truth contract. The rest of this file tests
  // self-consistency properties (determinism, role asymmetry, domain
  // separation), but a silent regression in the HKDF wiring or the BIP-39
  // word-index mapping could pass every property test while emitting
  // different words in production — Alice and Bob would derive mismatched
  // codes from the same shared secret, and no test would catch it.
  //
  // To verify these vectors against an independent implementation: run
  // HKDF-SHA-256(secret=ASCII("12345..."), info="signet/v1/totp-words-from-X",
  // nonce=BE-uint64(time/30), outLen=6 bytes), then read 4 11-bit chunks
  // big-endian and index into the BIP-39 English wordlist.
  //
  // Update procedure: if these break after an intentional crypto-layer
  // change, regenerate via a one-shot capture (see git history for the
  // pattern) and re-pin. NEVER tweak the expected values to make a failing
  // test pass without verifying the cause.
  group('TotpWords.generate — fixed snapshot vectors', () {
    final vectors = <
        (int unixTime, PairRole role),
        List<String>>{
      (59, PairRole.a): const ['brain', 'kit', 'exercise', 'express'],
      (59, PairRole.b): const ['nominee', 'awake', 'grocery', 'soup'],
      (1111111109, PairRole.a): const ['volcano', 'occur', 'fire', 'setup'],
      (1111111109, PairRole.b): const ['piano', 'please', 'erode', 'novel'],
      (1234567890, PairRole.a): const ['service', 'divert', 'song', 'live'],
      (1234567890, PairRole.b): const ['cloth', 'coast', 'payment', 'cry'],
      (2000000000, PairRole.a): const ['program', 'high', 'quarter', 'sponsor'],
      (2000000000, PairRole.b): const ['parent', 'olive', 'canal', 'unaware'],
    };

    vectors.forEach((key, expected) {
      final (unixTime, role) = key;
      test('T=$unixTime role=${role.wireName} → $expected', () async {
        final actual = await TotpWords.generate(
          secret: secret,
          unixTimeSeconds: unixTime,
          senderRole: role,
        );
        expect(actual, equals(expected));
      });
    });
  });

  group('TotpWords.generate', () {
    test('produces exactly 4 words by default', () async {
      final words = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: 1111111111,
        senderRole: PairRole.a,
      );
      expect(words, hasLength(4));
    });

    test('every derived word is in the BIP-39 wordlist', () async {
      final words = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: 1111111111,
        senderRole: PairRole.a,
      );
      for (final word in words) {
        expect(wordSet, contains(word), reason: 'word "$word" not in wordlist');
      }
    });

    test('is deterministic for the same secret, window, and role', () async {
      const t = 1111111111;
      final a = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: t,
        senderRole: PairRole.a,
      );
      final b = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: t,
        senderRole: PairRole.a,
      );
      expect(a, equals(b));
    });

    test('is constant across seconds within the same 30-second window',
        () async {
      final a = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: 60,
        senderRole: PairRole.a,
      );
      final b = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: 89,
        senderRole: PairRole.a,
      );
      expect(a, equals(b));
    });

    test('differs across adjacent windows', () async {
      final a = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: 60,
        senderRole: PairRole.a,
      );
      final b = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: 90,
        senderRole: PairRole.a,
      );
      expect(a, isNot(equals(b)));
    });

    test('rejects empty secret', () async {
      expect(
        () => TotpWords.generate(
          secret: const <int>[],
          unixTimeSeconds: 0,
          senderRole: PairRole.a,
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-positive wordCount', () async {
      expect(
        () => TotpWords.generate(
          secret: secret,
          unixTimeSeconds: 0,
          senderRole: PairRole.a,
          wordCount: 0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-positive timeStepSeconds', () async {
      expect(
        () => TotpWords.generate(
          secret: secret,
          unixTimeSeconds: 0,
          senderRole: PairRole.a,
          timeStepSeconds: 0,
        ),
        throwsArgumentError,
      );
    });

    test('supports wordCount != 4', () async {
      final words = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: 1111111111,
        senderRole: PairRole.a,
        wordCount: 6,
      );
      expect(words, hasLength(6));
    });
  });

  group('TotpWords.verify', () {
    const t = 1111111111;

    test('accepts the exact current window', () async {
      final expected = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: t,
        senderRole: PairRole.a,
      );
      expect(
        await TotpWords.verify(
          secret: secret,
          candidate: expected,
          unixTimeSeconds: t,
          senderRole: PairRole.a,
        ),
        isTrue,
      );
    });

    test('accepts one window in the past (tolerance ±1)', () async {
      final prev = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: t - 30,
        senderRole: PairRole.a,
      );
      expect(
        await TotpWords.verify(
          secret: secret,
          candidate: prev,
          unixTimeSeconds: t,
          senderRole: PairRole.a,
        ),
        isTrue,
      );
    });

    test('accepts one window in the future (tolerance ±1)', () async {
      final next = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: t + 30,
        senderRole: PairRole.a,
      );
      expect(
        await TotpWords.verify(
          secret: secret,
          candidate: next,
          unixTimeSeconds: t,
          senderRole: PairRole.a,
        ),
        isTrue,
      );
    });

    test('rejects two windows in the past (outside tolerance)', () async {
      final twoBack = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: t - 60,
        senderRole: PairRole.a,
      );
      expect(
        await TotpWords.verify(
          secret: secret,
          candidate: twoBack,
          unixTimeSeconds: t,
          senderRole: PairRole.a,
        ),
        isFalse,
      );
    });

    test('rejects two windows in the future (outside tolerance)', () async {
      final twoForward = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: t + 60,
        senderRole: PairRole.a,
      );
      expect(
        await TotpWords.verify(
          secret: secret,
          candidate: twoForward,
          unixTimeSeconds: t,
          senderRole: PairRole.a,
        ),
        isFalse,
      );
    });

    test('accepts windowTolerance=0 only at the exact window', () async {
      final current = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: t,
        senderRole: PairRole.a,
      );
      final prev = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: t - 30,
        senderRole: PairRole.a,
      );
      expect(
        await TotpWords.verify(
          secret: secret,
          candidate: current,
          unixTimeSeconds: t,
          senderRole: PairRole.a,
          windowTolerance: 0,
        ),
        isTrue,
      );
      expect(
        await TotpWords.verify(
          secret: secret,
          candidate: prev,
          unixTimeSeconds: t,
          senderRole: PairRole.a,
          windowTolerance: 0,
        ),
        isFalse,
      );
    });

    test('is case-insensitive on candidate words', () async {
      final expected = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: t,
        senderRole: PairRole.a,
      );
      final shouted = expected.map((w) => w.toUpperCase()).toList();
      expect(
        await TotpWords.verify(
          secret: secret,
          candidate: shouted,
          unixTimeSeconds: t,
          senderRole: PairRole.a,
        ),
        isTrue,
      );
    });

    test('tolerates surrounding whitespace on candidate words', () async {
      final expected = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: t,
        senderRole: PairRole.a,
      );
      final padded = expected.map((w) => '  $w  ').toList();
      expect(
        await TotpWords.verify(
          secret: secret,
          candidate: padded,
          unixTimeSeconds: t,
          senderRole: PairRole.a,
        ),
        isTrue,
      );
    });

    test('rejects candidate with wrong length', () async {
      final expected = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: t,
        senderRole: PairRole.a,
      );
      expect(
        await TotpWords.verify(
          secret: secret,
          candidate: expected.sublist(0, 3),
          unixTimeSeconds: t,
          senderRole: PairRole.a,
        ),
        isFalse,
      );
    });

    test('rejects candidate with a non-wordlist token', () async {
      final expected = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: t,
        senderRole: PairRole.a,
      );
      final tampered = <String>[...expected.sublist(0, 3), 'xyzzynotaword'];
      expect(
        await TotpWords.verify(
          secret: secret,
          candidate: tampered,
          unixTimeSeconds: t,
          senderRole: PairRole.a,
        ),
        isFalse,
      );
    });

    test('rejects a wrong-but-valid 4 words from the wordlist', () async {
      expect(
        await TotpWords.verify(
          secret: secret,
          candidate: const <String>['orange', 'anchor', 'cat', 'wagon'],
          unixTimeSeconds: t,
          senderRole: PairRole.a,
        ),
        isFalse,
      );
    });

    test('rejects negative windowTolerance', () async {
      expect(
        () => TotpWords.verify(
          secret: secret,
          candidate: const <String>['a', 'b', 'c', 'd'],
          unixTimeSeconds: t,
          senderRole: PairRole.a,
          windowTolerance: -1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TotpWords per-role asymmetry (reflection-attack defense)', () {
    const t = 1111111111;

    test('role a and role b produce different 4 words for the same window',
        () async {
      final aWords = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: t,
        senderRole: PairRole.a,
      );
      final bWords = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: t,
        senderRole: PairRole.b,
      );
      expect(aWords, isNot(equals(bWords)));
    });

    test(
      'verify with role a rejects a candidate that was generated for role b '
      '(this is the parrot-attack test)',
      () async {
        final bWords = await TotpWords.generate(
          secret: secret,
          unixTimeSeconds: t,
          senderRole: PairRole.b,
        );
        expect(
          await TotpWords.verify(
            secret: secret,
            candidate: bWords,
            unixTimeSeconds: t,
            senderRole: PairRole.a,
          ),
          isFalse,
          reason:
              'B\'s words must not verify as A\'s words — reflecting them back '
              'at Alice (role a) should fail.',
        );
      },
    );

    test(
      'verify with role b rejects a candidate that was generated for role a',
      () async {
        final aWords = await TotpWords.generate(
          secret: secret,
          unixTimeSeconds: t,
          senderRole: PairRole.a,
        );
        expect(
          await TotpWords.verify(
            secret: secret,
            candidate: aWords,
            unixTimeSeconds: t,
            senderRole: PairRole.b,
          ),
          isFalse,
          reason:
              'A\'s words must not verify as B\'s words — reflecting them back '
              'at Bob (role b) should fail.',
        );
      },
    );

    test('role-asymmetry holds across the ±1 window tolerance', () async {
      // Even with window tolerance, a role-mismatched candidate from the
      // neighbouring window must still be rejected.
      for (final offset in <int>[-30, 0, 30]) {
        final bWords = await TotpWords.generate(
          secret: secret,
          unixTimeSeconds: t + offset,
          senderRole: PairRole.b,
        );
        expect(
          await TotpWords.verify(
            secret: secret,
            candidate: bWords,
            unixTimeSeconds: t,
            senderRole: PairRole.a,
          ),
          isFalse,
          reason: 'B-role candidate at offset $offset must fail A-role verify',
        );
      }
    });

    test('role a words verify correctly against role a (sanity)', () async {
      final aWords = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: t,
        senderRole: PairRole.a,
      );
      expect(
        await TotpWords.verify(
          secret: secret,
          candidate: aWords,
          unixTimeSeconds: t,
          senderRole: PairRole.a,
        ),
        isTrue,
      );
    });
  });

  group('TotpWords domain separation', () {
    test(
        'same shared secret produces pair-time phrase distinct from all '
        'TOTP-words windows (both roles) in a day', () async {
      final phrase = await PairingVerification.derivePhrase(
        sharedSecret: secret,
      );
      // 2880 windows = 24 h × 3600 s / 30 s. For each window, check that
      // neither role's code matches the pair-time phrase.
      for (var window = 0; window < 2880; window++) {
        for (final role in PairRole.values) {
          final words = await TotpWords.generate(
            secret: secret,
            unixTimeSeconds: window * 30,
            senderRole: role,
          );
          expect(
            words,
            isNot(equals(phrase)),
            reason:
                'window $window (role ${role.wireName}) collided with pair-time phrase',
          );
        }
      }
    });

    test('different shared secrets produce different words for same window',
        () async {
      final other = await PairingHandshake.keyPairFromSeed(
        List<int>.generate(32, (i) => i + 1),
      );
      final a = await TotpWords.generate(
        secret: secret,
        unixTimeSeconds: 1111111111,
        senderRole: PairRole.a,
      );
      final b = await TotpWords.generate(
        secret: other.privateKeyBytes,
        unixTimeSeconds: 1111111111,
        senderRole: PairRole.a,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
