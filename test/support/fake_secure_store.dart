import 'dart:typed_data';

import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/storage/secure_store.dart';

/// In-memory stand-in for [SecureStore]. Used in widget tests via
/// `secureStoreProvider.overrideWithValue(FakeSecureStore(...))`.
class FakeSecureStore implements SecureStore {
  FakeSecureStore({Relationship? seeded, List<int>? secret})
      : _relationship = seeded,
        _secret = secret == null ? null : Uint8List.fromList(secret);

  Relationship? _relationship;
  Uint8List? _secret;

  @override
  Future<bool> hasRelationship() async => _relationship != null;

  @override
  Future<Relationship?> getRelationship() async => _relationship;

  @override
  Future<Uint8List?> getSharedSecret() async => _secret;

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
    _relationship = relationship;
    _secret = Uint8List.fromList(sharedSecret);
  }

  @override
  Future<void> updateRelationshipMetadata(Relationship relationship) async {
    if (_relationship == null) return;
    _relationship = relationship;
  }

  @override
  Future<void> deleteRelationship() async {
    _relationship = null;
    _secret = null;
  }
}
