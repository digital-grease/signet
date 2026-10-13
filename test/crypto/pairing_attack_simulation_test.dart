// Attack simulations for the pair-time phrase (plan Task 1.7, bug R5).
//
// These ILLUSTRATE the bounds in the pairing-commitment spike; they do not
// replace the argument, which is structural: under commit-then-reveal the
// man-in-the-middle must fix the substitute key it gives Start before
// Start's key is revealed, so it cannot evaluate Start's phrase while it
// still has a choice to make.
//
// Real X25519, the real commitment and the real transcript salt, but an
// 8-bit phrase so the bounds show up in a test run. One adaptive attacker
// runs against each ordering. At each decision it searches whenever every
// input to the phrase it is targeting is known, and guesses otherwise; the
// ordering alone decides whether it wins:
//
//   - today's protocol (both keys shown first): it searches, and wins;
//   - commit-then-reveal with fresh keys: Start's key is hidden when the
//     attacker must choose, so it guesses (about 1 in 256 here, 2^-44 with
//     the real 4-word phrase);
//   - commit-then-reveal when Start's key and nonce were learned in an
//     aborted earlier attempt and reused: it searches, and wins again.
//
// The last case shows WHY keys and nonces must be single-use (spike
// requirement 3). The regression test that the app actually mints fresh
// keys on every exit path lives with the pairing controller (Task 1.7e),
// because only the controller decides reuse.
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pairing.dart';
import 'package:signet/core/crypto/pairing_commitment.dart';
import 'package:signet/core/crypto/verification.dart';

/// The reduced phrase: one byte of HKDF over the same transcript salt the
/// real in-person phrase uses.
Future<int> _phrase(
  List<int> sharedSecret,
  List<int> keyX,
  List<int> keyY,
  List<int> nonce,
) async {
  final salt = await PairingVerification.transcriptSalt(keyX, keyY, nonce);
  final out = await Hkdf(hmac: Hmac.sha256(), outputLength: 1).deriveKey(
    secretKey: SecretKey(sharedSecret),
    nonce: salt,
    info: 'test/reduced-phrase'.codeUnits,
  );
  return (await out.extractBytes()).single;
}

Future<Uint8List> _dh(PairingKeyPair ours, List<int> theirs) =>
    PairingHandshake.deriveSharedSecret(ours: ours, theirPublicKey: theirs);

/// What the attacker knows about Start when it must choose the key it
/// gives Start (`m2`).
class _StartView {
  const _StartView(this.publicKey, this.nonce);
  final Uint8List? publicKey; // null while hidden behind the commitment
  final Uint8List? nonce;
}

/// One attempt. Join's key is known to the attacker before it chooses m2
/// in every ordering (Join shows it in step 2). Returns true if both honest
/// phones show the same reduced phrase.
Future<bool> _attempt({
  required PairingKeyPair start,
  required Uint8List startNonce,
  required PairingKeyPair join,
  required _StartView viewAtM2,
  int searchBudget = 4096,
}) async {
  // m1 goes to Join, committed before Join's key exists in option C. The
  // attacker opens its own commitment honestly, so Join's check passes.
  final m1 = await PairingHandshake.generateEphemeralKeyPair();
  final m1Nonce = PairingCommitment.newNonce();
  final commitToJoin = await PairingCommitment.commit(
    publicKey: m1.publicKey,
    nonce: m1Nonce,
  );
  final joinPhrase = await _phrase(
    await _dh(m1, join.publicKey),
    m1.publicKey,
    join.publicKey,
    m1Nonce,
  );
  expect(
    await PairingCommitment.matches(
      commitment: commitToJoin,
      publicKey: m1.publicKey,
      nonce: m1Nonce,
    ),
    isTrue,
  );

  // m2 goes to Start. Adaptive: search for an m2 whose phrase on Start
  // equals Join's phrase when Start's key and nonce are known; otherwise
  // the best the attacker can do is a single guess.
  final knownStart = viewAtM2.publicKey;
  final knownNonce = viewAtM2.nonce;
  final tries = knownStart != null && knownNonce != null ? searchBudget : 1;
  for (var i = 0; i < tries; i++) {
    final m2 = await PairingHandshake.generateEphemeralKeyPair();
    if (knownStart != null && knownNonce != null) {
      final predicted = await _phrase(
        await _dh(m2, knownStart),
        knownStart,
        m2.publicKey,
        knownNonce,
      );
      if (predicted != joinPhrase) continue;
    }
    // Commit to this m2. What Start actually shows:
    final startPhrase = await _phrase(
      await _dh(start, m2.publicKey),
      start.publicKey,
      m2.publicKey,
      startNonce,
    );
    return startPhrase == joinPhrase;
  }
  return false;
}

void main() {
  test("today's protocol: Start's key is known when choosing, attack wins",
      () async {
    for (var i = 0; i < 3; i++) {
      final start = await PairingHandshake.generateEphemeralKeyPair();
      final startNonce = PairingCommitment.newNonce();
      final join = await PairingHandshake.generateEphemeralKeyPair();
      // Both keys are on screen before either phone scans.
      final won = await _attempt(
        start: start,
        startNonce: startNonce,
        join: join,
        viewAtM2: _StartView(start.publicKey, startNonce),
      );
      // A 4096-try search on 8 bits misses with probability ~e^-16.
      expect(won, isTrue, reason: 'attempt $i');
    }
  });

  test('commit-then-reveal, fresh keys: Start hidden, attack is a guess',
      () async {
    const attempts = 400;
    var successes = 0;
    for (var i = 0; i < attempts; i++) {
      final start = await PairingHandshake.generateEphemeralKeyPair();
      final startNonce = PairingCommitment.newNonce();
      final join = await PairingHandshake.generateEphemeralKeyPair();
      if (await _attempt(
        start: start,
        startNonce: startNonce,
        join: join,
        viewAtM2: const _StartView(null, null),
      )) {
        successes++;
      }
    }
    // Expected about 400/256 = 1.6; more than 10 has probability ~1e-6.
    expect(successes, lessThanOrEqualTo(10));
  });

  test('commit-then-reveal, keys and nonce reused after an abort: wins',
      () async {
    for (var i = 0; i < 3; i++) {
      // Attempt 1 (not simulated): the attacker relays honestly until
      // Start's reveal, learns Start's key and nonce, and aborts. Attempt 2
      // reuses them, so they are known when the attacker chooses m2.
      final start = await PairingHandshake.generateEphemeralKeyPair();
      final startNonce = PairingCommitment.newNonce();
      final join = await PairingHandshake.generateEphemeralKeyPair();
      expect(
        await _attempt(
          start: start,
          startNonce: startNonce,
          join: join,
          viewAtM2: _StartView(start.publicKey, startNonce),
        ),
        isTrue,
        reason: 'attempt $i',
      );
    }
  });
}
