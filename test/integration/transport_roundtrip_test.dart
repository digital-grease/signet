import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/pairing.dart';
import 'package:signet/core/crypto/totp_words.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/crypto/verification.dart';

/// End-to-end integration tests for Phase-10 long-distance pairing. Exercises
/// the full stack — TransportPackage + PairingHandshake + PairingVerification +
/// TotpWords — as a coherent system. No UI; these are pure-crypto round-trip
/// tests that would run on any platform.

void main() {
  group('LDP round-trip: Alice ↔ Bob', () {
    test(
      'both sides derive identical shared secret + pair-time phrase',
      () async {
        // --- Alice mints package + PAKE ---
        final aliceKp = await PairingHandshake.generateEphemeralKeyPair();
        final pake = TransportPackage.mintPakeWords();
        final aliceWire = await TransportPackage.encodeLdp(
          publicKey: aliceKp.publicKey,
          labelHint: 'Alice',
          pakeWords: pake,
        );

        // --- Bob receives Alice's package, unlocks, mints his own ---
        final aliceLdp = await TransportPackage.decodeLdp(
          aliceWire,
          pakeWords: pake,
        );
        expect(aliceLdp.publicKey, aliceKp.publicKey);
        expect(aliceLdp.labelHint, 'Alice');

        final bobKp = await PairingHandshake.generateEphemeralKeyPair();
        final bobSharedSecret = await PairingHandshake.deriveSharedSecret(
          ours: bobKp,
          theirPublicKey: aliceLdp.publicKey,
        );
        final bobPhrase = await PairingVerification.derivePhrase(
          sharedSecret: bobSharedSecret,
        );
        final bobResponse = await TransportPackage.encodeLdp(
          publicKey: bobKp.publicKey,
          labelHint: '',
          pakeWords: pake,
        );

        // --- Alice unlocks Bob's response, derives her side ---
        final bobLdp = await TransportPackage.decodeLdp(
          bobResponse,
          pakeWords: pake,
        );
        final aliceSharedSecret = await PairingHandshake.deriveSharedSecret(
          ours: aliceKp,
          theirPublicKey: bobLdp.publicKey,
        );
        final alicePhrase = await PairingVerification.derivePhrase(
          sharedSecret: aliceSharedSecret,
        );

        // Sanity: the shared secrets match (X25519 ECDH round-trip).
        expect(aliceSharedSecret, bobSharedSecret);
        expect(alicePhrase, bobPhrase);
      },
    );

    test(
      'derived TOTP words match across the live window for both roles',
      () async {
        final aliceKp = await PairingHandshake.generateEphemeralKeyPair();
        final bobKp = await PairingHandshake.generateEphemeralKeyPair();
        final pake = TransportPackage.mintPakeWords();

        // Simulate the handshake without packaging (package round-trip is
        // covered above; this test focuses on the post-commit verify loop).
        final aliceShared = await PairingHandshake.deriveSharedSecret(
          ours: aliceKp,
          theirPublicKey: bobKp.publicKey,
        );
        final bobShared = await PairingHandshake.deriveSharedSecret(
          ours: bobKp,
          theirPublicKey: aliceKp.publicKey,
        );
        final aliceTotpSecret =
            await PairingHandshake.deriveTotpSecret(sharedSecret: aliceShared);
        final bobTotpSecret =
            await PairingHandshake.deriveTotpSecret(sharedSecret: bobShared);
        expect(aliceTotpSecret, bobTotpSecret);

        // Role is derived from pubkey ordering.
        final aliceRole = PairRole.assign(
          ourPublicKey: aliceKp.publicKey,
          theirPublicKey: bobKp.publicKey,
        );
        final bobRole = PairRole.assign(
          ourPublicKey: bobKp.publicKey,
          theirPublicKey: aliceKp.publicKey,
        );
        expect(aliceRole, bobRole.other);

        // In the current window, Bob's "show my words" displays his role's
        // code. Alice calls verify with senderRole=bobRole to check it.
        final now =
            DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final bobWords = await TotpWords.generate(
          secret: bobTotpSecret,
          unixTimeSeconds: now,
          senderRole: bobRole,
        );
        final aliceVerifies = await TotpWords.verify(
          secret: aliceTotpSecret,
          candidate: bobWords,
          unixTimeSeconds: now,
          senderRole: bobRole,
        );
        expect(aliceVerifies, isTrue);

        // Same for the other direction: Alice → Bob.
        final aliceWords = await TotpWords.generate(
          secret: aliceTotpSecret,
          unixTimeSeconds: now,
          senderRole: aliceRole,
        );
        final bobVerifies = await TotpWords.verify(
          secret: bobTotpSecret,
          candidate: aliceWords,
          unixTimeSeconds: now,
          senderRole: aliceRole,
        );
        expect(bobVerifies, isTrue);

        // Silence unused local warning.
        expect(pake.length, 8);
      },
    );

    test('wrong PAKE secret on receiver side rejects Alice\'s package',
        () async {
      final aliceKp = await PairingHandshake.generateEphemeralKeyPair();
      final correctPake = TransportPackage.mintPakeWords();
      final aliceWire = await TransportPackage.encodeLdp(
        publicKey: aliceKp.publicKey,
        labelHint: 'Alice',
        pakeWords: correctPake,
      );

      final wrongPake = <String>[...correctPake]..[0] = 'absurd';
      await expectLater(
        TransportPackage.decodeLdp(aliceWire, pakeWords: wrongPake),
        throwsA(isA<InvalidPakeException>()),
      );
    });

    test('tampered Alice package cannot be decrypted by Bob', () async {
      final aliceKp = await PairingHandshake.generateEphemeralKeyPair();
      final pake = TransportPackage.mintPakeWords();
      final wire = await TransportPackage.encodeLdp(
        publicKey: aliceKp.publicKey,
        labelHint: 'Alice',
        pakeWords: pake,
      );
      // Flip one character inside the ciphertext body.
      const idx = 11 + 40; // 'signet:tp1:'.length + 40
      final before = wire.substring(0, idx);
      final ch = wire[idx];
      final flipped = ch == 'A' ? 'B' : 'A';
      final after = wire.substring(idx + 1);
      final tampered = '$before$flipped$after';
      await expectLater(
        TransportPackage.decodeLdp(tampered, pakeWords: pake),
        throwsA(anyOf(
          isA<InvalidPakeException>(),
          isA<InvalidPackageException>(),
        )),
      );
    });

    test('reflected Alice-package as Bob-response is still valid data, '
        'but produces Alice-as-self shared-secret (app must detect)', () async {
      // The transport-package layer does NOT prevent replay of Alice's own
      // package back at her — that's an app-layer concern. This test pins
      // the behavior so a future app-layer guard ("decoded pubkey == our
      // own pubkey → reject") has a clear expectation to enforce.
      final aliceKp = await PairingHandshake.generateEphemeralKeyPair();
      final pake = TransportPackage.mintPakeWords();
      final wire = await TransportPackage.encodeLdp(
        publicKey: aliceKp.publicKey,
        labelHint: 'Alice',
        pakeWords: pake,
      );
      final decoded =
          await TransportPackage.decodeLdp(wire, pakeWords: pake);
      // The decoded pubkey equals the one Alice shipped — i.e. her own.
      expect(decoded.publicKey, aliceKp.publicKey);
    });
  });
}
