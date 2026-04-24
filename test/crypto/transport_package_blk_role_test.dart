import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/totp_words.dart';
import 'package:signet/core/crypto/transport_package.dart';

/// Reflection-attack regression coverage for BLK restores.
///
/// The rotating TOTP 4-word code is role-suffixed via HKDF info
/// `signet/v1/totp-words-from-{a|b}`. Two relationships that share the
/// same 32-byte shared secret but differ in `role` MUST produce
/// different 4-word codes for the same time window — otherwise an
/// attacker could parrot the verifier's own words back at her and pass
/// verification.
///
/// Bulk-backup round-trips every relationship through `encodeBlk` /
/// `decodeBlk`, which preserves the role byte per-record. This test
/// asserts that property end-to-end: after a BLK export → import cycle,
/// an A-role record and a B-role record with identical secrets still
/// diverge at the TOTP layer.
void main() {
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

  test(
    'BLK round-trip preserves role byte; A-role and B-role TOTP words diverge',
    () async {
      // Two records, same 32-byte secret, opposite roles. Paired times
      // and labels differ to prove field-by-field hydration; only the
      // role byte is load-bearing for the reflection-attack defense.
      final sharedBytes =
          Uint8List.fromList(List<int>.generate(32, (i) => (i * 7) & 0xFF));
      final aRecord = BlkRelationshipRecord(
        sharedSecret: sharedBytes,
        role: PairRole.a,
        label: 'Mom',
        pairedAt: DateTime.utc(2026, 1, 1),
        silentHaptics: false,
      );
      final bRecord = BlkRelationshipRecord(
        sharedSecret: sharedBytes,
        role: PairRole.b,
        label: 'Mom-mirror',
        pairedAt: DateTime.utc(2026, 2, 1),
        silentHaptics: true,
      );

      final wire = await TransportPackage.encodeBlk(
        records: [aRecord, bRecord],
        pakeWords: goodPake,
      );
      final decoded =
          await TransportPackage.decodeBlk(wire, pakeWords: goodPake);

      expect(decoded.records, hasLength(2));
      final decodedA =
          decoded.records.firstWhere((r) => r.role == PairRole.a);
      final decodedB =
          decoded.records.firstWhere((r) => r.role == PairRole.b);
      expect(decodedA.sharedSecret, sharedBytes);
      expect(decodedB.sharedSecret, sharedBytes);
      expect(decodedA.role, PairRole.a);
      expect(decodedB.role, PairRole.b);

      // Same time window for both computations — the only variable is
      // the role. If the role byte were lost in round-trip, both
      // records would derive identical words and this assertion would
      // fire.
      const window = 1_800_000_000; // mid-2027-ish; arbitrary fixed time
      final aWords = await TotpWords.generate(
        secret: decodedA.sharedSecret,
        unixTimeSeconds: window,
        senderRole: decodedA.role,
      );
      final bWords = await TotpWords.generate(
        secret: decodedB.sharedSecret,
        unixTimeSeconds: window,
        senderRole: decodedB.role,
      );

      expect(aWords, hasLength(4));
      expect(bWords, hasLength(4));
      expect(
        aWords,
        isNot(bWords),
        reason:
            'Role byte must survive BLK round-trip; A→B and B→A TOTP words '
            'must remain distinct or reflection attacks pass.',
      );
    },
  );
}
