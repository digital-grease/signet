// Transport-package extension 0x01, the word-list id (v0.5.0 plan Task
// 1.3; docs/WIRE_FORMAT.md registry). Non-critical, so v0.4.0 ignores it
// and restores the contact as English.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/models/relationship.dart';

void main() {
  final pake = TransportPackage.mintPakeWords();
  final secret = Uint8List.fromList(List<int>.generate(32, (i) => i + 9));

  Future<String> lpr({List<TransportExtension> ext = const []}) =>
      TransportPackage.encodeLpr(
        label: 'Mom',
        role: PairRole.a,
        pairedAt: DateTime.utc(2026, 4, 16),
        silentHaptics: false,
        sharedSecret: secret,
        pakeWords: pake,
        extensions: ext,
      );

  test('tag 0x01 is non-critical', () {
    expect(TransportPackage.wordListTag, 0x01);
    expect(TransportPackage.wordListTag & 0x80, 0);
  });

  test('LPR carries the id', () async {
    final wire =
        await lpr(ext: [TransportPackage.wordListExtension('fr')]);
    final decoded = await TransportPackage.decodeLpr(wire, pakeWords: pake);
    expect(TransportPackage.wordListIdOf(decoded.extensions), 'fr');
  });

  test('a package without the tag (v0.4.0) has no id', () async {
    final decoded =
        await TransportPackage.decodeLpr(await lpr(), pakeWords: pake);
    expect(TransportPackage.wordListIdOf(decoded.extensions), isNull);
  });

  test('an unknown id comes through as it was written', () async {
    final wire =
        await lpr(ext: [TransportPackage.wordListExtension('zh-9')]);
    final decoded = await TransportPackage.decodeLpr(wire, pakeWords: pake);
    expect(TransportPackage.wordListIdOf(decoded.extensions), 'zh-9');
  });

  test('a damaged value never fails the restore and reads as damaged',
      () async {
    final bad = <List<int>>[
      [0xFF, 0x66], // not UTF-8
      'EN'.codeUnits,
      'fr '.codeUnits,
      'f'.codeUnits,
      ''.codeUnits,
      'abcdefghijklmnopq'.codeUnits, // 17
      [0x66, 0x72, 0xE2, 0x80, 0xAE], // "fr" + U+202E
    ];
    for (final value in bad) {
      final wire = await lpr(ext: [TransportExtension(0x01, value)]);
      final decoded =
          await TransportPackage.decodeLpr(wire, pakeWords: pake);
      expect(TransportPackage.wordListIdOf(decoded.extensions),
          TransportPackage.damagedWordListId,
          reason: '$value');
    }
    expect(TransportPackage.damagedWordListId,
        Relationship.damagedWordLanguage);
  });

  test('a huge hostile value cannot make later backups too long', () async {
    final wire = await lpr(ext: [
      TransportExtension(0x01, List<int>.filled(30000, 0x80)),
    ]);
    final decoded = await TransportPackage.decodeLpr(wire, pakeWords: pake);
    final id = TransportPackage.wordListIdOf(decoded.extensions)!;
    // Re-export, as the backup screens do.
    await lpr(ext: [TransportPackage.wordListExtension(id)]);
  });

  // A v0.5.0 backup of a French contact, pinned. Every later Signet must
  // read it as French. A v0.4.0 decoder skips tag 0x01 (non-critical) and
  // restores the contact as English; checked in the Task 1.3 review by
  // running v0.4.0's transport_package.dart against this layout.
  test('pinned v0.5.0 French backup reads as French', () async {
    const fixture = 'signet:tp1:AgIAAAAAahzLgKRz_3uzzciZoE3qDxhGamevO2PE3Pjw'
        'OwtnuijEvKEzGUwMIeY3LZ_oj2HF7kZ8fRWNZz-wtS2cN9IJNEoa27s2y_b1T0gqyih-'
        '-6zM6J-z1w';
    final decoded = await TransportPackage.decodeLpr(fixture, pakeWords: const [
      'abandon', 'ability', 'able', 'about', //
      'above', 'absent', 'absorb', 'abstract',
    ]);
    expect(decoded.label, 'Mom');
    expect(TransportPackage.wordListIdOf(decoded.extensions), 'fr');
  });

  test('each BLK record carries its own id', () async {
    BlkRelationshipRecord record(String label, String? id) =>
        BlkRelationshipRecord(
          sharedSecret: secret,
          role: PairRole.b,
          label: label,
          pairedAt: DateTime.utc(2026, 4, 16),
          silentHaptics: false,
          extensions: {
            if (id != null)
              TransportPackage.wordListTag:
                  TransportPackage.wordListExtension(id).value,
          },
        );
    final wire = await TransportPackage.encodeBlk(
      records: [record('Mom', 'fr'), record('Dad', 'en'), record('Kid', null)],
      pakeWords: pake,
    );
    final decoded = await TransportPackage.decodeBlk(wire, pakeWords: pake);
    expect(
      [for (final r in decoded.records) TransportPackage.wordListIdOf(r.extensions)],
      ['fr', 'en', null],
    );
  });
}
