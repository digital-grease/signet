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

      final decoded = await TransportPackage.decodeLdp(
        wire,
        pakeWords: goodPake,
      );
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
      final decoded = await TransportPackage.decodeLdp(
        wire,
        pakeWords: goodPake,
      );
      expect(decoded.labelHint, '');
    });

    test('rejects mismatched PAKE secret with InvalidPakeException', () async {
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

    test('v1: flipping any byte outside the header timestamp fails', () async {
      // C4: the old test flipped one character that happened to land in the
      // nonce. v1 does not authenticate the header timestamp (bytes 2-9);
      // that gap is closed by version 2 (see the v2 group below).
      final wire = await TransportPackage.encodeLdp(
        publicKey: publicKey,
        labelHint: labelHint,
        pakeWords: goodPake,
        nonceRandom: fixedRng(),
      );
      final original = _decodeBase64Url(wire.substring('signet:tp1:'.length));
      for (var i = 0; i < original.length; i++) {
        if (i >= 2 && i < 10) continue;
        final b = List<int>.of(original);
        b[i] ^= 0x01;
        await expectLater(
          TransportPackage.decodeLdp(
            'signet:tp1:${_encodeBase64UrlNoPad(b)}',
            pakeWords: goodPake,
          ),
          throwsA(
            anyOf(isA<InvalidPakeException>(), isA<InvalidPackageException>()),
          ),
          reason: 'byte $i',
        );
      }
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
      final decoded = await TransportPackage.decodeLpr(
        wire,
        pakeWords: goodPake,
      );
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
      final decoded = await TransportPackage.decodeLpr(
        wire,
        pakeWords: goodPake,
      );
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
    // C4: the old test compared two packages with different plaintexts, so
    // it passed even if the HKDF info strings were identical. This one
    // relabels the payload-type byte of a real package: decryption under the
    // other type's key must fail.
    for (final version in [1, 2]) {
      test(
        'v$version: an LDP relabelled as LPR fails authentication',
        () async {
          final wire = await TransportPackage.encodeLdp(
            publicKey: List<int>.generate(32, (i) => i),
            labelHint: 'Mom',
            pakeWords: goodPake,
            version: version,
          );
          final b = _decodeBase64Url(wire.substring('signet:tp1:'.length));
          b[1] = 0x02; // LPR
          await expectLater(
            TransportPackage.decodeLpr(
              'signet:tp1:${_encodeBase64UrlNoPad(b)}',
              pakeWords: goodPake,
            ),
            throwsA(isA<InvalidPakeException>()),
          );
        },
      );
    }
  });

  group('PAKE input normalization', () {
    test('upper-cased + whitespace-padded input still decrypts', () async {
      final wire = await TransportPackage.encodeLdp(
        publicKey: Uint8List(32),
        labelHint: 'Mom',
        pakeWords: goodPake,
        nonceRandom: fixedRng(),
      );
      final noisy = goodPake.map((w) => ' ${w.toUpperCase()}  ').toList();
      final decoded = await TransportPackage.decodeLdp(wire, pakeWords: noisy);
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
    }) => BlkRelationshipRecord(
      sharedSecret: Uint8List.fromList(
        List<int>.generate(32, (i) => (i + secretSeed) & 0xFF),
      ),
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
      final decoded = await TransportPackage.decodeBlk(
        wire,
        pakeWords: goodPake,
      );
      expect(decoded.records, isEmpty);
      expect(decoded.timestamp.toUtc(), DateTime.utc(2026, 4, 22, 1, 2, 3));
    });

    test(
      'single-record round-trip hydrates identically to LPR fields',
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
        final decoded = await TransportPackage.decodeBlk(
          wire,
          pakeWords: goodPake,
        );
        expect(decoded.records, hasLength(1));
        final r = decoded.records.single;
        expect(r.sharedSecret, record.sharedSecret);
        expect(r.role, PairRole.b);
        expect(r.label, 'Mom');
        expect(r.pairedAt.toUtc(), DateTime.utc(2026, 2, 14, 15, 3));
        expect(r.silentHaptics, isTrue);
      },
    );

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
      final decoded = await TransportPackage.decodeBlk(
        wire,
        pakeWords: goodPake,
      );
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
      final decoded = await TransportPackage.decodeBlk(
        wire,
        pakeWords: goodPake,
      );
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
      final bad = makeRecord(secretSeed: 0, role: PairRole.a, label: 'x' * 65);
      await expectLater(
        TransportPackage.encodeBlk(records: [bad], pakeWords: goodPake),
        throwsArgumentError,
      );
    });

    test('rejects mismatched PAKE with InvalidPakeException', () async {
      final wire = await TransportPackage.encodeBlk(
        records: [makeRecord(secretSeed: 1, role: PairRole.a, label: 'Mom')],
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
          records: [makeRecord(secretSeed: 5, role: PairRole.a, label: 'Mom')],
          pakeWords: goodPake,
          nonceRandom: fixedRng(),
        );
        final body = _decodeBase64Url(blkWire.substring('signet:tp1:'.length));
        expect(body[1], 0x03, reason: 'sanity: BLK payload-type byte');
        final tampered = List<int>.from(body);
        tampered[1] = 0x02; // pretend it's an LPR.
        final tamperedWire = 'signet:tp1:${_encodeBase64UrlNoPad(tampered)}';
        await expectLater(
          TransportPackage.decodeLpr(tamperedWire, pakeWords: goodPake),
          throwsA(isA<InvalidPakeException>()),
        );
      },
    );
  });

  // ==========================================================================
  // Version 2 (plan Task 1.6): authenticated header, versioned KDF domain,
  // extension area, forward-compatible failure semantics.
  // ==========================================================================

  final secret = List<int>.generate(32, (i) => 100 + i);
  final pubKey = List<int>.generate(32, (i) => 200 - i);
  final fixedNow = DateTime.utc(2026, 10, 7, 12);

  List<int> body(String wire) => _decodeBase64Url(wire.substring(11));
  String wireOf(List<int> b) => 'signet:tp1:${_encodeBase64UrlNoPad(b)}';

  /// LPR plaintext fields (no extension area).
  List<int> lprFields({
    List<int>? secretBytes,
    int role = 0x01,
    List<int> label = const [0x4d, 0x6f, 0x6d], // "Mom"
    List<int>? pairedAt,
    int silent = 0,
  }) => <int>[
    ...(secretBytes ?? secret),
    role,
    label.length,
    ...label,
    ...(pairedAt ?? const [0, 0, 0, 0, 0x69, 0x8d, 0x1d, 0x00]),
    silent,
  ];

  List<int> ext(List<List<int>> tlvs) {
    final b = <int>[for (final t in tlvs) ...t];
    return <int>[(b.length >> 8) & 0xFF, b.length & 0xFF, ...b];
  }

  List<int> tlv(int tag, List<int> value) => <int>[
    tag,
    (value.length >> 8) & 0xFF,
    value.length & 0xFF,
    ...value,
  ];

  group('v2 round trips', () {
    test('LDP v2 round-trips and reports its version', () async {
      final wire = await TransportPackage.encodeLdp(
        publicKey: pubKey,
        labelHint: 'Alice',
        pakeWords: goodPake,
        version: 2,
        now: fixedNow,
      );
      expect(body(wire)[0], 2);
      final ldp = await TransportPackage.decodeLdp(wire, pakeWords: goodPake);
      expect(ldp.publicKey, pubKey);
      expect(ldp.labelHint, 'Alice');
      expect(ldp.version, 2);
      expect(ldp.timestamp, fixedNow);
    });

    test('LPR v2 and BLK v2 round-trip', () async {
      final lpr = await TransportPackage.decodeLpr(
        await TransportPackage.encodeLpr(
          label: 'Mom',
          role: PairRole.b,
          pairedAt: DateTime.utc(2026, 1, 1),
          silentHaptics: true,
          sharedSecret: secret,
          pakeWords: goodPake,
          version: 2,
        ),
        pakeWords: goodPake,
      );
      expect(
        (lpr.label, lpr.role, lpr.silentHaptics, lpr.version),
        ('Mom', PairRole.b, true, 2),
      );
      expect(lpr.repaired, isFalse);

      final blk = await TransportPackage.decodeBlk(
        await TransportPackage.encodeBlk(
          records: [
            for (final label in ['A', 'B', 'C'])
              BlkRelationshipRecord(
                sharedSecret: Uint8List.fromList(secret),
                role: PairRole.a,
                label: label,
                pairedAt: DateTime.utc(2026, 1, 1),
                silentHaptics: false,
                extensions: label == 'B'
                    ? const {
                        0x01: [9, 9],
                      }
                    : const <int, List<int>>{},
              ),
          ],
          pakeWords: goodPake,
          version: 2,
        ),
        pakeWords: goodPake,
      );
      expect(blk.records.map((r) => r.label), ['A', 'B', 'C']);
      expect(blk.records[1].extensions[0x01], [
        9,
        9,
      ], reason: 'per-record TLVs keep records delimited');
      expect(blk.version, 2);
    });

    test('this release still encodes version 1 by default', () async {
      final wire = await TransportPackage.encodeLdp(
        publicKey: pubKey,
        labelHint: '',
        pakeWords: goodPake,
      );
      expect(body(wire)[0], 1);
      expect(TransportPackage.currentEncodeVersion, 1);
    });

    test('extensions on a version 1 package are refused', () async {
      expect(
        () => TransportPackage.encodeLdp(
          publicKey: pubKey,
          labelHint: '',
          pakeWords: goodPake,
          version: 1,
          extensions: const [
            TransportExtension(1, [1]),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('v2 header authentication', () {
    test('flipping any header byte (version, type, timestamp) fails', () async {
      final wire = await TransportPackage.encodeLpr(
        label: 'Mom',
        role: PairRole.a,
        pairedAt: DateTime.utc(2026, 1, 1),
        silentHaptics: false,
        sharedSecret: secret,
        pakeWords: goodPake,
        version: 2,
        now: fixedNow,
      );
      for (var i = 2; i < 10; i++) {
        final b = body(wire);
        b[i] ^= 0x01;
        await expectLater(
          TransportPackage.decodeLpr(wireOf(b), pakeWords: goodPake),
          throwsA(isA<InvalidPakeException>()),
          reason: 'timestamp byte $i is authenticated',
        );
      }
    });

    test('every byte of a v2 body is protected', () async {
      final wire = await TransportPackage.encodeLdp(
        publicKey: pubKey,
        labelHint: 'Alice',
        pakeWords: goodPake,
        version: 2,
      );
      final length = body(wire).length;
      for (var i = 0; i < length; i++) {
        final b = body(wire);
        b[i] ^= 0x01;
        await expectLater(
          TransportPackage.decodeLdp(wireOf(b), pakeWords: goodPake),
          // Bytes 0 and 1 (version, type) are checked before decryption;
          // from byte 2 on (timestamp, nonce, ciphertext, tag) only the
          // AEAD can catch a change, so it must be an authentication
          // failure.
          throwsA(i < 2
              ? isA<InvalidPackageException>()
              : isA<InvalidPakeException>()),
          reason: 'byte $i',
        );
      }
    });

    test('relabelling v2 as v1, or v1 as v2, fails authentication', () async {
      for (final from in [1, 2]) {
        final wire = await TransportPackage.encodeLdp(
          publicKey: pubKey,
          labelHint: 'Alice',
          pakeWords: goodPake,
          version: from,
        );
        final b = body(wire)..[0] = from == 1 ? 2 : 1;
        await expectLater(
          TransportPackage.decodeLdp(wireOf(b), pakeWords: goodPake),
          throwsA(isA<InvalidPakeException>()),
        );
      }
    });

    test(
      'v1 header is unauthenticated (the reason v2 exists), but an '
      'out-of-range v1 timestamp is a clean error, not a RangeError',
      () async {
        final wire = await TransportPackage.encodeLpr(
          label: 'Mom',
          role: PairRole.a,
          pairedAt: DateTime.utc(2026, 1, 1),
          silentHaptics: false,
          sharedSecret: secret,
          pakeWords: goodPake,
          version: 1,
        );
        final tampered = body(wire)..[2] = 0x7f;
        await expectLater(
          TransportPackage.decodeLpr(wireOf(tampered), pakeWords: goodPake),
          throwsA(isA<InvalidPackageException>()),
        );
      },
    );
  });

  group('versions this build cannot read', () {
    test('peekPayloadType reads v1 and v2, throws for v3+', () async {
      for (final v in [1, 2]) {
        final wire = await TransportPackage.encodeLpr(
          label: 'Mom',
          role: PairRole.a,
          pairedAt: DateTime.utc(2026, 1, 1),
          silentHaptics: false,
          sharedSecret: secret,
          pakeWords: goodPake,
          version: v,
        );
        expect(
          TransportPackage.peekPayloadType(wire),
          TransportPayloadType.lpr,
        );
        final v3 = body(wire)..[0] = 3;
        expect(
          () => TransportPackage.peekPayloadType(wireOf(v3)),
          throwsA(isA<UnsupportedPackageVersionException>()),
        );
        await expectLater(
          TransportPackage.decodeLpr(wireOf(v3), pakeWords: goodPake),
          throwsA(isA<UnsupportedPackageVersionException>()),
        );
        final unknownType = body(wire)..[1] = 0x09;
        if (v == 1) {
          expect(TransportPackage.peekPayloadType(wireOf(unknownType)),
              isNull);
        } else {
          // Version 2 can grow payload types: an unknown one is from a
          // newer Signet.
          expect(() => TransportPackage.peekPayloadType(wireOf(unknownType)),
              throwsA(isA<UnsupportedPackageVersionException>()));
          await expectLater(
            TransportPackage.decodeLpr(wireOf(unknownType),
                pakeWords: goodPake),
            throwsA(isA<UnsupportedPackageVersionException>()),
          );
        }
      }
    });

    test('a truncated package from a newer Signet still asks to update',
        () async {
      // Reviewer finding: the length check used to run first, so a short
      // version-3 wire showed a raw "body too short" error on the LDP
      // screens.
      await expectLater(
        TransportPackage.decodeLdp('signet:tp1:AwI', pakeWords: goodPake),
        throwsA(isA<UnsupportedPackageVersionException>()),
      );
    });

    test(
      'an unknown critical extension asks for a newer Signet (LDP, LPR)',
      () async {
        final ldpWire = await TransportPackage.encodeLdp(
          publicKey: pubKey,
          labelHint: '',
          pakeWords: goodPake,
          version: 2,
          extensions: const [
            TransportExtension(0x81, [1]),
          ],
        );
        await expectLater(
          TransportPackage.decodeLdp(ldpWire, pakeWords: goodPake),
          throwsA(isA<UnsupportedPackageVersionException>()),
        );
        final lprWire = await TransportPackage.encodeLpr(
          label: 'Mom',
          role: PairRole.a,
          pairedAt: DateTime.utc(2026, 1, 1),
          silentHaptics: false,
          sharedSecret: secret,
          pakeWords: goodPake,
          version: 2,
          extensions: const [
            TransportExtension(0x81, [1]),
          ],
        );
        await expectLater(
          TransportPackage.decodeLpr(lprWire, pakeWords: goodPake),
          throwsA(isA<UnsupportedPackageVersionException>()),
        );
      },
    );

    test('an unknown non-critical extension is ignored and exposed', () async {
      final wire = await TransportPackage.encodeLdp(
        publicKey: pubKey,
        labelHint: 'Alice',
        pakeWords: goodPake,
        version: 2,
        extensions: const [
          TransportExtension(0x05, [7, 8]),
        ],
      );
      final ldp = await TransportPackage.decodeLdp(wire, pakeWords: goodPake);
      expect(ldp.labelHint, 'Alice');
      expect(ldp.extensions[0x05], [7, 8]);
    });

    test(
      'BLK skips only the record with an unknown critical extension',
      () async {
        final wire = await TransportPackage.encodeBlk(
          records: [
            for (final (label, ext) in [
              ('A', <int, List<int>>{}),
              (
                'B',
                <int, List<int>>{
                  0x90: [1],
                },
              ),
              (
                'C',
                <int, List<int>>{
                  0x02: [2],
                },
              ),
            ])
              BlkRelationshipRecord(
                sharedSecret: Uint8List.fromList(secret),
                role: PairRole.a,
                label: label,
                pairedAt: DateTime.utc(2026, 1, 1),
                silentHaptics: false,
                extensions: ext,
              ),
          ],
          pakeWords: goodPake,
          version: 2,
        );
        final blk = await TransportPackage.decodeBlk(wire, pakeWords: goodPake);
        expect(blk.records.map((r) => r.label), ['A', 'C']);
        expect(blk.skippedNeedsNewerVersion, 1);
      },
    );
  });

  group('structurally broken v2 extension areas reject the package', () {
    Future<void> expectRejected(List<int> extArea) async {
      final wire = await TransportPackage.debugEncodeRaw(
        version: 2,
        payloadType: TransportPayloadType.lpr,
        plaintext: [...lprFields(), ...extArea],
        pakeWords: goodPake,
      );
      await expectLater(
        TransportPackage.decodeLpr(wire, pakeWords: goodPake),
        throwsA(
          isA<InvalidPackageException>().having(
            (e) => e is UnsupportedPackageVersionException,
            'is version error',
            isFalse,
          ),
        ),
      );
    }

    test('overrun: ext_len longer than the payload', () async {
      await expectRejected([0x00, 0x09, 0x01, 0x00, 0x01, 0x07]);
    });
    test('truncated TLV header', () async {
      await expectRejected([0x00, 0x02, 0x01, 0x00]);
    });
    test('TLV value overruns the area', () async {
      await expectRejected([0x00, 0x04, 0x01, 0x00, 0x05, 0x07]);
    });
    test('repeated tag', () async {
      await expectRejected(
        ext([
          tlv(1, [1]),
          tlv(1, [2]),
        ]),
      );
    });
    test('missing ext_len entirely', () async {
      await expectRejected(const <int>[]);
    });
    test('trailing bytes after the extension area', () async {
      await expectRejected([...ext([]), 0x00]);
    });
  });

  group('damaged fields are repaired, never crash or drop a secret', () {
    final badDates = <String, List<int>>{
      'high bit set (negative)': [0x80, 0, 0, 0, 0, 0, 0, 1],
      'beyond year 9999': [0, 0, 0x01, 0, 0, 0, 0, 0],
    };
    for (final v in [1, 2]) {
      for (final entry in badDates.entries) {
        test(
          'v$v LPR pairedAt ${entry.key} is reset to now and flagged',
          () async {
            final wire = await TransportPackage.debugEncodeRaw(
              version: v,
              payloadType: TransportPayloadType.lpr,
              plaintext: [
                ...lprFields(pairedAt: entry.value),
                if (v == 2) ...ext([]),
              ],
              pakeWords: goodPake,
            );
            final lpr = await TransportPackage.decodeLpr(
              wire,
              pakeWords: goodPake,
              now: fixedNow,
            );
            expect(lpr.pairedAt, fixedNow);
            expect(lpr.repaired, isTrue);
            expect(lpr.sharedSecret, secret);
          },
        );
      }

      test('v$v invalid UTF-8 label is replaced and flagged', () async {
        final wire = await TransportPackage.debugEncodeRaw(
          version: v,
          payloadType: TransportPayloadType.lpr,
          plaintext: [
            ...lprFields(label: const [0x4d, 0xff, 0xfe]),
            if (v == 2) ...ext([]),
          ],
          pakeWords: goodPake,
        );
        final lpr = await TransportPackage.decodeLpr(wire, pakeWords: goodPake);
        expect(lpr.label, startsWith('M'));
        expect(lpr.label, contains('�'));
        expect(lpr.repaired, isTrue);
      });

      test(
        'v$v BLK: one damaged record is repaired, the rest are intact',
        () async {
          final good = lprFields();
          final bad = lprFields(pairedAt: const [0xff, 0, 0, 0, 0, 0, 0, 0]);
          final wire = await TransportPackage.debugEncodeRaw(
            version: v,
            payloadType: TransportPayloadType.blk,
            plaintext: [
              0x00,
              0x02,
              ...good,
              if (v == 2) ...ext([]),
              ...bad,
              if (v == 2) ...ext([]),
            ],
            pakeWords: goodPake,
          );
          final blk = await TransportPackage.decodeBlk(
            wire,
            pakeWords: goodPake,
            now: fixedNow,
          );
          expect(blk.records, hasLength(2));
          expect(blk.records[0].repaired, isFalse);
          expect(blk.records[1].repaired, isTrue);
          expect(blk.records[1].pairedAt, fixedNow);
          expect(blk.repairedCount, 1);
        },
      );
    }

    test('v1 LPR with trailing bytes is rejected', () async {
      final wire = await TransportPackage.debugEncodeRaw(
        version: 1,
        payloadType: TransportPayloadType.lpr,
        plaintext: [...lprFields(), 0x00],
        pakeWords: goodPake,
      );
      await expectLater(
        TransportPackage.decodeLpr(wire, pakeWords: goodPake),
        throwsA(isA<InvalidPackageException>()),
      );
    });

    test('v1 LDP with trailing bytes is rejected', () async {
      final wire = await TransportPackage.debugEncodeRaw(
        version: 1,
        payloadType: TransportPayloadType.ldp,
        plaintext: [...pubKey, 0, 0x00],
        pakeWords: goodPake,
      );
      await expectLater(
        TransportPackage.decodeLdp(wire, pakeWords: goodPake),
        throwsA(isA<InvalidPackageException>()),
      );
    });
  });

  group('review round 2 hardening', () {
    test('peek and decode agree on a 1- or 2-byte version 3 body', () async {
      for (final wire in ['signet:tp1:Aw', 'signet:tp1:AwI']) {
        expect(() => TransportPackage.peekPayloadType(wire),
            throwsA(isA<UnsupportedPackageVersionException>()));
        await expectLater(
          TransportPackage.decodeLpr(wire, pakeWords: goodPake),
          throwsA(isA<UnsupportedPackageVersionException>()),
        );
      }
    });

    test('a pre-authentication version verdict is marked unauthenticated',
        () async {
      try {
        await TransportPackage.decodeLpr('signet:tp1:AwI', pakeWords: goodPake);
        fail('expected UnsupportedPackageVersionException');
      } on UnsupportedPackageVersionException catch (e) {
        expect(e.authenticated, isFalse);
      }
    });

    test('an unknown critical tag inside the payload is authenticated',
        () async {
      final wire = await TransportPackage.encodeLpr(
        label: 'Mom',
        role: PairRole.a,
        pairedAt: DateTime.utc(2026, 1, 1),
        silentHaptics: false,
        sharedSecret: secret,
        pakeWords: goodPake,
        version: 2,
        extensions: const [TransportExtension(0x81, [1])],
      );
      try {
        await TransportPackage.decodeLpr(wire, pakeWords: goodPake);
        fail('expected UnsupportedPackageVersionException');
      } on UnsupportedPackageVersionException catch (e) {
        expect(e.authenticated, isTrue);
      }
    });

    test('reserved tags 0x00 and 0x80 are refused by encoder and decoder',
        () async {
      for (final tag in [0x00, 0x80]) {
        expect(
          () => TransportPackage.encodeLdp(
            publicKey: pubKey,
            labelHint: '',
            pakeWords: goodPake,
            version: 2,
            extensions: [TransportExtension(tag, const [1])],
          ),
          throwsArgumentError,
        );
        final wire = await TransportPackage.debugEncodeRaw(
          version: 2,
          payloadType: TransportPayloadType.lpr,
          plaintext: [
            ...lprFields(),
            ...ext([tlv(tag, [1])]),
          ],
          pakeWords: goodPake,
        );
        await expectLater(
          TransportPackage.decodeLpr(wire, pakeWords: goodPake),
          throwsA(isA<InvalidPackageException>().having(
              (e) => e is UnsupportedPackageVersionException,
              'is version error',
              isFalse)),
        );
      }
    });

    test('the encoder refuses a pairing date outside 1970-9999', () {
      expect(
        () => TransportPackage.encodeLpr(
          label: 'Mom',
          role: PairRole.a,
          pairedAt: DateTime.utc(1969, 12, 31),
          silentHaptics: false,
          sharedSecret: secret,
          pakeWords: goodPake,
        ),
        throwsArgumentError,
      );
    });

    test('an over-long label is truncated to the limit and flagged', () async {
      final wire = await TransportPackage.debugEncodeRaw(
        version: 1,
        payloadType: TransportPayloadType.lpr,
        plaintext: lprFields(label: List<int>.filled(80, 0x41)), // 80 x 'A'
        pakeWords: goodPake,
      );
      final lpr = await TransportPackage.decodeLpr(wire, pakeWords: goodPake);
      expect(lpr.label, 'A' * 64);
      expect(lpr.labelRepaired, isTrue);
      expect(lpr.pairedAtRepaired, isFalse);
    });

    test('a must-understand BLK record is skipped even with a bad role byte',
        () async {
      final skippable = [
        ...lprFields(role: 0x03),
        ...ext([tlv(0x90, [1])]),
      ];
      final good = [...lprFields(), ...ext([])];
      final wire = await TransportPackage.debugEncodeRaw(
        version: 2,
        payloadType: TransportPayloadType.blk,
        plaintext: [0x00, 0x02, ...skippable, ...good],
        pakeWords: goodPake,
      );
      final blk = await TransportPackage.decodeBlk(wire, pakeWords: goodPake);
      expect(blk.records, hasLength(1));
      expect(blk.skippedNeedsNewerVersion, 1);
    });

    test('a bad role byte without a must-understand field is still rejected',
        () async {
      final wire = await TransportPackage.debugEncodeRaw(
        version: 2,
        payloadType: TransportPayloadType.lpr,
        plaintext: [...lprFields(role: 0x03), ...ext([])],
        pakeWords: goodPake,
      );
      await expectLater(
        TransportPackage.decodeLpr(wire, pakeWords: goodPake),
        throwsA(isA<InvalidPackageException>()),
      );
    });

    test('v2 LDP with bytes after the extension area is rejected', () async {
      final wire = await TransportPackage.debugEncodeRaw(
        version: 2,
        payloadType: TransportPayloadType.ldp,
        plaintext: [...pubKey, 0, ...ext([]), 0x00],
        pakeWords: goodPake,
      );
      await expectLater(
        TransportPackage.decodeLdp(wire, pakeWords: goodPake),
        throwsA(isA<InvalidPackageException>()),
      );
    });

    test('v2 BLK whose count is lower than the records present is rejected',
        () async {
      final record = [...lprFields(), ...ext([])];
      final wire = await TransportPackage.debugEncodeRaw(
        version: 2,
        payloadType: TransportPayloadType.blk,
        plaintext: [0x00, 0x01, ...record, ...record],
        pakeWords: goodPake,
      );
      await expectLater(
        TransportPackage.decodeBlk(wire, pakeWords: goodPake),
        throwsA(isA<InvalidPackageException>()),
      );
    });
  });

  group('compatibility fixtures', () {
    // Produced by the v0.3.6 codec (the commit before tp1 v2) with these
    // exact inputs. Every backup a user already holds looks like this.
    const v036Lpr =
        'signet:tp1:AQIAAAAAahzLgKRz_3uzzciZoE3qD1EvmPUrnUWE7y-kvrjUfcMc_GYU75GMFxXvEFIZDRWBrPUFw6SaZ70b69DofF5ep-EhB703G836dSxM5vTB';
    const v036Ldp =
        'signet:tp1:AQEAAAAAahzLgGlxPBQuch-zFon8DacvpNcefA9p-HZvNUAAmVcdpHmmiOXMQkMDRlVI165lm-TVtZG2PjaUW4ZemVMBpvRuhnoYmw';
    final june = DateTime.utc(2026, 6, 1);

    test('packages made by v0.3.6 still decode', () async {
      final lpr = await TransportPackage.decodeLpr(
        v036Lpr,
        pakeWords: goodPake,
      );
      expect(lpr.sharedSecret, List<int>.generate(32, (i) => 100 + i));
      expect(
        (lpr.label, lpr.role, lpr.silentHaptics, lpr.version),
        ('Mom', PairRole.b, true, 1),
      );
      expect(lpr.pairedAt, DateTime.utc(2026, 1, 1));
      expect(lpr.repaired, isFalse);
      final ldp = await TransportPackage.decodeLdp(
        v036Ldp,
        pakeWords: goodPake,
      );
      expect(ldp.publicKey, List<int>.generate(32, (i) => 200 - i));
      expect(ldp.labelHint, 'Alice');
      expect(ldp.version, 1);
    });

    test('version 1 encoding is byte-identical to v0.3.6', () async {
      expect(
        await TransportPackage.encodeLpr(
          label: 'Mom',
          role: PairRole.b,
          pairedAt: DateTime.utc(2026, 1, 1),
          silentHaptics: true,
          sharedSecret: List<int>.generate(32, (i) => 100 + i),
          pakeWords: goodPake,
          now: june,
          nonceRandom: Random(1),
        ),
        v036Lpr,
      );
      expect(
        await TransportPackage.encodeLdp(
          publicKey: List<int>.generate(32, (i) => 200 - i),
          labelHint: 'Alice',
          pakeWords: goodPake,
          now: june,
          nonceRandom: Random(2),
        ),
        v036Ldp,
      );
    });

    // Bulk backup made by the v0.3.6 codec (two records, one with a
    // multibyte label).
    const v036Blk =
        'signet:tp1:AQMAAAAAahzLgEc3Vn_XdLnoPuUca7An0tWpcsvZlMOCYlinzlGfEXA7fBQVTWNxGdsDI_9n-yQCAscmOvOH6Ub5j9mdBb-JArp4wtf7_oz_n4SU_HHitbbHTbVqh98gUNkhARdqNXj4r86qPK4zicITB8-lF65m6GIwSyu7qpl0jqMUfIrdJA';
    final v036BlkRecords = [
      BlkRelationshipRecord(
        sharedSecret: Uint8List.fromList(List<int>.generate(32, (i) => i)),
        role: PairRole.a,
        label: 'Mom',
        pairedAt: DateTime.utc(2026, 1, 1),
        silentHaptics: false,
      ),
      BlkRelationshipRecord(
        sharedSecret: Uint8List.fromList(List<int>.generate(32, (i) => 255 - i)),
        role: PairRole.b,
        label: 'Jürgen',
        pairedAt: DateTime.utc(2025, 7, 4),
        silentHaptics: true,
      ),
    ];

    test('bulk backups made by v0.3.6 decode, and v1 BLK encoding is '
        'byte-identical', () async {
      final blk = await TransportPackage.decodeBlk(v036Blk, pakeWords: goodPake);
      expect(blk.version, 1);
      expect(blk.records.map((r) => r.label), ['Mom', 'Jürgen']);
      expect(blk.records[1].sharedSecret, v036BlkRecords[1].sharedSecret);
      expect(blk.records[1].role, PairRole.b);
      expect(blk.records[1].silentHaptics, isTrue);
      expect(blk.repairedCount, 0);
      expect(
        await TransportPackage.encodeBlk(
          records: v036BlkRecords,
          pakeWords: goodPake,
          now: june,
          nonceRandom: Random(3),
        ),
        v036Blk,
      );
    });

    test('version 2 golden vector (pins KDF domain, AAD and layout)', () async {
      final wire = await TransportPackage.encodeLpr(
        label: 'Mom',
        role: PairRole.b,
        pairedAt: DateTime.utc(2026, 1, 1),
        silentHaptics: true,
        sharedSecret: List<int>.generate(32, (i) => 100 + i),
        pakeWords: goodPake,
        now: june,
        nonceRandom: Random(1),
        version: 2,
        extensions: const [
          TransportExtension(0x01, [0x65, 0x73]),
        ],
      );
      expect(wire, _v2Golden);
    });
  });
}

List<int> _decodeBase64Url(String input) {
  final padding = (4 - input.length % 4) % 4;
  return base64Url.decode(input + '=' * padding);
}

String _encodeBase64UrlNoPad(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

// Captured from this implementation; any change to the v2 KDF domain,
// header authentication or payload layout must change it deliberately.
const _v2Golden =
    'signet:tp1:AgIAAAAAahzLgKRz_3uzzciZoE3qDxhGamevO2PE3PjwOwtnuijEvKEzGUwMIeY3LZ_oj2HF7kZ8fRWNZz-wtS2cN9MJNEoa27g3c3mq4X7UvyeNvFHh19mwsA';
