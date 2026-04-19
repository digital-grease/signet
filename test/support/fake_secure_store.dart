import 'dart:typed_data';

import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/storage/secure_store.dart';

/// In-memory stand-in for [SecureStore]. Used in widget tests via
/// `secureStoreProvider.overrideWithValue(FakeSecureStore(...))`.
///
/// Implements both the v1 single-slot API (used by current consumers) and
/// the v2 keyed API (added in Phase 10.1, used by new consumers starting
/// in 10.3). The two APIs share the same backing store, so a save on
/// one side is visible on the other.
class FakeSecureStore implements SecureStore {
  FakeSecureStore({Relationship? seeded, List<int>? secret}) {
    if (seeded != null) {
      _relationships[seeded.id] = seeded;
      if (secret != null) {
        _secrets[seeded.id] = Uint8List.fromList(secret);
      }
    }
  }

  final Map<String, Relationship> _relationships = <String, Relationship>{};
  final Map<String, Uint8List> _secrets = <String, Uint8List>{};

  // --- v1 single-slot shims (pick the first / only entry) --------------

  Relationship? get _firstRelationship =>
      _relationships.isEmpty ? null : _relationships.values.first;

  String? get _firstId =>
      _relationships.isEmpty ? null : _relationships.keys.first;

  @override
  Future<bool> hasRelationship() async => _relationships.isNotEmpty;

  @override
  Future<Relationship?> getRelationship() async => _firstRelationship;

  @override
  Future<Uint8List?> getSharedSecret() async {
    final id = _firstId;
    return id == null ? null : _secrets[id];
  }

  @override
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
    _relationships.clear();
    _secrets.clear();
    _relationships[relationship.id] = relationship;
    _secrets[relationship.id] = Uint8List.fromList(sharedSecret);
  }

  @override
  Future<void> updateRelationshipMetadata(Relationship relationship) async {
    if (!_relationships.containsKey(relationship.id)) return;
    _relationships[relationship.id] = relationship;
  }

  @override
  Future<void> deleteRelationship() async {
    _relationships.clear();
    _secrets.clear();
  }

  // --- v2 keyed API ---------------------------------------------------

  @override
  Future<List<String>> listRelationshipIds() async =>
      _relationships.keys.toList(growable: false);

  @override
  Future<List<Relationship>> listRelationships() async =>
      _relationships.values.toList(growable: false);

  @override
  Future<Relationship?> getRelationshipById(String id) async =>
      _relationships[id];

  @override
  Future<Uint8List?> getSharedSecretById(String id) async => _secrets[id];

  @override
  Future<void> saveRelationshipV2(
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
    _relationships[relationship.id] = relationship;
    _secrets[relationship.id] = Uint8List.fromList(sharedSecret);
  }

  @override
  Future<void> updateRelationshipMetadataV2(Relationship relationship) async {
    if (!_relationships.containsKey(relationship.id)) return;
    _relationships[relationship.id] = relationship;
  }

  @override
  Future<void> deleteRelationshipById(String id) async {
    _relationships.remove(id);
    _secrets.remove(id);
  }
}
