// Phase 7 leak-prevention test — structural guarantee for the primary defense
// in the four-layer scrubber stack (see `.devloop/spikes/log-shipping.md`).
//
// The crash-log scrubber's mechanical patterns catch hex/base64/transport-wire
// secrets that leak THROUGH stack frames. But the cheapest defense is to never
// let secrets *enter* a string in the first place. This test asserts that
// every sensitive type in the codebase, when stringified via `toString()`,
// does NOT contain its secret payload.
//
// When you add a new sensitive type, add it to this file. If the test fails,
// either fix the toString to redact, or revise the threat-model classification.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/backup_bundle.dart';
import 'package:signet/core/crypto/challenge_response_grid.dart';
import 'package:signet/core/crypto/liveness_challenge.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/pairing.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/models/relationship.dart';

/// A long, recognizable canary string that's exceedingly unlikely to appear
/// in any toString output by accident. If the test sees it, the toString
/// included the value we passed in.
const String _canaryLabel = 'CANARY_LABEL_xxxxxxxx_DO_NOT_LEAK';

/// 32 bytes of structured, recognizable secret material. Each byte is
/// distinct enough that any encoding (hex, base64, raw substring of either)
/// is searchable in the toString output.
final Uint8List _canarySecret = Uint8List.fromList(
  List<int>.generate(32, (i) => 0xA0 + i), // 0xA0, 0xA1, ..., 0xBF
);

/// Hex representation of [_canarySecret]: "a0a1a2...bf".
final String _canaryHex = _canarySecret
    .map((b) => b.toRadixString(16).padLeft(2, '0'))
    .join();

/// Base64 representation of [_canarySecret].
final String _canaryBase64 = base64.encode(_canarySecret);

/// Assert that none of the canary representations appear in [output]. Uses
/// reasonable substrings to also catch partial leaks (the first 16 hex chars
/// alone are enough to identify a key in a leaked stack frame).
void _expectNoLeak(String output, {String? label, String why = ''}) {
  expect(output, isNot(contains(_canaryHex)),
      reason: 'toString leaks full hex secret: $why');
  expect(output, isNot(contains(_canaryHex.substring(0, 16))),
      reason: 'toString leaks first 8 bytes of hex secret: $why');
  expect(output, isNot(contains(_canaryBase64)),
      reason: 'toString leaks full base64 secret: $why');
  // Raw-bytes representation as a Dart list — uncommon but possible if
  // someone does `toString()` on a `List<int>` field directly.
  expect(output, isNot(contains(_canarySecret.join(', '))),
      reason: 'toString leaks raw byte list: $why');
  if (label != null) {
    expect(output, isNot(contains(label)),
        reason: 'toString leaks label "$label": $why');
  }
}

