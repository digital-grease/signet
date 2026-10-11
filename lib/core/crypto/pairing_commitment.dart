import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Commit-then-reveal for in-person pairing (plan Task 1.7, bug R5; design
/// in the pairing-commitment spike, after ZRTP, RFC 6189 section 4.4.1.1).
///
/// The Start phone shows `c = SHA-256("signet/v2/commit" || pub || nonce)`
/// before the Join phone has a key, and reveals `pub || nonce` only after
/// it has received Join's key. A man-in-the-middle therefore has to fix
/// one phone's phrase before it can compute the other's: one blind guess
/// per attempt instead of a birthday search.
///
/// Pure function API, no Flutter imports. Every input has a fixed length,
/// so the hash input is unambiguous without length prefixes.
class PairingCommitment {
  const PairingCommitment._();

  static const int publicKeyLength = 32;
  static const int nonceLength = 16;
  static const int commitmentLength = 32;
  static const String _domain = 'signet/v2/commit';

  static final Random _random = Random.secure();

  /// A fresh 16-byte nonce. One per attempt, never reused (spike
  /// requirement 3: keys and nonces are single-use).
  static Uint8List newNonce() => Uint8List.fromList(
        List<int>.generate(nonceLength, (_) => _random.nextInt(256)),
      );

  /// The commitment Start shows in its first QR code.
  static Future<Uint8List> commit({
    required List<int> publicKey,
    required List<int> nonce,
  }) async {
    if (publicKey.length != publicKeyLength) {
      throw ArgumentError.value(
        publicKey.length,
        'publicKey.length',
        'X25519 public keys must be exactly $publicKeyLength bytes.',
      );
    }
    if (nonce.length != nonceLength) {
      throw ArgumentError.value(
        nonce.length,
        'nonce.length',
        'Commitment nonces must be exactly $nonceLength bytes.',
      );
    }
    final hash = await Sha256().hash(<int>[
      ..._domain.codeUnits,
      ...publicKey,
      ...nonce,
    ]);
    return Uint8List.fromList(hash.bytes);
  }

  /// Whether a revealed key and nonce open [commitment]. Wrong lengths
  /// return false rather than throwing, so a malformed code is just a
  /// mismatch to the caller. The final comparison is constant time.
  static Future<bool> matches({
    required List<int> commitment,
    required List<int> publicKey,
    required List<int> nonce,
  }) async {
    if (commitment.length != commitmentLength ||
        publicKey.length != publicKeyLength ||
        nonce.length != nonceLength) {
      return false;
    }
    final expected = await commit(publicKey: publicKey, nonce: nonce);
    var diff = 0;
    for (var i = 0; i < commitmentLength; i++) {
      diff |= expected[i] ^ commitment[i];
    }
    return diff == 0;
  }
}
