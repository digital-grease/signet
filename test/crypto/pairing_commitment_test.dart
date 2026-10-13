import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pairing_commitment.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  final pub = Uint8List.fromList(List<int>.generate(32, (i) => i));
  final nonce = Uint8List.fromList(List<int>.generate(16, (i) => 200 + i));

  group('PairingCommitment.commit', () {
    test('matches the reference SHA-256("signet/v2/commit" || pub || nonce)',
        () async {
      // Computed independently (Python hashlib) in the Task 1.7b notes.
      final c = await PairingCommitment.commit(publicKey: pub, nonce: nonce);
      expect(
        _hex(c),
        'e69620fa986708a39c48479442b9a41bcd112aa72aadc1e450ba037b7cd54b1f',
      );
      expect(c.length, PairingCommitment.commitmentLength);
    });

    test('rejects a public key that is not 32 bytes', () {
      expect(
        () => PairingCommitment.commit(publicKey: pub.sublist(1), nonce: nonce),
        throwsArgumentError,
      );
    });

    test('rejects a nonce that is not 16 bytes', () {
      expect(
        () => PairingCommitment.commit(publicKey: pub, nonce: nonce.sublist(1)),
        throwsArgumentError,
      );
    });
  });

  group('PairingCommitment.matches', () {
    late Uint8List c;
    setUp(() async {
      c = await PairingCommitment.commit(publicKey: pub, nonce: nonce);
    });

    test('accepts the committed key and nonce', () async {
      expect(
        await PairingCommitment.matches(
          commitment: c,
          publicKey: pub,
          nonce: nonce,
        ),
        isTrue,
      );
    });

    test('rejects a different nonce', () async {
      final other = Uint8List.fromList(nonce)..[0] ^= 1;
      expect(
        await PairingCommitment.matches(
          commitment: c,
          publicKey: pub,
          nonce: other,
        ),
        isFalse,
      );
    });

    test('rejects a different key', () async {
      final other = Uint8List.fromList(pub)..[31] ^= 0x80;
      expect(
        await PairingCommitment.matches(
          commitment: c,
          publicKey: other,
          nonce: nonce,
        ),
        isFalse,
      );
    });

    test('rejects a commitment that differs in a single byte, any position',
        () async {
      // Every byte must be compared: a check of only the first byte (or
      // first half) would let a forged reveal through with high odds.
      for (final i in [0, 15, 16, 31]) {
        final forged = Uint8List.fromList(c)..[i] ^= 0x01;
        expect(
          await PairingCommitment.matches(
            commitment: forged,
            publicKey: pub,
            nonce: nonce,
          ),
          isFalse,
          reason: 'byte $i flipped',
        );
      }
    });

    test('rejects a truncated commitment, key or nonce instead of throwing',
        () async {
      expect(
        await PairingCommitment.matches(
          commitment: c.sublist(0, 31),
          publicKey: pub,
          nonce: nonce,
        ),
        isFalse,
      );
      expect(
        await PairingCommitment.matches(
          commitment: c,
          publicKey: pub.sublist(0, 31),
          nonce: nonce,
        ),
        isFalse,
      );
      expect(
        await PairingCommitment.matches(
          commitment: c,
          publicKey: pub,
          nonce: nonce.sublist(0, 15),
        ),
        isFalse,
      );
    });
  });

  group('PairingCommitment.newNonce', () {
    test('is 16 bytes and differs between calls', () {
      final a = PairingCommitment.newNonce();
      final b = PairingCommitment.newNonce();
      expect(a.length, PairingCommitment.nonceLength);
      expect(b.length, PairingCommitment.nonceLength);
      expect(a, isNot(equals(b)));
    });
  });
}
