import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Thrown when a peer's X25519 public key cannot produce a safe shared
/// secret: a low-order point (all-zero ECDH output) or any encoding of our
/// own key reflected back. Either means a tampered or broken pairing code.
/// The message never contains key material.
class WeakPublicKeyException implements Exception {
  const WeakPublicKeyException._(this.message);

  final String message;

  @override
  String toString() => 'WeakPublicKeyException: $message';
}

/// X25519 ECDH handshake for device-to-device pairing (RFC 7748),
/// plus HKDF-SHA-256 derivation of the long-lived TOTP secret
/// from the raw shared secret.
///
/// Pure-function API. No Flutter imports. Each call is independently
/// testable against RFC vectors.
class PairingHandshake {
  const PairingHandshake._();

  static const int publicKeyLength = 32;
  static const int sharedSecretLength = 32;
  static const int totpSecretLength = 32;
  static const String totpHkdfInfo = 'signet/v1/totp-secret';

  static final X25519 _x25519 = X25519();

  /// Generate a fresh ephemeral X25519 key pair for this pairing.
  static Future<PairingKeyPair> generateEphemeralKeyPair() async {
    final keyPair = await _x25519.newKeyPair();
    return PairingKeyPair._(await keyPair.extract());
  }

  /// Reconstruct a key pair from a known 32-byte seed (private scalar).
  /// Used primarily for test vectors; the app should prefer [generateEphemeralKeyPair].
  static Future<PairingKeyPair> keyPairFromSeed(List<int> seed) async {
    if (seed.length != 32) {
      throw ArgumentError.value(
        seed.length,
        'seed.length',
        'X25519 seed must be exactly 32 bytes.',
      );
    }
    final keyPair = await _x25519.newKeyPairFromSeed(seed);
    return PairingKeyPair._(await keyPair.extract());
  }

  /// Derive the shared secret from our private key and the remote public key.
  /// Both devices, given matching inputs, produce byte-identical output.
  static Future<Uint8List> deriveSharedSecret({
    required PairingKeyPair ours,
    required List<int> theirPublicKey,
  }) async {
    if (theirPublicKey.length != publicKeyLength) {
      throw ArgumentError.value(
        theirPublicKey.length,
        'theirPublicKey.length',
        'X25519 public keys must be exactly 32 bytes.',
      );
    }
    final remote = SimplePublicKey(
      theirPublicKey,
      type: KeyPairType.x25519,
    );
    final secretKey = await _x25519.sharedSecretKey(
      keyPair: ours._data,
      remotePublicKey: remote,
    );
    final bytes = await secretKey.extractBytes();
    // RFC 7748 §6.1: reject an all-zero output. The X25519 scalar is clamped
    // to a multiple of 8, so every low-order or small-subgroup peer point
    // (and its non-canonical encodings) lands here. Without this check a
    // MITM can substitute such points in both directions: both victims
    // derive the same all-zero secret, see matching 4-word phrases, and the
    // attacker can compute every future code. DartX25519 does no peer-key
    // validation of its own. Constant-time OR so timing does not reveal
    // the secret's leading bytes.
    var acc = 0;
    for (final b in bytes) {
      acc |= b;
    }
    if (acc == 0) {
      throw const WeakPublicKeyException._(
        'Peer public key is a low-order point (all-zero shared secret).',
      );
    }
    // Reject our own key reflected back. Comparing derived secrets rather
    // than key bytes also catches re-encodings of our key (top bit set, or
    // our point plus a small-order component, which clamping cancels).
    // A reflection is not exploitable on its own (the attacker still lacks
    // our private key), so this is a sanity check, not a security boundary.
    final selfSecret = await (await _x25519.sharedSecretKey(
      keyPair: ours._data,
      remotePublicKey: SimplePublicKey(
        ours.publicKey,
        type: KeyPairType.x25519,
      ),
    ))
        .extractBytes();
    if (_constantTimeEquals(bytes, selfSecret)) {
      throw const WeakPublicKeyException._(
        'Peer public key is our own public key reflected back.',
      );
    }
    return Uint8List.fromList(bytes);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Turn the raw ECDH shared secret into a long-lived TOTP secret via HKDF-SHA-256.
  /// Domain-separated by [totpHkdfInfo] so the same shared secret can later yield
  /// other derived keys (e.g., for a different protocol) without collision.
  static Future<Uint8List> deriveTotpSecret({
    required List<int> sharedSecret,
  }) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: totpSecretLength);
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(sharedSecret),
      nonce: const <int>[],
      info: totpHkdfInfo.codeUnits,
    );
    final bytes = await derived.extractBytes();
    return Uint8List.fromList(bytes);
  }
}

/// Opaque wrapper around a concrete X25519 key pair.
/// Exposes the public key bytes (safe to share) and the seed bytes
/// (private — only needed for serialization/recovery flows).
class PairingKeyPair {
  PairingKeyPair._(this._data);

  final SimpleKeyPairData _data;

  Uint8List get publicKey => Uint8List.fromList(_data.publicKey.bytes);

  Uint8List get privateKeyBytes => Uint8List.fromList(_data.bytes);
}
