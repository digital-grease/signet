import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/relationship.dart';

/// Wrapper around the platform secure enclave (Android Keystore / iOS Keychain).
///
/// v0.1 enforces a single relationship: the storage has exactly one slot.
/// The relationship metadata (id, label, timestamp) and the raw shared
/// secret are stored under fixed keys; there is no directory of secrets
/// to iterate. This matches the v0.1 scope and makes it trivially
/// impossible to leak the wrong secret.
///
/// Android configuration uses the standard `AndroidOptions(...)` which corresponds to:
///   - RSA/OAEP-wrapped AES key held in hardware-backed Keystore
///     (StrongBox-backed when the device supports it)
///   - AES/GCM/NoPadding storage cipher
///   - no biometric prompt (grandma test)
///   - `resetOnError: false` so transient failures surface instead of silently
///     wiping the user's paired secret.
///
/// The stronger `AndroidOptions.biometric()` path (AES-GCM for both key wrap and
/// storage) is _not_ used because v10.0.0 of the plugin hits a first-run
/// algorithm-migration bug under that constructor ("Cipher not initialized"),
/// and the security difference vs. RSA-OAEP key wrapping is negligible — both
/// are hardware-backed and protected from extraction.
class SecureStore {
  SecureStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: false,
                preferencesKeyPrefix: _androidKeyPrefix,
              ),
            );

  final FlutterSecureStorage _storage;

  static const String _androidKeyPrefix = 'signet_v1';
  static const String _keyRelationship = 'signet.v1.relationship';
  static const String _keySharedSecret = 'signet.v1.shared_secret';

  /// Whether a paired relationship currently exists.
  Future<bool> hasRelationship() async {
    final raw = await _storage.read(key: _keyRelationship);
    return raw != null;
  }

  /// Commit a new relationship and its shared secret atomically (best-effort —
  /// we delete any prior slot first, then write both, so the only observable
  /// states are "nothing paired" or "fully paired").
  Future<void> saveRelationship(
    Relationship relationship, {
    required List<int> sharedSecret,
  }) async {
    if (sharedSecret.isEmpty) {
      throw ArgumentError.value(
        sharedSecret,
        'sharedSecret',
        'Shared secret must not be empty.',
      );
    }
    await _storage.delete(key: _keyRelationship);
    await _storage.delete(key: _keySharedSecret);
    await _storage.write(
      key: _keySharedSecret,
      value: base64Encode(sharedSecret),
    );
    await _storage.write(
      key: _keyRelationship,
      value: relationship.toJson(),
    );
  }

  /// Read the currently paired relationship, if any.
  ///
  /// If the stored blob can't be parsed (e.g. it was written by a
  /// pre-Phase-8 build that doesn't include the `role` field, or it's
  /// otherwise corrupt), we atomically wipe both slots and return null
  /// so the app falls back to the empty-home state and the user can
  /// repair. Pre-alpha, no migration story beyond that.
  Future<Relationship?> getRelationship() async {
    final raw = await _storage.read(key: _keyRelationship);
    if (raw == null) return null;
    try {
      return Relationship.fromJson(raw);
    } on FormatException {
      await deleteRelationship();
      return null;
    } on TypeError {
      await deleteRelationship();
      return null;
    }
  }

  /// Read the shared secret for the currently paired relationship, if any.
  /// Returns null when no relationship is paired.
  Future<Uint8List?> getSharedSecret() async {
    final encoded = await _storage.read(key: _keySharedSecret);
    if (encoded == null) return null;
    return Uint8List.fromList(base64Decode(encoded));
  }

  /// Unpair: clear both the metadata and the shared secret.
  Future<void> deleteRelationship() async {
    await _storage.delete(key: _keyRelationship);
    await _storage.delete(key: _keySharedSecret);
  }
}
