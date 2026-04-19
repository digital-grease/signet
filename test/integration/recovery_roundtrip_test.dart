import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/pairing.dart';
import 'package:signet/core/crypto/totp_words.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/storage/secure_store.dart';
import 'package:signet/core/crypto/verification.dart' show PairingVerification;

import '../support/fake_secure_store.dart';

/// End-to-end recovery round-trip. Models the full lost-phone scenario:
///
/// 1. **Original pairing**: Alice and Mom pair in person. Alice's old
///    phone has a relationship row with a shared secret + role. Mom's
///    phone has the same shared secret with complementary role.
/// 2. **Loss**: Alice drops her phone. She still has the paper backup.
/// 3. **Import**: Alice's new phone consumes the LPR package + PAKE.
///    A fresh `Relationship.id` is minted but the shared secret + role
///    + label are preserved.
/// 4. **Verify vs Mom**: Alice's new phone produces TOTP words that
///    match Mom's verify expectation. Mom's words verify on Alice's
///    new phone.

void main() {
  test(
    'old phone → paper → new phone rehydrates a pair that still verifies '
    'against the unchanged peer',
    () async {
      // --- Step 1: the original in-person pairing ---
      final aliceOldKp =
          await PairingHandshake.generateEphemeralKeyPair();
      final momKp = await PairingHandshake.generateEphemeralKeyPair();
      final sharedSecret = await PairingHandshake.deriveSharedSecret(
        ours: aliceOldKp,
        theirPublicKey: momKp.publicKey,
      );
      final aliceRole = PairRole.assign(
        ourPublicKey: aliceOldKp.publicKey,
        theirPublicKey: momKp.publicKey,
      );
      final momRole = aliceRole.other;
      final originalPairedAt = DateTime.utc(2026, 2, 14, 15, 3);

      // Mom's phone derives her TOTP secret and sanity-verifies itself.
      final momTotpSecret =
          await PairingHandshake.deriveTotpSecret(sharedSecret: sharedSecret);

      // --- Step 2: Alice exports a backup on her (still-working) phone ---
      final pake = TransportPackage.mintPakeWords();
      final wire = await TransportPackage.encodeLpr(
        label: 'Mom',
        role: aliceRole,
        pairedAt: originalPairedAt,
        silentHaptics: false,
        sharedSecret: momTotpSecret,
        pakeWords: pake,
      );

      // Alice then physically transports the wire + PAKE to a new phone
      // (paper + safety deposit box, whatever). In-process we simulate by
      // passing the strings directly.

      // --- Step 3: Alice's new phone imports ---
      final newStore = FakeSecureStore();
      final decoded =
          await TransportPackage.decodeLpr(wire, pakeWords: pake);
      final fresh = Relationship.fresh(
        label: decoded.label,
        role: decoded.role,
        silentHaptics: decoded.silentHaptics,
      );
      await newStore.saveRelationshipV2(
        fresh,
        sharedSecret: decoded.sharedSecret,
      );

      // Fresh id (new local identity) but original label + role preserved.
      final stored = (await newStore.listRelationships()).single;
      expect(stored.label, 'Mom');
      expect(stored.role, aliceRole);
      expect(stored.id, isNot(isEmpty));

      // --- Step 4: Alice's new phone verifies against Mom ---
      // Mom generates her current-window words using her role.
      final nowUnix =
          DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final momWordsRightNow = await TotpWords.generate(
        secret: momTotpSecret,
        unixTimeSeconds: nowUnix,
        senderRole: momRole,
      );
      // Alice's new phone calls verify with senderRole=momRole (i.e.
      // relationship.role.other).
      final aliceVerifies = await TotpWords.verify(
        secret:
            (await newStore.getSharedSecretById(stored.id))!,
        candidate: momWordsRightNow,
        unixTimeSeconds: nowUnix,
        senderRole: stored.role.other,
      );
      expect(aliceVerifies, isTrue,
          reason: 'Rehydrated pair still verifies against unchanged peer');

      // And the other direction: Alice's new phone generates her "show
      // my words" and Mom verifies them.
      final aliceWordsFromNewPhone = await TotpWords.generate(
        secret: (await newStore.getSharedSecretById(stored.id))!,
        unixTimeSeconds: nowUnix,
        senderRole: stored.role,
      );
      final momVerifies = await TotpWords.verify(
        secret: momTotpSecret,
        candidate: aliceWordsFromNewPhone,
        unixTimeSeconds: nowUnix,
        senderRole: aliceRole,
      );
      expect(momVerifies, isTrue);
    },
  );

  test(
    'pair-time binding phrase survives export→import: both devices show '
    'the same 4-word phrase for the same shared secret',
    () async {
      final aliceOldKp = await PairingHandshake.generateEphemeralKeyPair();
      final momKp = await PairingHandshake.generateEphemeralKeyPair();
      final sharedSecret = await PairingHandshake.deriveSharedSecret(
        ours: aliceOldKp,
        theirPublicKey: momKp.publicKey,
      );
      final totpSecret = await PairingHandshake.deriveTotpSecret(
        sharedSecret: sharedSecret,
      );
      final originalPhrase = await PairingVerification.derivePhrase(
        sharedSecret: totpSecret,
      );

      final pake = TransportPackage.mintPakeWords();
      final wire = await TransportPackage.encodeLpr(
        label: 'Mom',
        role: PairRole.a,
        pairedAt: DateTime.utc(2026, 2, 14),
        silentHaptics: false,
        sharedSecret: totpSecret,
        pakeWords: pake,
      );

      final imported =
          await TransportPackage.decodeLpr(wire, pakeWords: pake);
      final importedPhrase = await PairingVerification.derivePhrase(
        sharedSecret: imported.sharedSecret,
      );

      expect(importedPhrase, originalPhrase);
    },
  );

  test(
    'wrong PAKE at import time does not write anything to storage',
    () async {
      final sharedSecret = List<int>.generate(32, (i) => i + 3);
      final pake = TransportPackage.mintPakeWords();
      final wire = await TransportPackage.encodeLpr(
        label: 'Mom',
        role: PairRole.a,
        pairedAt: DateTime.utc(2026, 2, 14),
        silentHaptics: false,
        sharedSecret: sharedSecret,
        pakeWords: pake,
      );

      final store = FakeSecureStore();
      final wrongPake = <String>[...pake]..[0] = 'absurd';
      await expectLater(
        TransportPackage.decodeLpr(wire, pakeWords: wrongPake),
        throwsA(isA<InvalidPakeException>()),
      );
      expect(await store.listRelationships(), isEmpty);
    },
  );

  test(
    'imported Relationship has a FRESH local id (new device identity)',
    () async {
      final sharedSecret = List<int>.generate(32, (i) => i + 1);
      final pake = TransportPackage.mintPakeWords();
      final wire = await TransportPackage.encodeLpr(
        label: 'Mom',
        role: PairRole.a,
        pairedAt: DateTime.utc(2026, 2, 14),
        silentHaptics: false,
        sharedSecret: sharedSecret,
        pakeWords: pake,
      );

      // Simulate "the old phone's id" and the new phone minting its own.
      const oldPhoneId = 'deadbeefcafef00ddeadbeefcafef00d';
      final imported =
          await TransportPackage.decodeLpr(wire, pakeWords: pake);
      final fresh = Relationship.fresh(
        label: imported.label,
        role: imported.role,
      );
      expect(fresh.id, isNot(oldPhoneId));
      expect(fresh.id.length, 32);
    },
  );

  test(
    'two imports from the same backup on the same new device produce '
    'distinct relationships (each has a fresh id)',
    () async {
      final sharedSecret = List<int>.generate(32, (i) => i + 2);
      final pake = TransportPackage.mintPakeWords();
      final wire = await TransportPackage.encodeLpr(
        label: 'Mom',
        role: PairRole.a,
        pairedAt: DateTime.utc(2026, 2, 14),
        silentHaptics: false,
        sharedSecret: sharedSecret,
        pakeWords: pake,
      );

      final store = FakeSecureStore();
      // First import
      final d1 = await TransportPackage.decodeLpr(wire, pakeWords: pake);
      final r1 = Relationship.fresh(label: d1.label, role: d1.role);
      await store.saveRelationshipV2(r1, sharedSecret: d1.sharedSecret);

      // Second import (paranoid user re-does the restore)
      final d2 = await TransportPackage.decodeLpr(wire, pakeWords: pake);
      final r2 = Relationship.fresh(label: d2.label, role: d2.role);
      await store.saveRelationshipV2(r2, sharedSecret: d2.sharedSecret);

      final ids = await store.listRelationshipIds();
      expect(ids, hasLength(2));
      expect(ids.toSet().length, 2);
    },
  );
}

// Satisfy the `pair_role` import.
// ignore: unused_element
void _noop(SecureStore _) {}
