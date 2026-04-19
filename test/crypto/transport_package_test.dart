import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/bip39_english_wordlist.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/transport_package.dart';

void main() {
  // Eight deterministic PAKE words used across tests.
  const goodPake = <String>[
    'abandon',
    'ability',
    'able',
    'about',
    'above',
    'absent',
    'absorb',
    'abstract',
  ];

  // Seed a fixed nonce RNG so encode produces deterministic output for
  // vector checks. The app never uses this in production; it only matters
  // for test determinism.
  Random fixedRng([int seed = 42]) => Random(seed);

  group('mintPakeWords', () {
    test('returns exactly 8 BIP-39 words', () {
      final words = TransportPackage.mintPakeWords(random: fixedRng());
      expect(words, hasLength(8));
      for (final w in words) {
        expect(bip39EnglishWordlist.contains(w), isTrue);
      }
    });

    test('seeded RNG is deterministic; default RNG isn\'t', () {
      final a = TransportPackage.mintPakeWords(random: fixedRng(7));
      final b = TransportPackage.mintPakeWords(random: fixedRng(7));
      expect(a, b);
      final c = TransportPackage.mintPakeWords();
      final d = TransportPackage.mintPakeWords();
      expect(c, isNot(d));
    });
  });

  group('normalizePakeWords', () {
    test('accepts correctly-cased input', () {
      final out = TransportPackage.normalizePakeWords(goodPake);
      expect(out, goodPake);
    });

    test('lowercases + trims whitespace', () {
      final noisy = goodPake.map((w) => '  ${w.toUpperCase()} ').toList();
      final out = TransportPackage.normalizePakeWords(noisy);
      expect(out, goodPake);
    });

    test('rejects wrong count', () {
      expect(
        () => TransportPackage.normalizePakeWords(goodPake.take(7).toList()),
        throwsA(isA<InvalidPakeException>()),
      );
      expect(
        () => TransportPackage.normalizePakeWords([...goodPake, 'abandon']),
        throwsA(isA<InvalidPakeException>()),
      );
    });

    test('rejects a non-wordlist token', () {
      final bad = [...goodPake];
      bad[3] = 'notaword';
      expect(
        () => TransportPackage.normalizePakeWords(bad),
        throwsA(isA<InvalidPakeException>()),
      );
    });
  });

  group('LDP — long-distance pairing', () {
    final publicKey = List<int>.generate(32, (i) => i);
    const labelHint = 'Mom';

    test('round-trips publicKey + label hint + timestamp', () async {
      final wire = await TransportPackage.encodeLdp(
        publicKey: publicKey,
        labelHint: labelHint,
        pakeWords: goodPake,
        now: DateTime.utc(2026, 4, 18, 12, 0),
        nonceRandom: fixedRng(),
      );
      expect(wire.startsWith('signet:tp1:'), isTrue);

      final decoded =
          await TransportPackage.decodeLdp(wire, pakeWords: goodPake);
      expect(decoded.publicKey, publicKey);
      expect(decoded.labelHint, labelHint);
      expect(decoded.timestamp.toUtc(), DateTime.utc(2026, 4, 18, 12, 0));
    });

    test('empty label hint is allowed', () async {
      final wire = await TransportPackage.encodeLdp(
        publicKey: publicKey,
        labelHint: '',
        pakeWords: goodPake,
        nonceRandom: fixedRng(),
      );
      final decoded =
          await TransportPackage.decodeLdp(wire, pakeWords: goodPake);
      expect(decoded.labelHint, '');
    });

    test('rejects mismatched PAKE secret with InvalidPakeException',
        () async {
      final wire = await TransportPackage.encodeLdp(
        publicKey: publicKey,
        labelHint: labelHint,
        pakeWords: goodPake,
        nonceRandom: fixedRng(),
      );
      final wrong = [...goodPake];
      wrong[0] = 'absurd';
      await expectLater(
        TransportPackage.decodeLdp(wire, pakeWords: wrong),
        throwsA(isA<InvalidPakeException>()),
      );
    });

    test('rejects LPR wire string when trying to decode as LDP', () async {
      final lprWire = await TransportPackage.encodeLpr(
        label: 'Mom',
        role: PairRole.a,
        pairedAt: DateTime.utc(2026, 1, 1),
        silentHaptics: false,
        sharedSecret: List<int>.generate(32, (i) => i + 1),
        pakeWords: goodPake,
        nonceRandom: fixedRng(),
      );
      await expectLater(
        TransportPackage.decodeLdp(lprWire, pakeWords: goodPake),
        throwsA(isA<InvalidPackageException>()),
      );
    });

    test('rejects malformed base64 body', () async {
      await expectLater(
        TransportPackage.decodeLdp(
          'signet:tp1:not valid base64!!!',
          pakeWords: goodPake,
        ),
        throwsA(isA<InvalidPackageException>()),
      );
    });

    test('rejects wrong scheme prefix', () async {
      await expectLater(
        TransportPackage.decodeLdp(
          'signet:p1:NotATransportPackage',
          pakeWords: goodPake,
        ),
        throwsA(isA<InvalidPackageException>()),
      );
    });

    test('rejects oversized label hint', () async {
      expect(
        () => TransportPackage.encodeLdp(
          publicKey: publicKey,
          labelHint: 'x' * 33,
          pakeWords: goodPake,
          nonceRandom: fixedRng(),
        ),
        throwsArgumentError,
      );
    });

    test('rejects wrong-length public key', () async {
      expect(
        () => TransportPackage.encodeLdp(
          publicKey: List<int>.filled(31, 0),
          labelHint: labelHint,
          pakeWords: goodPake,
          nonceRandom: fixedRng(),
        ),
        throwsArgumentError,
      );
    });

    test('bit-flip in the wire body fails decryption (tag check)', () async {
      final wire = await TransportPackage.encodeLdp(
        publicKey: publicKey,
        labelHint: labelHint,
        pakeWords: goodPake,
        nonceRandom: fixedRng(),
      );
      // Flip a bit in the middle of the payload.
      final before = wire.substring(0, 'signet:tp1:'.length + 20);
      final middle = wire.substring('signet:tp1:'.length + 20,
          'signet:tp1:'.length + 21);
      final after = wire.substring('signet:tp1:'.length + 21);
      // Replace one char with a different one, keeping base64url-valid.
      final flipped = middle == 'A' ? 'B' : 'A';
      final tampered = '$before$flipped$after';
      await expectLater(
        TransportPackage.decodeLdp(tampered, pakeWords: goodPake),
        throwsA(anyOf(
          isA<InvalidPakeException>(),
          isA<InvalidPackageException>(),
        )),
      );
    });
  });

  group('LPR — lost-phone recovery', () {
    final sharedSecret = List<int>.generate(32, (i) => i + 1);
    final pairedAt = DateTime.utc(2026, 2, 14, 15, 3);

    test('round-trips every relationship field', () async {
      final wire = await TransportPackage.encodeLpr(
        label: 'Mom',
        role: PairRole.b,
        pairedAt: pairedAt,
        silentHaptics: true,
        sharedSecret: sharedSecret,
        pakeWords: goodPake,
        now: DateTime.utc(2026, 4, 18, 12, 0),
        nonceRandom: fixedRng(),
      );
      final decoded =
          await TransportPackage.decodeLpr(wire, pakeWords: goodPake);
      expect(decoded.sharedSecret, sharedSecret);
      expect(decoded.label, 'Mom');
      expect(decoded.role, PairRole.b);
      expect(decoded.pairedAt.toUtc(), pairedAt);
      expect(decoded.silentHaptics, isTrue);
      expect(decoded.timestamp.toUtc(), DateTime.utc(2026, 4, 18, 12, 0));
    });

    test('preserves silentHaptics=false', () async {
      final wire = await TransportPackage.encodeLpr(
        label: 'Dad',
        role: PairRole.a,
        pairedAt: pairedAt,
        silentHaptics: false,
        sharedSecret: sharedSecret,
        pakeWords: goodPake,
        nonceRandom: fixedRng(),
      );
      final decoded =
          await TransportPackage.decodeLpr(wire, pakeWords: goodPake);
      expect(decoded.silentHaptics, isFalse);
    });

    test('rejects an LDP wire string when trying to decode as LPR', () async {
      final ldpWire = await TransportPackage.encodeLdp(
        publicKey: List<int>.generate(32, (i) => i),
        labelHint: 'Mom',
        pakeWords: goodPake,
        nonceRandom: fixedRng(),
      );
      await expectLater(
        TransportPackage.decodeLpr(ldpWire, pakeWords: goodPake),
        throwsA(isA<InvalidPackageException>()),
      );
    });

    test('rejects wrong-length shared secret', () async {
      expect(
        () => TransportPackage.encodeLpr(
          label: 'Mom',
          role: PairRole.a,
          pairedAt: pairedAt,
          silentHaptics: false,
          sharedSecret: List<int>.filled(31, 0),
          pakeWords: goodPake,
          nonceRandom: fixedRng(),
        ),
        throwsArgumentError,
      );
    });
  });

  group('domain separation', () {
    test(
      'same W + same nonce with different payload types produces distinct ciphertexts',
      () async {
        // We use the same nonce via the same seeded RNG; differing payload-
        // type bytes should produce differing ciphertexts because HKDF info
        // strings differ.
        final publicKey = List<int>.generate(32, (i) => i);
        final ldpWire = await TransportPackage.encodeLdp(
          publicKey: publicKey,
          labelHint: 'Mom',
          pakeWords: goodPake,
          now: DateTime.utc(2026, 4, 18, 12, 0),
          nonceRandom: fixedRng(99),
        );
        // Same W, same timestamp, same nonce seed → but LPR payload & info.
        final lprWire = await TransportPackage.encodeLpr(
          label: 'Mom',
          role: PairRole.a,
          pairedAt: DateTime.utc(2026, 1, 1),
          silentHaptics: false,
          sharedSecret: List<int>.generate(32, (i) => i),
          pakeWords: goodPake,
          now: DateTime.utc(2026, 4, 18, 12, 0),
          nonceRandom: fixedRng(99),
        );
        expect(ldpWire == lprWire, isFalse);
      },
    );
  });

  group('PAKE input normalization', () {
    test('upper-cased + whitespace-padded input still decrypts', () async {
      final wire = await TransportPackage.encodeLdp(
        publicKey: Uint8List(32),
        labelHint: 'Mom',
        pakeWords: goodPake,
        nonceRandom: fixedRng(),
      );
      final noisy =
          goodPake.map((w) => ' ${w.toUpperCase()}  ').toList();
      final decoded =
          await TransportPackage.decodeLdp(wire, pakeWords: noisy);
      expect(decoded.labelHint, 'Mom');
    });
  });
}
