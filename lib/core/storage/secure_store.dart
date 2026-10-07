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

  /// Roll-forward journal for [saveRelationshipV2]. A JSON list of pending
  /// writes `{"id", "rel", "secret"}`. One key (rather than one per id) so
  /// recovery never needs to enumerate storage.
  static const String _keyJournal = 'signet.v2.journal';

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
  ///
  /// After migration, any save interrupted by a crash or a storage error is
  /// rolled forward from the journal (see [saveRelationshipV2]).
  ///
  /// A failure is not cached: the guard is cleared so the next call retries
  /// (a transient Keystore error must not wedge every v2 call until the app
  /// restarts). Migration and replay are idempotent.
  Future<void> _ensureMigrated() {
    return _migrationGuard ??= () async {
      try {
        await _runMigration();
        await _replayJournal();
      } catch (_) {
        _migrationGuard = null;
        rethrow;
      }
    }();
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
    final ids = <String>[...await _readIndex()];
    for (final e in await _readJournal()) {
      if (e.op == _JournalEntry.opPut && !ids.contains(e.id)) ids.add(e.id);
      if (e.op == _JournalEntry.opDelete) ids.remove(e.id);
    }
    return ids;
  }

  /// List every paired relationship. Entries whose metadata blob fails to
  /// parse are skipped (not wiped — migration at boundary decides wipe
  /// policy for legacy shapes).
  Future<List<Relationship>> listRelationships() async {
    final ids = await listRelationshipIds();
    final out = <Relationship>[];
    for (final id in ids) {
      final pending = await _pendingFor(id);
      final raw = pending?.op == _JournalEntry.opPut
          ? pending!.relJson
          : await _storage.read(key: _relationshipKey(id));
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
    final pending = await _pendingFor(id);
    if (pending?.op == _JournalEntry.opDelete) return null;
    final raw = pending?.op == _JournalEntry.opPut
        ? pending!.relJson
        : await _storage.read(key: _relationshipKey(id));
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
    final pending = await _pendingFor(id);
    if (pending?.op == _JournalEntry.opDelete) return null;
    final encoded = pending?.op == _JournalEntry.opPut
        ? pending!.secretB64
        : await _storage.read(key: _secretKey(id));
    if (encoded == null) return null;
    return Uint8List.fromList(base64Decode(encoded));
  }

  /// Save [relationship] and its [sharedSecret] under [relationship.id].
  /// If the id is already in the index, the prior entry is overwritten
  /// (used by rekey in 10.6). Otherwise the id is appended to the index.
  ///
  /// Crash-safe: the new secret and metadata are first recorded in a
  /// roll-forward journal, then written over the primary keys (never
  /// deleted first), then the id is added to the index, and only then is
  /// the journal entry removed. If the process dies or a write fails at any
  /// point, the relationship is either fully old or, once the journal is
  /// replayed, fully new: never missing.
  ///
  /// If both the write and its immediate retry fail, the error is rethrown
  /// and the entry stays journaled. The migration guard is reset so the
  /// next store access retries the replay, and until it lands every read
  /// overlays the journaled entry: no caller ever sees the new secret with
  /// the old metadata, or a relationship that is half deleted.
  ///
  /// This is the rekey path too, so an interrupted rekey can no longer
  /// make a paired contact disappear.
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
    await _journalAndApply(_JournalEntry.put(
      id: relationship.id,
      relJson: relationship.toJson(),
      secretB64: base64Encode(sharedSecret),
    ));
  }

  /// Record [entry] (replacing any pending entry for its id), apply it, and
  /// on a second failure leave it journaled for the next store access.
  Future<void> _journalAndApply(_JournalEntry entry) async {
    final journal = await _readJournal();
    await _writeJournal(<_JournalEntry>[
      ...journal.where((e) => e.id != entry.id),
      entry,
    ]);
    try {
      await _applyJournalEntry(entry);
    } catch (_) {
      try {
        // One immediate retry from the journal.
        await _applyJournalEntry(entry);
      } catch (_) {
        // Still journaled. Make the next v2 call replay before it reads
        // anything, so no caller sees a half-applied entry.
        _migrationGuard = null;
        rethrow;
      }
    }
  }

  /// Apply [entry] and clear it from the journal. Idempotent in every
  /// partial state. Entries of an unknown kind (written by a newer build)
  /// are left in place untouched.
  Future<void> _applyJournalEntry(_JournalEntry entry) async {
    switch (entry.op) {
      case _JournalEntry.opPut:
        await _storage.write(
            key: _secretKey(entry.id), value: entry.secretB64!);
        await _storage.write(
            key: _relationshipKey(entry.id), value: entry.relJson!);
        final ids = await _readIndex();
        if (!ids.contains(entry.id)) {
          await _writeIndex(<String>[...ids, entry.id]);
        }
      case _JournalEntry.opDelete:
        // Secret first: if we die here, nothing secret is left behind.
        await _storage.delete(key: _secretKey(entry.id));
        await _storage.delete(key: _relationshipKey(entry.id));
        final ids = await _readIndex();
        if (ids.contains(entry.id)) {
          await _writeIndex(
              ids.where((each) => each != entry.id).toList(growable: false));
        }
      default:
        return;
    }
    final journal = await _readJournal();
    // Remove exactly this entry; a newer entry for the same id stays.
    await _writeJournal(journal.where((e) => !e.sameAs(entry)).toList());
  }

  /// Roll pending entries forward. A failing entry is kept for the next
  /// attempt and does not block the others or any store call: reads
  /// overlay the journal ([_pendingFor]), so callers still see a
  /// consistent view, and an unpair can always proceed.
  Future<void> _replayJournal() async {
    for (final entry in await _readJournal()) {
      try {
        await _applyJournalEntry(entry);
      } catch (_) {
        // Left journaled; retried on the next store access.
      }
    }
  }

  /// The pending journal entry for [id], if any. Reads overlay it so a
  /// half-applied save or delete is never observed.
  Future<_JournalEntry?> _pendingFor(String id) async {
    _JournalEntry? found;
    for (final e in await _readJournal()) {
      if (e.id == id && (e.op == _JournalEntry.opPut || e.op == _JournalEntry.opDelete)) {
        found = e;
      }
    }
    return found;
  }

  Future<List<_JournalEntry>> _readJournal() async {
    final String? raw;
    try {
      raw = await _storage.read(key: _keyJournal);
    } catch (_) {
      // Undecryptable (e.g. resetOnError:false after a Keystore change):
      // its contents are lost either way. Treat as empty so one bad value
      // can never block every relationship, unpair included; the next
      // journal write replaces it.
      return const <_JournalEntry>[];
    }
    if (raw == null) return const <_JournalEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <_JournalEntry>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_JournalEntry.fromJson)
          .whereType<_JournalEntry>()
          .toList(growable: false);
    } on FormatException {
      return const <_JournalEntry>[];
    }
  }

  Future<void> _writeJournal(List<_JournalEntry> entries) async {
    if (entries.isEmpty) {
      await _storage.delete(key: _keyJournal);
    } else {
      await _storage.write(
        key: _keyJournal,
        value: jsonEncode(entries.map((e) => e.raw).toList()),
      );
    }
  }

  /// Rewrite the metadata blob for [relationship.id]. Used for non-secret
  /// mutations like `silentHaptics` toggles and label edits. No-op if
  /// [relationship.id] is not already in the index (we don't materialize
  /// stranger relationships). If a save for this id is still journaled,
  /// the journaled metadata is updated too, so a later replay does not
  /// revert the edit.
  Future<void> updateRelationshipMetadataV2(Relationship relationship) async {
    final ids = await listRelationshipIds();
    if (!ids.contains(relationship.id)) return;
    final journal = await _readJournal();
    if (journal.any((e) => e.id == relationship.id && e.op == _JournalEntry.opPut)) {
      await _writeJournal(journal
          .map((e) => e.id == relationship.id && e.op == _JournalEntry.opPut
              ? _JournalEntry.put(
                  id: e.id,
                  relJson: relationship.toJson(),
                  secretB64: e.secretB64!,
                )
              : e)
          .toList());
    }
    await _storage.write(
      key: _relationshipKey(relationship.id),
      value: relationship.toJson(),
    );
  }

  /// Delete the relationship with [id]: its secret, its metadata, and its
  /// entry in the index. Journaled as a tombstone that replaces any pending
  /// save for [id] in one write, so a crash at any point either leaves the
  /// relationship untouched or finishes deleting it on the next store
  /// access ("unpairing leaves no trace"), and a failed earlier save can
  /// never be rolled forward afterwards.
  Future<void> deleteRelationshipById(String id) async {
    await _ensureMigrated();
    await _journalAndApply(_JournalEntry.delete(id: id));
  }
}

