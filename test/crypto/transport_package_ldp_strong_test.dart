// Long-distance pairing with the strong (8-word) phrase (plan Task 1.7g;
// pairing-commitment spike, owner decisions 2 and 4): requests and
// responses are tp1 version 2 and carry the critical strong-phrase tag;
// both sides refuse a package without it, so the flag cannot be stripped
// to force the weak 4-word phrase.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/transport_package.dart';

void main() {
  final key = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
  final words = TransportPackage.mintPakeWords();

  test('a request is version 2 with the strong-phrase tag', () async {
    final wire = await TransportPackage.encodeLdpRequest(
      publicKey: key,
      labelHint: 'Ana',
      pakeWords: words,
    );
    final generic = await TransportPackage.decodeLdp(wire, pakeWords: words);
    expect(generic.version, 2);
    expect(generic.extensions[TransportPackage.ldpStrongPhraseTag], [0x01]);
    expect(TransportPackage.ldpStrongPhraseTag & TransportPackage.criticalTagBit,
        isNot(0), reason: 'must-understand: an older decoder refuses it');

    final strict =
        await TransportPackage.decodeLdpStrict(wire, pakeWords: words);
    expect(strict.publicKey, key);
    expect(strict.labelHint, 'Ana');
    expect(strict.hasStrongPhrase, isTrue);
  });

  test('a response is version 2 with the tag and no label', () async {
    final wire = await TransportPackage.encodeLdpResponse(
      publicKey: key,
      pakeWords: words,
    );
    final strict =
        await TransportPackage.decodeLdpStrict(wire, pakeWords: words);
    expect(strict.version, 2);
    expect(strict.hasStrongPhrase, isTrue);
    expect(strict.labelHint, isEmpty);
  });

  test('a version 1 package (Signet 0.3.6 and older) is refused as outdated',
      () async {
    final v1 = await TransportPackage.encodeLdp(
      publicKey: key,
      labelHint: 'Ana',
      pakeWords: words,
      version: 1,
    );
    expect(
      () => TransportPackage.decodeLdpStrict(v1, pakeWords: words),
      throwsA(isA<OutdatedPeerPackageException>()),
    );
  });

  test('a version 2 package without the tag is refused: the flag cannot be '
      'stripped', () async {
    // Someone holding the 8 words can re-encrypt a package without the
    // tag; the strict decoder refuses it instead of falling back to the
    // weak phrase.
    final stripped = await TransportPackage.encodeLdp(
      publicKey: key,
      labelHint: 'Ana',
      pakeWords: words,
      version: 2,
    );
    expect(
      () => TransportPackage.decodeLdpStrict(stripped, pakeWords: words),
      throwsA(isA<OutdatedPeerPackageException>()),
    );
  });

  test('an unknown strong-phrase scheme is from a newer Signet', () async {
    final newer = await TransportPackage.encodeLdp(
      publicKey: key,
      labelHint: 'Ana',
      pakeWords: words,
      version: 2,
      extensions: const [
        TransportExtension(TransportPackage.ldpStrongPhraseTag, [0x02]),
      ],
    );
    expect(
      () => TransportPackage.decodeLdpStrict(newer, pakeWords: words),
      throwsA(isA<UnsupportedPackageVersionException>()
          .having((e) => e.authenticated, 'authenticated', isTrue)),
    );
  });

  test('outdated is a package error, distinct from "needs a newer Signet"',
      () {
    const e = OutdatedPeerPackageException();
    expect(e, isA<InvalidPackageException>());
    expect(e, isNot(isA<UnsupportedPackageVersionException>()));
  });
  Future<String> ldpWith(List<TransportExtension> extensions) =>
      TransportPackage.encodeLdp(
        publicKey: key,
        labelHint: 'Ana',
        pakeWords: words,
        version: 2,
        extensions: extensions,
      );

  test('a version 2 package with only a non-critical tag is refused as '
      'outdated', () async {
    final wire = await ldpWith(const [TransportExtension(0x05, [1])]);
    expect(
      () => TransportPackage.decodeLdpStrict(wire, pakeWords: words),
      throwsA(isA<OutdatedPeerPackageException>()),
    );
  });

  for (final (name, value) in const [
    ('empty', <int>[]),
    ('two bytes', <int>[0x01, 0x01]),
  ]) {
    test('a malformed scheme value ($name) is damaged, not "newer"', () async {
      final wire = await ldpWith([
        TransportExtension(TransportPackage.ldpStrongPhraseTag, value),
      ]);
      expect(
        () => TransportPackage.decodeLdpStrict(wire, pakeWords: words),
        throwsA(isA<InvalidPackageException>()
            .having((e) => e, 'not newer',
                isNot(isA<UnsupportedPackageVersionException>()))
            .having((e) => e, 'not outdated',
                isNot(isA<OutdatedPeerPackageException>()))),
      );
    });
  }

  test('a known non-critical tag next to the strong-phrase tag is accepted',
      () async {
    final wire = await ldpWith(const [
      TransportExtension(TransportPackage.ldpStrongPhraseTag, [0x01]),
      TransportExtension(0x05, [9]),
    ]);
    final ldp = await TransportPackage.decodeLdpStrict(wire, pakeWords: words);
    expect(ldp.hasStrongPhrase, isTrue);
    expect(ldp.extensions[0x05], [9]);
  });

  test('an unknown critical tag next to the strong-phrase tag is from a '
      'newer Signet', () async {
    final wire = await ldpWith(const [
      TransportExtension(TransportPackage.ldpStrongPhraseTag, [0x01]),
      TransportExtension(0x8F, [1]),
    ]);
    expect(
      () => TransportPackage.decodeLdpStrict(wire, pakeWords: words),
      throwsA(isA<UnsupportedPackageVersionException>()),
    );
  });

  // The tag is understood only in LDP: in a backup it means nothing to
  // this build, so it must be refused, not silently ignored.
  group('the strong-phrase tag is unknown outside LDP', () {
    final secret = List<int>.generate(32, (i) => 0x40 + i);
    const tag = TransportExtension(TransportPackage.ldpStrongPhraseTag, [1]);

    test('LPR', () async {
      final wire = await TransportPackage.encodeLpr(
        label: 'Mom',
        role: PairRole.a,
        pairedAt: DateTime.utc(2026, 1, 1),
        silentHaptics: false,
        sharedSecret: secret,
        pakeWords: words,
        version: 2,
        extensions: const [tag],
      );
      expect(
        () => TransportPackage.decodeLpr(wire, pakeWords: words),
        throwsA(isA<UnsupportedPackageVersionException>()
            .having((e) => e.authenticated, 'authenticated', isTrue)),
      );
    });

    test('BLK skips the record', () async {
      final wire = await TransportPackage.encodeBlk(
        records: [
          for (final ext in [
            <int, List<int>>{},
            <int, List<int>>{TransportPackage.ldpStrongPhraseTag: [1]},
          ])
            BlkRelationshipRecord(
              sharedSecret: Uint8List.fromList(secret),
              role: PairRole.a,
              label: ext.isEmpty ? 'A' : 'B',
              pairedAt: DateTime.utc(2026, 1, 1),
              silentHaptics: false,
              extensions: ext,
            ),
        ],
        pakeWords: words,
        version: 2,
      );
      final blk = await TransportPackage.decodeBlk(wire, pakeWords: words);
      expect(blk.records.map((r) => r.label), ['A']);
      expect(blk.skippedNeedsNewerVersion, 1);
    });
  });
}
