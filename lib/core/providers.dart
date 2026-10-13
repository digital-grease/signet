import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'logging/debug_log.dart';
import 'models/relationship.dart';
import 'storage/secure_store.dart';

/// Singleton secure-storage wrapper. Override in tests to inject a mock.
final Provider<SecureStore> secureStoreProvider = Provider<SecureStore>(
  (Ref ref) => SecureStore(),
);

/// App-wide breadcrumb logger (Phase 8). The default carries an in-memory ring
/// only (no session), so any screen can call `ref.read(debugLogProvider).log(...)`
/// safely in tests. `main()` overrides this with a [DebugLog] wired to an
/// encrypted [DebugSession] so opt-in debug logging actually persists.
final Provider<DebugLog> debugLogProvider = Provider<DebugLog>(
  (Ref ref) => DebugLog(),
);

/// All currently paired relationships. In v0.1 single-slot territory this
/// will have 0 or 1 entries; Phase 10.4 surfaces it as a list UI. Invalidate
/// (`ref.invalidate(relationshipsProvider)`) after any pair / unpair /
/// rename to force a re-read.
final FutureProvider<List<Relationship>> relationshipsProvider =
    FutureProvider<List<Relationship>>(
  (Ref ref) async {
    final store = ref.watch(secureStoreProvider);
    // The first listing waits for the startup sweep, which can put a lost
    // contact back into the index, but never for long: a stuck sweep must
    // not leave Home on a spinner.
    await _sweepOrTimeout(ref);
    return store.listRelationships();
  },
);

Future<void> _sweepOrTimeout(Ref ref) => ref
    .watch(storeSweepProvider.future)
    .timeout(const Duration(seconds: 3),
        onTimeout: () => const SweepReport(removed: 0, restored: 0))
    .then((_) {}, onError: (Object _) {});

/// Startup orphan sweep (plan Task 4.4), once per app session. Never
/// fails: an error leaves storage as it was.
final FutureProvider<SweepReport> storeSweepProvider =
    FutureProvider<SweepReport>(
  (Ref ref) => ref.watch(secureStoreProvider).sweepOrphans(),
);

/// Ids of stored contacts that cannot be read (plan Task 4.4): kept, not
/// listed, and counted in Settings with an option to remove them.
/// Invalidate together with [relationshipsProvider].
final FutureProvider<List<String>> unreadableRelationshipsProvider =
    FutureProvider<List<String>>(
  (Ref ref) async {
    final store = ref.watch(secureStoreProvider);
    await _sweepOrTimeout(ref);
    return store.listUnreadableRelationshipIds();
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
