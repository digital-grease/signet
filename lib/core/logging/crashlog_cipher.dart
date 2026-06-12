import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256-GCM at-rest encryption for crash sentinel files.
///
/// **Layer 3** of the four-layer defense in `.devloop/spikes/log-shipping.md`.
/// Even if [LogScrubber] (layer 2) misses something, the sentinel file on
/// disk is encrypted under a 256-bit key held in `flutter_secure_storage`
/// (Android Keystore / iOS Keychain). An attacker with forensic read of
/// `~/data/data/dev.digitalgrease.signet/files/crashes/last.bin` needs
/// both a scrubber-miss AND Keystore extraction to recover plaintext.
///
/// Key lifecycle:
///   - Generated lazily on first [encrypt] call via `Random.secure()`.
///   - Persisted under [_keyStorageKey] in `flutter_secure_storage`.
///   - Read back on every [encrypt] / [decrypt] call.
///   - No rotation in v1: rotating the key invalidates any pending crash
///     report, which is acceptable — pending reports get discarded after
///     the dialog regardless.
///
/// Wire format produced by [encrypt]:
///
///     [12-byte nonce][N-byte ciphertext][16-byte AES-GCM tag]
///
/// Self-contained — no header, no version byte. Future-rev would add a
/// version byte and bump [_keyStorageKey] to `crashlog.aead_key.v2`.
class CrashlogCipher {
  CrashlogCipher({
    FlutterSecureStorage? storage,
    Random? random,
    String keyStorageKey = 'crashlog.aead_key.v1',
  })  : _storage = storage ?? _defaultStorage,
        _random = random ?? Random.secure(),
        _keyStorageKey = keyStorageKey;

  // Match SecureStore's AndroidOptions so all signet keys share the same
  // preferences namespace and reset policy. Keystore-backed; not biometric.
  static const FlutterSecureStorage _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      preferencesKeyPrefix: 'signet_v1',
    ),
  );

  static const int _keyLength = 32; // 256 bits
  static const int _nonceLength = 12; // AES-GCM standard
  static const int _tagLength = 16;

  final FlutterSecureStorage _storage;
  final Random _random;

  /// `flutter_secure_storage` key under which this cipher's AES key lives.
  /// Defaults to the crash sentinel key; the Phase-8 debug session passes a
  /// distinct `debuglog.aead_key.v1` so resetting one never wipes the other.
  final String _keyStorageKey;

  /// Encrypt [plaintext]. Generates the per-cipher key on first call.
  /// The returned blob is self-contained — pass it back to [decrypt] later.
  Future<Uint8List> encrypt(List<int> plaintext) async {
    final key = await _ensureKey();
    final nonce = Uint8List.fromList(
      List<int>.generate(_nonceLength, (_) => _random.nextInt(256)),
    );
    final cipher = AesGcm.with256bits();
    final box = await cipher.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    return Uint8List.fromList(<int>[
      ...nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  /// Decrypt a blob produced by [encrypt]. Throws [StateError] if the
  /// stored key is missing (e.g., user reinstalled the app between record
  /// and read) or if AEAD authentication fails.
  Future<Uint8List> decrypt(List<int> blob) async {
    if (blob.length < _nonceLength + _tagLength) {
      throw const _CrashlogCipherException(
        'Crashlog blob too short — corrupt or wrong format.',
      );
    }
    final key = await _readKey();
    if (key == null) {
      throw const _CrashlogCipherException(
        'Crashlog cipher key missing from secure storage.',
      );
    }
    final nonce = blob.sublist(0, _nonceLength);
    final ctEnd = blob.length - _tagLength;
    final ciphertext = blob.sublist(_nonceLength, ctEnd);
    final tag = blob.sublist(ctEnd);
    final cipher = AesGcm.with256bits();
    try {
      final plaintext = await cipher.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(tag)),
        secretKey: SecretKey(key),
      );
      return Uint8List.fromList(plaintext);
    } on SecretBoxAuthenticationError {
      throw const _CrashlogCipherException(
        'Crashlog AEAD authentication failed — blob tampered or wrong key.',
      );
    }
  }

  /// Wipe the stored key. Any pending crash blob on disk becomes
  /// unreadable. Useful for test cleanup and for an eventual "clear all
  /// crash data" Settings button.
  Future<void> resetKey() async {
    await _storage.delete(key: _keyStorageKey);
  }

  // ===========================================================================
  // Key persistence
  // ===========================================================================

  Future<Uint8List> _ensureKey() async {
    final existing = await _readKey();
    if (existing != null) return existing;
    final key = Uint8List.fromList(
      List<int>.generate(_keyLength, (_) => _random.nextInt(256)),
    );
    await _writeKey(key);
    return key;
  }

  Future<Uint8List?> _readKey() async {
    final encoded = await _storage.read(key: _keyStorageKey);
    if (encoded == null) return null;
    return Uint8List.fromList(base64.decode(encoded));
  }

  Future<void> _writeKey(Uint8List key) async {
    await _storage.write(key: _keyStorageKey, value: base64.encode(key));
  }
}

/// Thrown when a crashlog blob cannot be decrypted (short, missing key,
/// or AEAD auth failure). Treat any catch as "discard this crash report".
class _CrashlogCipherException implements Exception {
  const _CrashlogCipherException(this.message);
  final String message;

  @override
  String toString() => 'CrashlogCipherException: $message';
}