/// One pending operation in the [SecureStore] roll-forward journal.
///
/// Stored as its raw JSON map so entries of a kind this build does not
/// know (written by a newer build) survive a journal rewrite untouched.
class _JournalEntry {
  _JournalEntry._(this.raw);

  factory _JournalEntry.put({
    required String id,
    required String relJson,
    required String secretB64,
  }) =>
      _JournalEntry._(<String, dynamic>{
        'op': opPut,
        'id': id,
        'rel': relJson,
        'secret': secretB64,
      });

  factory _JournalEntry.delete({required String id}) =>
      _JournalEntry._(<String, dynamic>{'op': opDelete, 'id': id});

  /// Null when the map has no string id (cannot be attributed or applied).
  static _JournalEntry? fromJson(Map<String, dynamic> map) =>
      map['id'] is String ? _JournalEntry._(map) : null;

  static const String opPut = 'put';
  static const String opDelete = 'delete';

  final Map<String, dynamic> raw;

  String get id => raw['id'] as String;

  /// Entries written before ops existed (same session's earlier build)
  /// carry no `op` but have a payload: treat them as puts.
  String? get op {
    final op = raw['op'];
    if (op is String) return op;
    return (raw['rel'] is String && raw['secret'] is String) ? opPut : null;
  }

  String? get relJson => raw['rel'] as String?;
  String? get secretB64 => raw['secret'] as String?;

  bool sameAs(_JournalEntry other) =>
      jsonEncode(raw) == jsonEncode(other.raw);

  // Never print secret material (toString reaches logs and crash traces).
  @override
  String toString() => '_JournalEntry(op: $op, id: $id, secret: [redacted])';
}
