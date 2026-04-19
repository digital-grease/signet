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

  /// Rewrite just the relationship metadata blob. Used when toggling a
  /// non-secret field on the paired relationship (e.g. `silentHaptics`,
  /// future label edits) without touching the shared secret.
  ///
  /// No-op if no relationship is currently paired — we don't materialize
  /// a stranger relationship from nothing. Caller is expected to only
  /// invoke this after reading a live `Relationship` from
  /// `getRelationship()`.
  Future<void> updateRelationshipMetadata(Relationship relationship) async {
    final existing = await _storage.read(key: _keyRelationship);
    if (existing == null) return;
    await _storage.write(
      key: _keyRelationship,
      value: relationship.toJson(),
    );
  }

  /// Unpair: clear both the metadata and the shared secret.
  Future<void> deleteRelationship() async {
    await _storage.delete(key: _keyRelationship);
    await _storage.delete(key: _keySharedSecret);
  }

  // ======================================================================
  // v2 keyed API (Phase 10.1). Additive — sits alongside the v1 single-slot
  // methods above. Migration from v1 → v2 lands in Phase 10.2; callers move
  // to the v2 methods in 10.3+. Until migration runs, a fresh install sees
  // an empty v2 index and the v1 methods remain the source of truth. This
  // coexistence window is deliberate: it lets each consumer migrate on its
  // own commit with the test suite green.
  // ======================================================================

  static const String _keyIndex = 'signet.v2.index';
  static const String _keyRelationshipPrefix = 'signet.v2.rel.';
  static const String _keySecretPrefix = 'signet.v2.secret.';

  String _relationshipKey(String id) => '$_keyRelationshipPrefix$id';
  String _secretKey(String id) => '$_keySecretPrefix$id';

  /// Instance-scoped guard so migration runs exactly once per `SecureStore`
  /// even under concurrent v2 reads. On first call the guard holds the
  /// actual migration future; subsequent callers await the same future.
  Future<void>? _migrationGuard;

  /// Promote any v1 single-slot data to v2 keyed layout, exactly once.
  /// Called at the top of every v2 public method. Safe to call repeatedly.
  ///
  /// Three paths:
  /// - v2 index already written → no-op. This is both the "already
  ///   migrated" case and every subsequent call after the first.
  /// - v1 data present + parseable → move to v2 keys, write index = [id],
  ///   delete v1 keys. Existing pairing survives the upgrade.
  /// - v1 data absent OR malformed → write empty v2 index. Malformed v1
  ///   blob is treated as corrupt (wiped) — preserves Phase 8's self-heal
  ///   behavior.
  Future<void> _ensureMigrated() {
    return _migrationGuard ??= _runMigration();
  }

  Future<void> _runMigration() async {
    final existingIndex = await _storage.read(key: _keyIndex);
    if (existingIndex != null) return;

    final v1Raw = await _storage.read(key: _keyRelationship);
    final v1Secret = await _storage.read(key: _keySharedSecret);

    Relationship? v1Rel;
    if (v1Raw != null) {
      try {
        v1Rel = Relationship.fromJson(v1Raw);
      } on FormatException {
        v1Rel = null;
      } on TypeError {
        v1Rel = null;
      }
    }

    if (v1Rel != null && v1Secret != null) {
      // Happy migration path: promote to v2 under the same id.
      await _storage.write(
        key: _relationshipKey(v1Rel.id),
        value: v1Raw!,
      );
      await _storage.write(
        key: _secretKey(v1Rel.id),
        value: v1Secret,
      );
      await _writeIndex(<String>[v1Rel.id]);
    } else {
      // Fresh install, or a v1 blob that's corrupt / missing its secret.
      // Either way: v2 starts empty.
      await _writeIndex(const <String>[]);
    }

    // Clean up v1 keys unconditionally. After migration the v2 index is
    // authoritative; leaving v1 keys around would let stray v1 reads see
    // stale data.
    if (v1Raw != null) {
      await _storage.delete(key: _keyRelationship);
    }
    if (v1Secret != null) {
      await _storage.delete(key: _keySharedSecret);
    }
  }

  Future<List<String>> _readIndex() async {
    final raw = await _storage.read(key: _keyIndex);
    if (raw == null) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];
      return decoded.whereType<String>().toList(growable: false);
    } on FormatException {
      return const <String>[];
    }
  }

  Future<void> _writeIndex(List<String> ids) async {
    await _storage.write(key: _keyIndex, value: jsonEncode(ids));
  }

  /// List the ids of every paired relationship. Order matches write order.
  Future<List<String>> listRelationshipIds() async {
    await _ensureMigrated();
    return _readIndex();
  }

  /// List every paired relationship. Entries whose metadata blob fails to
  /// parse are skipped (not wiped — migration at boundary decides wipe
  /// policy for legacy shapes).
  Future<List<Relationship>> listRelationships() async {
    await _ensureMigrated();
    final ids = await _readIndex();
    final out = <Relationship>[];
    for (final id in ids) {
      final raw = await _storage.read(key: _relationshipKey(id));
      if (raw == null) continue;
      try {
        out.add(Relationship.fromJson(raw));
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    return out;
  }

  /// Fetch a single relationship by id. Returns null if no such id is in
  /// the index, or if its blob fails to parse.
  Future<Relationship?> getRelationshipById(String id) async {
    await _ensureMigrated();
    final raw = await _storage.read(key: _relationshipKey(id));
    if (raw == null) return null;
    try {
      return Relationship.fromJson(raw);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Fetch the shared secret for [id]. Returns null when nothing is stored.
  Future<Uint8List?> getSharedSecretById(String id) async {
    await _ensureMigrated();
    final encoded = await _storage.read(key: _secretKey(id));
    if (encoded == null) return null;
    return Uint8List.fromList(base64Decode(encoded));
  }

  /// Save [relationship] and its [sharedSecret] under [relationship.id].
  /// If the id is already in the index, the prior entry is overwritten
  /// (used by rekey in 10.6). Otherwise the id is appended to the index.
  ///
  /// Writes are ordered so that a partial failure leaves either "no
  /// relationship at this id" (index stale but pointing at nothing) or
  /// "relationship fully present." The order: clear prior data at this
  /// id → write secret → write metadata → write index. On crash between
  /// writes, the next `listRelationships` call silently skips the half-
  /// written id (no metadata → not returned).
  Future<void> saveRelationshipV2(
    Relationship relationship, {
    required List<int> sharedSecret,
  }) async {
    await _ensureMigrated();
    if (sharedSecret.isEmpty) {
      throw ArgumentError.value(
        sharedSecret,
        'sharedSecret',
        'Shared secret must not be empty.',
      );
    }
    final id = relationship.id;
    await _storage.delete(key: _relationshipKey(id));
    await _storage.delete(key: _secretKey(id));
    await _storage.write(
      key: _secretKey(id),
      value: base64Encode(sharedSecret),
    );
    await _storage.write(
      key: _relationshipKey(id),
      value: relationship.toJson(),
    );
    final ids = await _readIndex();
    if (!ids.contains(id)) {
      await _writeIndex(<String>[...ids, id]);
    }
  }

  /// Rewrite the metadata blob for [relationship.id]. Used for non-secret
  /// mutations like `silentHaptics` toggles and label edits. No-op if
  /// [relationship.id] is not already in the index (we don't materialize
  /// stranger relationships).
  Future<void> updateRelationshipMetadataV2(Relationship relationship) async {
    await _ensureMigrated();
    final ids = await _readIndex();
    if (!ids.contains(relationship.id)) return;
    await _storage.write(
      key: _relationshipKey(relationship.id),
      value: relationship.toJson(),
    );
  }

  /// Delete the relationship with [id]: its metadata, its secret, and its
  /// entry in the index.
  Future<void> deleteRelationshipById(String id) async {
    await _ensureMigrated();
    await _storage.delete(key: _relationshipKey(id));
    await _storage.delete(key: _secretKey(id));
    final ids = await _readIndex();
    if (ids.contains(id)) {
      await _writeIndex(ids.where((each) => each != id).toList(growable: false));
    }
  }
}
