import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pairing.dart';

Uint8List _hex(String input) {
  final cleaned = input.replaceAll(RegExp(r'\s+'), '');
  final bytes = Uint8List(cleaned.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

void main() {
  // RFC 7748 Section 6.1 Diffie-Hellman example.
  final alicePrivate = _hex(
    '77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a',
  );
  final alicePublic = _hex(
    '8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a',
  );
  final bobPrivate = _hex(
    '5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb',
  );
  final bobPublic = _hex(
    'de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f',
  );
  final expectedShared = _hex(
    '4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742',
  );

  group('X25519 — RFC 7748 Section 6.1', () {
    test('private scalar produces the expected public key (Alice)', () async {
      final pair = await PairingHandshake.keyPairFromSeed(alicePrivate);
      expect(pair.publicKey, equals(alicePublic));
    });

    test('private scalar produces the expected public key (Bob)', () async {
      final pair = await PairingHandshake.keyPairFromSeed(bobPrivate);
      expect(pair.publicKey, equals(bobPublic));
    });

    test('Alice derives the documented shared secret', () async {
      final alice = await PairingHandshake.keyPairFromSeed(alicePrivate);
      final shared = await PairingHandshake.deriveSharedSecret(
        ours: alice,
        theirPublicKey: bobPublic,
      );
      expect(shared, equals(expectedShared));
    });

    test('Bob derives the same shared secret', () async {
      final bob = await PairingHandshake.keyPairFromSeed(bobPrivate);
      final shared = await PairingHandshake.deriveSharedSecret(
        ours: bob,
        theirPublicKey: alicePublic,
      );
      expect(shared, equals(expectedShared));
    });
  });

  group('PairingHandshake round trip', () {
    test('two freshly generated key pairs derive matching shared secrets', () async {
      final a = await PairingHandshake.generateEphemeralKeyPair();
      final b = await PairingHandshake.generateEphemeralKeyPair();
      final fromA = await PairingHandshake.deriveSharedSecret(
        ours: a,
        theirPublicKey: b.publicKey,
      );
      final fromB = await PairingHandshake.deriveSharedSecret(
        ours: b,
        theirPublicKey: a.publicKey,
      );
      expect(fromA, equals(fromB));
      expect(fromA, hasLength(32));
    });

    test('different key pairs produce different shared secrets', () async {
      final a = await PairingHandshake.generateEphemeralKeyPair();
      final b = await PairingHandshake.generateEphemeralKeyPair();
      final c = await PairingHandshake.generateEphemeralKeyPair();
      final abShared = await PairingHandshake.deriveSharedSecret(
        ours: a,
        theirPublicKey: b.publicKey,
      );
      final acShared = await PairingHandshake.deriveSharedSecret(
        ours: a,
        theirPublicKey: c.publicKey,
      );
      expect(abShared, isNot(equals(acShared)));
    });

    test('public keys are 32 bytes', () async {
      final pair = await PairingHandshake.generateEphemeralKeyPair();
      expect(pair.publicKey, hasLength(32));
    });
  });

  group('TOTP-secret derivation (HKDF-SHA-256)', () {
    test('same shared secret → same derived TOTP secret', () async {
      final secret1 = await PairingHandshake.deriveTotpSecret(
        sharedSecret: expectedShared,
      );
      final secret2 = await PairingHandshake.deriveTotpSecret(
        sharedSecret: expectedShared,
      );
      expect(secret1, equals(secret2));
      expect(secret1, hasLength(32));
    });

    test('different shared secrets → different derived TOTP secrets', () async {
      final other = Uint8List.fromList(List.filled(32, 1));
      final a = await PairingHandshake.deriveTotpSecret(
        sharedSecret: expectedShared,
      );
      final b = await PairingHandshake.deriveTotpSecret(sharedSecret: other);
      expect(a, isNot(equals(b)));
    });

    test('derived TOTP secret is not the raw shared secret', () async {
      final derived = await PairingHandshake.deriveTotpSecret(
        sharedSecret: expectedShared,
      );
      expect(derived, isNot(equals(expectedShared)));
    });
  });

  // RFC 7748 §6.1: a peer that sends a low-order point forces the X25519
  // output to all zeros for every private key. Both victims of a MITM that
  // substitutes such points would derive the same (public) secret and see
  // matching 4-word phrases, so these keys must be rejected.
  group('low-order public keys are rejected', () {
    // Every u-coordinate encoding that is low-order after RFC 7748 decoding
    // (which masks the top bit): the canonical small-order points 0, 1 and
    // the two order-8 points, the non-canonical p-1 / p / p+1 (≡ -1, 0, 1),
    // and all of those with the top bit set. The order-8 points have no
    // non-canonical form below 2^255, so there are no "+p" variants of them.
    final lowOrder = <String, String>{
      'zero': '0000000000000000000000000000000000000000000000000000000000000000',
      'one': '0100000000000000000000000000000000000000000000000000000000000000',
      'order-8 a': 'e0eb7a7c3b41b8ae1656e3faf19fc46ada098deb9c32b1fd866205165f49b800',
      'order-8 b': '5f9c95bca3508c24b1d0b1559c83ef5b04445cc4581c8e86d8224eddd09f1157',
      'p-1': 'ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f',
      'p': 'edffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f',
      'p+1': 'eeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f',
      'zero high bit': '0000000000000000000000000000000000000000000000000000000000000080',
      'one high bit': '0100000000000000000000000000000000000000000000000000000000000080',
      'order-8 a high bit': 'e0eb7a7c3b41b8ae1656e3faf19fc46ada098deb9c32b1fd866205165f49b880',
      'order-8 b high bit': '5f9c95bca3508c24b1d0b1559c83ef5b04445cc4581c8e86d8224eddd09f11d7',
      'p-1 high bit': 'ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      'p high bit': 'edffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      'p+1 high bit': 'eeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    };

    for (final entry in lowOrder.entries) {
      test('${entry.key} -> WeakPublicKeyException', () async {
        final ours = await PairingHandshake.generateEphemeralKeyPair();
        await expectLater(
          PairingHandshake.deriveSharedSecret(
            ours: ours,
            theirPublicKey: _hex(entry.value),
          ),
          throwsA(isA<WeakPublicKeyException>()),
        );
      });
    }

    test('rejected for the RFC 7748 private keys too', () async {
      for (final seed in [alicePrivate, bobPrivate]) {
        final ours = await PairingHandshake.keyPairFromSeed(seed);
        for (final hex in lowOrder.values) {
          await expectLater(
            PairingHandshake.deriveSharedSecret(
              ours: ours,
              theirPublicKey: _hex(hex),
            ),
            throwsA(isA<WeakPublicKeyException>()),
          );
        }
      }
    });

    test('a peer key equal to our own is rejected', () async {
      final ours = await PairingHandshake.generateEphemeralKeyPair();
      await expectLater(
        PairingHandshake.deriveSharedSecret(
          ours: ours,
          theirPublicKey: ours.publicKey,
        ),
        throwsA(isA<WeakPublicKeyException>()),
      );
    });

    test('a re-encoded copy of our own key is rejected too', () async {
      final ours = await PairingHandshake.generateEphemeralKeyPair();
      // Same u-coordinate with the top bit set: decodes to our own point.
      final highBit = Uint8List.fromList(ours.publicKey)..[31] |= 0x80;
      await expectLater(
        PairingHandshake.deriveSharedSecret(
          ours: ours,
          theirPublicKey: highBit,
        ),
        throwsA(isA<WeakPublicKeyException>()),
      );
    });

    test('the exception message carries no key material', () async {
      final ours = await PairingHandshake.generateEphemeralKeyPair();
      try {
        await PairingHandshake.deriveSharedSecret(
          ours: ours,
          theirPublicKey: Uint8List(32),
        );
        fail('expected WeakPublicKeyException');
      } on WeakPublicKeyException catch (e) {
        expect(e.toString(), isNot(contains('00000000')));
      }
    });
  });

  // Interface sanity: the cryptography package's types should round-trip.
  test('SimpleKeyPairData can be reconstructed from exported seed', () async {
    final pair = await PairingHandshake.generateEphemeralKeyPair();
    final seed = pair.privateKeyBytes;
    final rebuilt = await PairingHandshake.keyPairFromSeed(seed);
    expect(rebuilt.publicKey, equals(pair.publicKey));
  });
}