void main() {
  group('Relationship.toString', () {
    test('omits the human-readable label', () {
      final r = Relationship(
        id: 'a1b2c3d4',
        label: _canaryLabel,
        pairedAt: DateTime.utc(2026, 5, 20),
        role: PairRole.a,
      );
      _expectNoLeak(r.toString(),
          label: _canaryLabel,
          why: 'label is the human-identifying field; sensitive per threat model');
      // Sanity — non-sensitive fields should still be there for debugging.
      expect(r.toString(), contains('a1b2c3d4'));
      expect(r.toString(), contains('role: a'));
    });
  });

  group('LivenessPrompt.toString', () {
    test('omits the BIP-39 word', () {
      const prompt = LivenessPrompt(
        action: LivenessAction.touchLeftEar,
        word: _canaryLabel,
      );
      _expectNoLeak(prompt.toString(),
          label: _canaryLabel,
          why: 'word fingerprints the window per threat model');
      // The action name is a public enum value and is safe to expose.
      expect(prompt.toString(), contains('touchLeftEar'));
    });
  });

  group('PairingKeyPair.toString (default Object)', () {
    test('does not leak private key bytes', () async {
      final kp = await PairingHandshake.keyPairFromSeed(_canarySecret);
      _expectNoLeak(kp.toString(),
          why: 'PairingKeyPair wraps the X25519 private scalar; '
              'default Object.toString must remain in place');
    });
  });

  group('BackupBundle.toString (default Object)', () {
    test('does not leak wire or PAKE words', () {
      final bundle = BackupBundle(
        wire: 'signet:tp1:$_canaryBase64',
        pakeWords: const <String>[
          'abandon', 'ability', 'able', 'about',
          'above', 'absent', 'absorb', 'abstract',
        ],
      );
      _expectNoLeak(bundle.toString(),
          why: 'Wire byte string and PAKE words are catastrophic-tier leaks');
      // Belt-and-suspenders: also forbid the literal 'signet:tp1:' wire prefix
      // adjacent to any base64 content, which is what an attacker greps for.
      expect(bundle.toString(), isNot(contains('signet:tp1:')),
          reason: 'toString must not surface the transport-wire prefix');
    });
  });

  group('LdpPackage.toString (default Object)', () {
    test('does not leak labelHint', () {
      final pkg = LdpPackage(
        publicKey: _canarySecret,
        labelHint: _canaryLabel,
        timestamp: DateTime.utc(2026, 5, 20),
      );
      _expectNoLeak(pkg.toString(),
          label: _canaryLabel,
          why: 'labelHint can identify the human counterparty');
    });
  });

  group('LprPackage.toString (default Object)', () {
    test('does not leak sharedSecret or label', () {
      final pkg = LprPackage(
        sharedSecret: _canarySecret,
        label: _canaryLabel,
        role: PairRole.a,
        pairedAt: DateTime.utc(2026, 5, 20),
        silentHaptics: false,
        timestamp: DateTime.utc(2026, 5, 20),
      );
      _expectNoLeak(pkg.toString(),
          label: _canaryLabel,
          why: 'sharedSecret + label are both catastrophic when leaked together');
    });
  });

  group('BlkRelationshipRecord.toString (default Object)', () {
    test('does not leak sharedSecret or label', () {
      final rec = BlkRelationshipRecord(
        sharedSecret: _canarySecret,
        role: PairRole.b,
        label: _canaryLabel,
        pairedAt: DateTime.utc(2026, 5, 20),
        silentHaptics: false,
      );
      _expectNoLeak(rec.toString(),
          label: _canaryLabel,
          why: 'one record per relationship in a BlkPackage; same threat as LPR');
    });
  });

  group('BlkPackage.toString (default Object)', () {
    test('does not leak any nested record material', () {
      final pkg = BlkPackage(
        records: <BlkRelationshipRecord>[
          BlkRelationshipRecord(
            sharedSecret: _canarySecret,
            role: PairRole.a,
            label: _canaryLabel,
            pairedAt: DateTime.utc(2026, 5, 20),
            silentHaptics: false,
          ),
        ],
        timestamp: DateTime.utc(2026, 5, 20),
      );
      _expectNoLeak(pkg.toString(),
          label: _canaryLabel,
          why: 'iterating records into toString would leak every paired secret');
    });
  });

  group('ChallengeResponseGrid.toString (default Object)', () {
    test('does not leak cell answers', () async {
      final grid = await ChallengeResponseGrid.derive(_canarySecret);
      final firstAnswer = grid.cells[0][0].join(' ');
      // No canary check here — answers are derived deterministically from the
      // secret, not from a passed-in canary. Just assert the rendered answer
      // doesn't show up in toString.
      expect(grid.toString(), isNot(contains(firstAnswer)),
          reason: 'cell answers are 3-word secrets per grid cell');
      expect(grid.toString(), isNot(contains(grid.cells[0][0][0])),
          reason: 'individual answer words must not surface either');
    });
  });

  group('Transport-package exceptions', () {
    // These exceptions DO surface their `message` in toString by design.
    // The audit confirmed the messages contain only metadata (lengths,
    // version bytes, payload-type bytes, generic text) — never raw bytes
    // or PAKE words. This test pins that invariant for the two specific
    // message-shaped exceptions that ship today.
    test('InvalidPakeException toString reveals only its message text', () {
      const e = InvalidPakeException('PAKE secret must be exactly 8 words');
      expect(e.toString(), equals(
          'InvalidPakeException: PAKE secret must be exactly 8 words'));
      _expectNoLeak(e.toString(),
          why: 'baseline check on a known-clean message');
    });

    test('InvalidPackageException toString reveals only its message text', () {
      const e = InvalidPackageException('LPR payload too short.');
      expect(e.toString(), equals(
          'InvalidPackageException: LPR payload too short.'));
      _expectNoLeak(e.toString(),
          why: 'baseline check on a known-clean message');
    });
  });
}

