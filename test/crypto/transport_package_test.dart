import 'dart:convert';
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

  group('BLK — bulk backup', () {
    BlkRelationshipRecord makeRecord({
      required int secretSeed,
      required PairRole role,
      required String label,
      DateTime? pairedAt,
      bool silentHaptics = false,
    }) =>
        BlkRelationshipRecord(
          sharedSecret:
              Uint8List.fromList(List<int>.generate(32, (i) => (i + secretSeed) & 0xFF)),
          role: role,
          label: label,
          pairedAt: pairedAt ?? DateTime.utc(2026, 1, 1),
          silentHaptics: silentHaptics,
        );

    test('empty bundle (N=0) round-trips', () async {
      final wire = await TransportPackage.encodeBlk(
        records: const [],
        pakeWords: goodPake,
        now: DateTime.utc(2026, 4, 22, 1, 2, 3),
        nonceRandom: fixedRng(),
      );
      expect(wire.startsWith('signet:tp1:'), isTrue);
      final decoded =
          await TransportPackage.decodeBlk(wire, pakeWords: goodPake);
      expect(decoded.records, isEmpty);
      expect(decoded.timestamp.toUtc(), DateTime.utc(2026, 4, 22, 1, 2, 3));
    });

    test('single-record round-trip hydrates identically to LPR fields',
        () async {
      final record = makeRecord(
        secretSeed: 17,
        role: PairRole.b,
        label: 'Mom',
        pairedAt: DateTime.utc(2026, 2, 14, 15, 3),
        silentHaptics: true,
      );
      final wire = await TransportPackage.encodeBlk(
        records: [record],
        pakeWords: goodPake,
        nonceRandom: fixedRng(),
      );
      final decoded =
          await TransportPackage.decodeBlk(wire, pakeWords: goodPake);
      expect(decoded.records, hasLength(1));
      final r = decoded.records.single;
      expect(r.sharedSecret, record.sharedSecret);
      expect(r.role, PairRole.b);
      expect(r.label, 'Mom');
      expect(r.pairedAt.toUtc(), DateTime.utc(2026, 2, 14, 15, 3));
      expect(r.silentHaptics, isTrue);
    });

    test('N=3 round-trip preserves order + per-record field mix', () async {
      final records = <BlkRelationshipRecord>[
        makeRecord(
          secretSeed: 1,
          role: PairRole.a,
          label: 'Mom',
          pairedAt: DateTime.utc(2025, 12, 1),
          silentHaptics: false,
        ),
        makeRecord(
          secretSeed: 2,
          role: PairRole.b,
          label: 'Dad',
          pairedAt: DateTime.utc(2026, 1, 15),
          silentHaptics: true,
        ),
        makeRecord(
          secretSeed: 3,
          role: PairRole.a,
          label: '', // empty label edge-case
          pairedAt: DateTime.utc(2026, 3, 3),
          silentHaptics: false,
        ),
      ];
      final wire = await TransportPackage.encodeBlk(
        records: records,
        pakeWords: goodPake,
        nonceRandom: fixedRng(),
      );
      final decoded =
          await TransportPackage.decodeBlk(wire, pakeWords: goodPake);
      expect(decoded.records, hasLength(3));
      for (var i = 0; i < records.length; i++) {
        expect(decoded.records[i].sharedSecret, records[i].sharedSecret);
        expect(decoded.records[i].role, records[i].role);
        expect(decoded.records[i].label, records[i].label);
        expect(
          decoded.records[i].pairedAt.toUtc(),
          records[i].pairedAt.toUtc(),
        );
        expect(decoded.records[i].silentHaptics, records[i].silentHaptics);
      }
    });

    test('N=255 (max) round-trip', () async {
      final records = List<BlkRelationshipRecord>.generate(
        255,
        (i) => makeRecord(
          secretSeed: i,
          role: i.isEven ? PairRole.a : PairRole.b,
          label: 'peer-$i',
        ),
      );
      final wire = await TransportPackage.encodeBlk(
        records: records,
        pakeWords: goodPake,
        nonceRandom: fixedRng(),
      );
      final decoded =
          await TransportPackage.decodeBlk(wire, pakeWords: goodPake);
      expect(decoded.records, hasLength(255));
      expect(decoded.records.first.label, 'peer-0');
      expect(decoded.records.last.label, 'peer-254');
    });

    test('rejects > 255 records on encode', () async {
      final tooMany = List<BlkRelationshipRecord>.generate(
        256,
        (i) => makeRecord(secretSeed: i, role: PairRole.a, label: 'x'),
      );
      await expectLater(
        TransportPackage.encodeBlk(records: tooMany, pakeWords: goodPake),
        throwsArgumentError,
      );
    });

    test('rejects wrong-length shared secret in a record', () async {
      final bad = BlkRelationshipRecord(
        sharedSecret: Uint8List.fromList(List<int>.filled(31, 0)),
        role: PairRole.a,
        label: 'Mom',
        pairedAt: DateTime.utc(2026, 1, 1),
        silentHaptics: false,
      );
      await expectLater(
        TransportPackage.encodeBlk(records: [bad], pakeWords: goodPake),
        throwsArgumentError,
      );
    });

    test('rejects oversized label (>64 UTF-8 bytes) in a record', () async {
      final bad = makeRecord(
        secretSeed: 0,
        role: PairRole.a,
        label: 'x' * 65,
      );
      await expectLater(
        TransportPackage.encodeBlk(records: [bad], pakeWords: goodPake),
        throwsArgumentError,
      );
    });

    test('rejects mismatched PAKE with InvalidPakeException', () async {
      final wire = await TransportPackage.encodeBlk(
        records: [
          makeRecord(secretSeed: 1, role: PairRole.a, label: 'Mom'),
        ],
        pakeWords: goodPake,
        nonceRandom: fixedRng(),
      );
      final wrong = [...goodPake];
      wrong[0] = 'absurd';
      await expectLater(
        TransportPackage.decodeBlk(wire, pakeWords: wrong),
        throwsA(isA<InvalidPakeException>()),
      );
    });

    test('rejects LDP wire when trying to decode as BLK', () async {
      final ldpWire = await TransportPackage.encodeLdp(
        publicKey: List<int>.generate(32, (i) => i),
        labelHint: 'Mom',
        pakeWords: goodPake,
        nonceRandom: fixedRng(),
      );
      await expectLater(
        TransportPackage.decodeBlk(ldpWire, pakeWords: goodPake),
        throwsA(isA<InvalidPackageException>()),
      );
    });

    test('rejects LPR wire when trying to decode as BLK', () async {
      final lprWire = await TransportPackage.encodeLpr(
        label: 'Mom',
        role: PairRole.a,
        pairedAt: DateTime.utc(2026, 1, 1),
        silentHaptics: false,
        sharedSecret: List<int>.generate(32, (i) => i),
        pakeWords: goodPake,
        nonceRandom: fixedRng(),
      );
      await expectLater(
        TransportPackage.decodeBlk(lprWire, pakeWords: goodPake),
        throwsA(isA<InvalidPackageException>()),
      );
    });

    test(
      'payload-type confusion: BLK wire with byte[1] flipped to 0x02 fails LPR decode',
      () async {
        // Defends the HKDF domain-separation invariant: flipping the
        // payload-type byte between LPR (0x02) and BLK (0x03) must not
        // produce a wire that decrypts under the other type's info
        // string. If this regresses, an attacker could potentially
        // coerce a BLK plaintext into the LPR parser path.
        final blkWire = await TransportPackage.encodeBlk(
          records: [
            makeRecord(secretSeed: 5, role: PairRole.a, label: 'Mom'),
          ],
          pakeWords: goodPake,
          nonceRandom: fixedRng(),
        );
        final body = _decodeBase64Url(
          blkWire.substring('signet:tp1:'.length),
        );
        expect(body[1], 0x03, reason: 'sanity: BLK payload-type byte');
        final tampered = List<int>.from(body);
        tampered[1] = 0x02; // pretend it's an LPR.
        final tamperedWire =
            'signet:tp1:${_encodeBase64UrlNoPad(tampered)}';
        await expectLater(
          TransportPackage.decodeLpr(tamperedWire, pakeWords: goodPake),
          throwsA(isA<InvalidPakeException>()),
        );
      },
    );
  });
}

List<int> _decodeBase64Url(String input) {
  final padding = (4 - input.length % 4) % 4;
  return base64Url.decode(input + '=' * padding);
}

String _encodeBase64UrlNoPad(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
