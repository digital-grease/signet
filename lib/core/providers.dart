import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/relationship.dart';
import 'storage/secure_store.dart';

/// Singleton secure-storage wrapper. Override in tests to inject a mock.
final Provider<SecureStore> secureStoreProvider = Provider<SecureStore>(
  (Ref ref) => SecureStore(),
);

/// The currently paired relationship, or null if none.
/// Invalidate this provider (`ref.invalidate(relationshipProvider)`) after
/// a successful pair or unpair to force a re-read.
final FutureProvider<Relationship?> relationshipProvider =
    FutureProvider<Relationship?>(
  (Ref ref) async {
    final store = ref.watch(secureStoreProvider);
    return store.getRelationship();
  },
);
