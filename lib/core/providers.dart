import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/relationship.dart';
import 'storage/secure_store.dart';

/// Singleton secure-storage wrapper. Override in tests to inject a mock.
final Provider<SecureStore> secureStoreProvider = Provider<SecureStore>(
  (Ref ref) => SecureStore(),
);

/// All currently paired relationships. In v0.1 single-slot territory this
/// will have 0 or 1 entries; Phase 10.4 surfaces it as a list UI. Invalidate
/// (`ref.invalidate(relationshipsProvider)`) after any pair / unpair /
/// rename to force a re-read.
final FutureProvider<List<Relationship>> relationshipsProvider =
    FutureProvider<List<Relationship>>(
  (Ref ref) async {
    final store = ref.watch(secureStoreProvider);
    return store.listRelationships();
  },
);

/// Shared secret for a single relationship id. Returns null when no such
/// id is stored. Invalidate via
/// `ref.invalidate(sharedSecretProvider(id))` if the secret was rotated
/// (rekey, Phase 10.6) or if the relationship was deleted and undo
/// restored it.
final sharedSecretProvider = FutureProvider.family<Uint8List?, String>(
  (Ref ref, String id) async {
    final store = ref.watch(secureStoreProvider);
    return store.getSharedSecretById(id);
  },
);
