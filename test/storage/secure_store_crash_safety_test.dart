// Crash safety of SecureStore writes (plan Tasks 1.4 + 4.1).
//
// A storage stub that can fail a single write or "kill the process" after
// the Nth mutation, then come back as a fresh SecureStore on the same data
// (a relaunch). Every interruption point of a save must leave the
// relationship fully old or fully new: never missing, never an old role
// paired with a new secret.

import 'dart:convert';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/storage/secure_store.dart';

import '../support/in_memory_secure_storage.dart';

class _Killed implements Exception {}

class _FaultyStorage extends InMemoryFlutterSecureStorage {
  /// Mutation number (1-based) at which to fail.
  int? failAt;

  /// If true, the failure is a process death: every later call fails too,
  /// until [relaunch]. Otherwise only that one write fails.
  bool kill = false;

  int _mutations = 0;
  bool _dead = false;

  /// Fail the first read of this key (once), e.g. a transient Keystore error.
  String? failReadOnceKey;

  /// Every read of this key fails (an undecryptable value).
  String? unreadableKey;

  /// Writes to these keys fail this many more times.
  final Map<String, int> failWritesTo = <String, int>{};

  /// Deletes of these keys fail this many more times.
  final Map<String, int> failDeletesTo = <String, int>{};

  /// Total mutations since the last [relaunch].
  int get mutations => _mutations;

  void relaunch() {
    _dead = false;
    failAt = null;
    _mutations = 0;
  }

  void _mutate() {
    if (_dead) throw _Killed();
    _mutations++;
    if (_mutations == failAt) {
      if (kill) _dead = true;
      throw _Killed();
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    if (_dead) throw _Killed();
    if (key == failReadOnceKey) {
      failReadOnceKey = null;
      throw StateError('transient keystore failure');
    }
    if (key == unreadableKey) throw StateError('cannot decrypt');
    return super.read(key: key);
  }

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (_dead) throw _Killed();
    final all = await super.readAll();
    // Like Android: one value that cannot be decrypted fails the lot.
    if (unreadableKey != null && all.containsKey(unreadableKey)) {
      throw StateError('cannot decrypt $unreadableKey');
    }
    return all;
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    _mutate();
    final left = failWritesTo[key] ?? 0;
    if (left > 0) {
      failWritesTo[key] = left - 1;
      throw StateError('write to $key failed');
    }
    return super.write(key: key, value: value);
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    _mutate();
    final left = failDeletesTo[key] ?? 0;
    if (left > 0) {
      failDeletesTo[key] = left - 1;
      throw StateError('delete of $key failed');
    }
    return super.delete(key: key);
  }
}

void main() {
  final oldRel = Relationship(
    id: 'abc123',
    label: 'Mom',
    pairedAt: DateTime.utc(2026, 1, 1),
    role: PairRole.a,
  );
  final newRel = oldRel.copyWith(
    role: PairRole.b,
    pairedAt: DateTime.utc(2026, 10, 7),
  );
  final oldSecret = List<int>.filled(32, 1);
  final newSecret = List<int>.filled(32, 2);

  Future<_FaultyStorage> seededWithOld() async {
    final storage = _FaultyStorage();
    await SecureStore(
      storage: storage,
    ).saveRelationshipV2(oldRel, sharedSecret: oldSecret);
    storage.relaunch(); // count only the mutations of the save under test
    return storage;
  }

  /// A migrated, empty store, so mutation counts start at the save itself.
  Future<_FaultyStorage> migratedEmpty() async {
    final storage = _FaultyStorage();
    await SecureStore(storage: storage).listRelationshipIds();
    storage.relaunch();
    return storage;
  }

  // P4: rekey used to delete the old secret and metadata before writing
  // the new ones, so a failure in between made the contact vanish.
  group('rekey interrupted by a process kill at every write', () {
    for (var n = 1; n <= 8; n++) {
      test('kill at mutation $n leaves Mom fully old or fully new', () async {
        final dry = await seededWithOld();
        await SecureStore(
          storage: dry,
        ).saveRelationshipV2(newRel, sharedSecret: newSecret);
        final total = dry.mutations;
        final storage = await seededWithOld();
        storage
          ..failAt = n
          ..kill = true;
        var killed = false;
        try {
          await SecureStore(
            storage: storage,
          ).saveRelationshipV2(newRel, sharedSecret: newSecret);
        } on _Killed {
          killed = true;
        }
        expect(killed, n <= total, reason: 'kill point $n of $total');
        storage.relaunch();
        final store = SecureStore(storage: storage);
        final listed = await store.listRelationships();
        expect(listed.map((r) => r.id), ['abc123'], reason: 'never missing');
        final rel = (await store.getRelationshipById('abc123'))!;
        final secret = await store.getSharedSecretById('abc123');
        final isOld = rel.role == PairRole.a && _eq(secret, oldSecret);
        final isNew = rel.role == PairRole.b && _eq(secret, newSecret);
        expect(
          isOld || isNew,
          isTrue,
          reason: 'role and secret must belong to the same pairing',
        );
      });
    }
  });

  group('new pair interrupted by a process kill at every write', () {
    for (var n = 1; n <= 8; n++) {
      test('kill at mutation $n leaves the pair absent or complete', () async {
        final dry = await migratedEmpty();
        await SecureStore(
          storage: dry,
        ).saveRelationshipV2(oldRel, sharedSecret: oldSecret);
        final total = dry.mutations;
        final storage = await migratedEmpty();
        storage
          ..failAt = n
          ..kill = true;
        var killed = false;
        try {
          await SecureStore(
            storage: storage,
          ).saveRelationshipV2(oldRel, sharedSecret: oldSecret);
        } on _Killed {
          killed = true;
        }
        expect(killed, n <= total, reason: 'kill point $n of $total');
        storage.relaunch();
        final store = SecureStore(storage: storage);
        final ids = await store.listRelationshipIds();
        if (ids.contains('abc123')) {
          expect(await store.getRelationshipById('abc123'), isNotNull);
          expect(
            _eq(await store.getSharedSecretById('abc123'), oldSecret),
            isTrue,
          );
        } else {
          expect(
            storage.snapshot.keys.where((k) => k.contains('abc123')),
            isEmpty,
            reason: 'no half-written secret left behind',
          );
        }
      });
    }
  });

  test(
    'a single failed write during rekey still completes in-process',
    () async {
      final storage = await seededWithOld();
      storage.failAt = 2; // the secret write, after the journal entry
      final store = SecureStore(storage: storage);
      await store.saveRelationshipV2(newRel, sharedSecret: newSecret);
      final rel = (await store.getRelationshipById('abc123'))!;
      expect(rel.role, PairRole.b);
      expect(_eq(await store.getSharedSecretById('abc123'), newSecret), isTrue);
      expect(storage.snapshot.containsKey('signet.v2.journal'), isFalse);
    },
  );

  test('unpairing after a failed save is never undone on relaunch', () async {
    final storage = await migratedEmpty();
    storage
      ..failAt = 2
      ..kill = true;
    try {
      await SecureStore(
        storage: storage,
      ).saveRelationshipV2(oldRel, sharedSecret: oldSecret);
    } on _Killed {
      // Died after journaling.
    }
    storage.relaunch();
    final store = SecureStore(storage: storage);
    await store.deleteRelationshipById('abc123');
    storage.relaunch();
    final again = SecureStore(storage: storage);
    expect(await again.listRelationshipIds(), isEmpty);
    expect(storage.snapshot.keys.where((k) => k.contains('abc123')), isEmpty);
    expect(storage.snapshot.containsKey('signet.v2.journal'), isFalse);
  });

  test('a save killed after journaling leaves a well-formed journal', () async {
    final storage = (await migratedEmpty())
      ..failAt = 2
      ..kill = true;
    try {
      await SecureStore(
        storage: storage,
      ).saveRelationshipV2(oldRel, sharedSecret: oldSecret);
    } on _Killed {
      // Died after journaling.
    }
    final raw = storage.snapshot['signet.v2.journal']!;
    final decoded = jsonDecode(raw) as List<dynamic>;
    expect(decoded.single, containsPair('id', 'abc123'));
  });

  // S3: a failed migration future used to be cached for the life of the
  // store, so one transient Keystore error wedged every v2 call.
  test(
    'a transient failure during first access neither throws nor wipes',
    () async {
      final storage = await seededWithOld();
      storage.failReadOnceKey = 'signet.v2.index';
      final store = SecureStore(storage: storage);
      // Since the Phase 4 review an unreadable index counts as "already
      // migrated" (never restarted empty), so the first call already works.
      final listed = await store.listRelationships();
      expect(listed.map((r) => r.id), ['abc123']);
      expect(await storage.read(key: 'signet.v2.index'), contains('abc123'));
    },
  );

  // Unpair must leave no trace of the contact, whatever the crash timing
  // ("unpairing leaves no trace" is the abuse mitigation in CLAUDE.md).
  group('unpair interrupted by a process kill at every write', () {
    for (final withPending in [false, true]) {
      for (var n = 1; n <= 7; n++) {
        test('kill at mutation $n (pending save: $withPending)', () async {
          Future<_FaultyStorage> prepare() async {
            final storage = await seededWithOld();
            if (withPending) {
              // A rekey that failed twice in-process stays journaled.
              storage.failWritesTo['signet.v2.rel.abc123'] = 2;
              try {
                await SecureStore(
                  storage: storage,
                ).saveRelationshipV2(newRel, sharedSecret: newSecret);
              } on StateError {
                // Expected: both attempts failed.
              }
              storage.relaunch();
            }
            return storage;
          }

          final dry = await prepare();
          final dryStore = SecureStore(storage: dry);
          await dryStore.listRelationshipIds(); // replay first, uncounted
          dry.relaunch();
          await dryStore.deleteRelationshipById('abc123');
          final total = dry.mutations;

          final storage = await prepare();
          final store = SecureStore(storage: storage);
          await store.listRelationshipIds();
          storage
            ..relaunch()
            ..failAt = n
            ..kill = true;
          var killed = false;
          try {
            await store.deleteRelationshipById('abc123');
          } on _Killed {
            killed = true;
          }
          expect(killed, n <= total, reason: 'kill point $n of $total');
          storage.relaunch();
          final after = SecureStore(storage: storage);
          final ids = await after.listRelationshipIds();
          if (ids.isEmpty) {
            expect(
              storage.snapshot.entries.where(
                (e) =>
                    e.key.contains('abc123') ||
                    (e.key == 'signet.v2.journal' &&
                        e.value.contains('abc123')),
              ),
              isEmpty,
              reason: 'no trace once the unpair has landed',
            );
          } else {
            // Killed before the tombstone landed: Mom intact and consistent.
            final rel = (await after.getRelationshipById('abc123'))!;
            final secret = await after.getSharedSecretById('abc123');
            expect(
              (rel.role == PairRole.a && _eq(secret, oldSecret)) ||
                  (rel.role == PairRole.b && _eq(secret, newSecret)),
              isTrue,
            );
          }
        });
      }
    }
  });

  test(
    'in-process unpair after a double-failed save is never undone',
    () async {
      final storage = await migratedEmpty();
      storage.failWritesTo['signet.v2.rel.abc123'] = 2;
      final store = SecureStore(storage: storage);
      await expectLater(
        store.saveRelationshipV2(oldRel, sharedSecret: oldSecret),
        throwsStateError,
      );
      await store.deleteRelationshipById('abc123'); // same process
      storage.relaunch();
      final again = SecureStore(storage: storage);
      expect(await again.listRelationshipIds(), isEmpty);
      expect(storage.snapshot.keys.where((k) => k.contains('abc123')), isEmpty);
      expect(storage.snapshot.containsKey('signet.v2.journal'), isFalse);
    },
  );

  test('after a double-failed rekey, reads in the same session are '
      'consistent', () async {
    final storage = await seededWithOld();
    storage.failWritesTo['signet.v2.rel.abc123'] = 2;
    final store = SecureStore(storage: storage);
    await expectLater(
      store.saveRelationshipV2(newRel, sharedSecret: newSecret),
      throwsStateError,
    );
    // The secret landed but the metadata did not: reads must still agree.
    final rel = (await store.getRelationshipById('abc123'))!;
    final secret = await store.getSharedSecretById('abc123');
    expect(rel.role, PairRole.b);
    expect(_eq(secret, newSecret), isTrue);
    final listed = await store.listRelationships();
    expect(listed.single.role, PairRole.b);
  });

  test('a rename during a pending save survives the replay', () async {
    final storage = await seededWithOld();
    // The secret write fails for both save attempts and for the replay the
    // rename triggers, so the save is still pending when the rename lands.
    storage.failWritesTo['signet.v2.secret.abc123'] = 3;
    final store = SecureStore(storage: storage);
    await expectLater(
      store.saveRelationshipV2(newRel, sharedSecret: newSecret),
      throwsStateError,
    );
    await store.updateRelationshipMetadataV2(newRel.copyWith(label: 'Mother'));
    storage.relaunch();
    final again = SecureStore(storage: storage);
    expect((await again.getRelationshipById('abc123'))!.label, 'Mother');
    expect(storage.snapshot.containsKey('signet.v2.journal'), isFalse);
  });

  test('an unreadable journal never blocks listing or unpair', () async {
    final storage = await seededWithOld();
    // A journal value that can no longer be decrypted.
    await storage.write(key: 'signet.v2.journal', value: 'garbage');
    storage
      ..relaunch()
      ..unreadableKey = 'signet.v2.journal';
    final store = SecureStore(storage: storage);
    expect((await store.listRelationships()).single.id, 'abc123');
    await store.deleteRelationshipById('abc123');
    storage.unreadableKey = null;
    expect(await SecureStore(storage: storage).listRelationshipIds(), isEmpty);
  });

  for (final key in ['secret', 'rel']) {
    test('a permanently failing journal entry ($key write) never blocks the '
        'store', () async {
      final storage = await seededWithOld();
      storage.failWritesTo['signet.v2.$key.abc123'] = 1000;
      final store = SecureStore(storage: storage);
      await expectLater(
        store.saveRelationshipV2(newRel, sharedSecret: newSecret),
        throwsStateError,
      );
      storage.relaunch();
      final again = SecureStore(storage: storage);
      // Replay keeps failing, but listing, reading and unpair still work,
      // and every read agrees on the pending (new) pairing.
      expect((await again.listRelationships()).single.role, PairRole.b);
      expect((await again.getRelationshipById('abc123'))!.role, PairRole.b);
      expect(_eq(await again.getSharedSecretById('abc123'), newSecret), isTrue);
      await again.deleteRelationshipById('abc123');
      expect(await again.listRelationshipIds(), isEmpty);
    });
  }

  test(
    'after a double failure the next call in the same session replays',
    () async {
      final storage = await seededWithOld();
      storage.failWritesTo['signet.v2.rel.abc123'] = 2;
      final store = SecureStore(storage: storage);
      await expectLater(
        store.saveRelationshipV2(newRel, sharedSecret: newSecret),
        throwsStateError,
      );
      await store.listRelationshipIds(); // no relaunch
      expect(storage.snapshot.containsKey('signet.v2.journal'), isFalse);
      expect(storage.snapshot['signet.v2.rel.abc123'], newRel.toJson());
    },
  );

  group('previous pairing on rekey (plan Task 3.10)', () {
    test('a rekey keeps the old secret and role; a plain save does not',
        () async {
      final storage = await seededWithOld();
      final store = SecureStore(storage: storage);
      await store.saveRelationshipV2(newRel,
          sharedSecret: newSecret, keepPrevious: true);
      final previous = await store.getPreviousPairing(oldRel.id);
      expect(previous!.secret, oldSecret);
      expect(previous.role, oldRel.role);

      final other = await seededWithOld();
      final plain = SecureStore(storage: other);
      await plain.saveRelationshipV2(newRel, sharedSecret: newSecret);
      expect(await plain.getPreviousPairing(oldRel.id), isNull);
    });

    test('killed at any point of a rekey: if the new secret is in place, '
        'the old one is kept with its role', () async {
      final probe = await seededWithOld();
      await SecureStore(storage: probe).saveRelationshipV2(newRel,
          sharedSecret: newSecret, keepPrevious: true);
      final total = probe.mutations;
      expect(total, greaterThan(0));
      for (var at = 1; at <= total; at++) {
        final storage = await seededWithOld();
        storage
          ..failAt = at
          ..kill = true;
        try {
          await SecureStore(storage: storage).saveRelationshipV2(newRel,
              sharedSecret: newSecret, keepPrevious: true);
        } catch (_) {}
        storage.relaunch();
        final store = SecureStore(storage: storage);
        final secret = await store.getSharedSecretById(oldRel.id);
        if (_eq(secret, newSecret)) {
          final previous = await store.getPreviousPairing(oldRel.id);
          expect(previous, isNotNull, reason: 'killed at mutation $at');
          expect(previous!.secret, oldSecret, reason: 'killed at $at');
          expect(previous.role, oldRel.role, reason: 'killed at $at');
        } else {
          expect(secret, oldSecret, reason: 'killed at $at');
        }
      }
    });

    test('unpair deletes the old secret too', () async {
      final storage = await seededWithOld();
      final store = SecureStore(storage: storage);
      await store.saveRelationshipV2(newRel,
          sharedSecret: newSecret, keepPrevious: true);
      await store.deleteRelationshipById(oldRel.id);
      expect(await store.getPreviousPairing(oldRel.id), isNull);
      expect(await storage.read(key: 'signet.v2.prev.${oldRel.id}'), isNull);
    });

    test('an old secret older than 7 days is deleted when read', () async {
      final storage = await seededWithOld();
      final store = SecureStore(storage: storage);
      final eightDaysAgo = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 8))
          .millisecondsSinceEpoch;
      await storage.write(
        key: 'signet.v2.prev.${oldRel.id}',
        value: jsonEncode(<String, dynamic>{
          'secret': base64Encode(oldSecret),
          'role': 'a',
          'savedAt': eightDaysAgo,
        }),
      );
      expect(await store.getPreviousPairing(oldRel.id), isNull);
      expect(await storage.read(key: 'signet.v2.prev.${oldRel.id}'), isNull);
    });

    test('a corrupt record reads as none and is removed', () async {
      final storage = await seededWithOld();
      final store = SecureStore(storage: storage);
      await storage.write(key: 'signet.v2.prev.${oldRel.id}', value: '{"x":1');
      expect(await store.getPreviousPairing(oldRel.id), isNull);
      expect(await storage.read(key: 'signet.v2.prev.${oldRel.id}'), isNull);
    });

    test('a later save that is not a rekey drops the old secret', () async {
      final storage = await seededWithOld();
      final store = SecureStore(storage: storage);
      await store.saveRelationshipV2(newRel,
          sharedSecret: newSecret, keepPrevious: true);
      await store.saveRelationshipV2(newRel, sharedSecret: List<int>.filled(32, 3));
      expect(await store.getPreviousPairing(oldRel.id), isNull);
    });

    test('forgetting the old secret also strips it from a pending rekey, '
        'so a replay cannot bring it back', () async {
      final storage = await seededWithOld();
      // The rekey and its immediate retry both fail to write the secret.
      storage.failWritesTo['signet.v2.secret.${oldRel.id}'] = 2;
      try {
        await SecureStore(storage: storage).saveRelationshipV2(newRel,
            sharedSecret: newSecret, keepPrevious: true);
      } catch (_) {}
      final store = SecureStore(storage: storage);
      await store.deletePreviousPairing(oldRel.id);
      storage.relaunch();
      final again = SecureStore(storage: storage);
      expect(await again.getSharedSecretById(oldRel.id), newSecret,
          reason: 'the rekey itself still rolls forward');
      expect(await again.getPreviousPairing(oldRel.id), isNull);
    });

    test('an old secret dated in the future (clock was ahead) is deleted',
        () async {
      final storage = await seededWithOld();
      final store = SecureStore(storage: storage);
      await storage.write(
        key: 'signet.v2.prev.${oldRel.id}',
        value: jsonEncode(<String, dynamic>{
          'secret': base64Encode(oldSecret),
          'role': 'a',
          'savedAt': DateTime.now()
              .toUtc()
              .add(const Duration(days: 3))
              .millisecondsSinceEpoch,
        }),
      );
      expect(await store.getPreviousPairing(oldRel.id), isNull);
    });

    test('a stored old secret of the wrong length is ignored', () async {
      final storage = await seededWithOld();
      final store = SecureStore(storage: storage);
      await storage.write(
        key: 'signet.v2.prev.${oldRel.id}',
        value: jsonEncode(<String, dynamic>{
          'secret': '',
          'role': 'a',
          'savedAt': DateTime.now().toUtc().millisecondsSinceEpoch,
        }),
      );
      expect(await store.getPreviousPairing(oldRel.id), isNull);
    });
  });

  group('corrupt index (plan Task 4.3)', () {
    test('a corrupt index is rebuilt, so the next save orphans nobody',
        () async {
      final storage = await seededWithOld();
      final store = SecureStore(storage: storage);
      final dad = Relationship(
        id: 'dad1',
        label: 'Dad',
        pairedAt: DateTime.utc(2026, 1, 2),
        role: PairRole.b,
      );
      await store.saveRelationshipV2(dad, sharedSecret: newSecret);
      await storage.write(key: 'signet.v2.index', value: '[broken');

      final fresh = SecureStore(storage: storage);
      final third = dad.copyWith(id: 'kid1', label: 'Kid');
      await fresh.saveRelationshipV2(third, sharedSecret: newSecret);
      expect(
        (await fresh.listRelationships()).map((r) => r.label).toSet(),
        <String>{'Mom', 'Dad', 'Kid'},
      );
    });

    test('an id whose delete is still journaled is not brought back',
        () async {
      final storage = await seededWithOld();
      // The unpair is journaled, but removing the relationship key keeps
      // failing (it stays on disk), and the index is then corrupted.
      storage.failDeletesTo['signet.v2.rel.${oldRel.id}'] = 99;
      try {
        await SecureStore(storage: storage).deleteRelationshipById(oldRel.id);
      } catch (_) {}
      await storage.write(key: 'signet.v2.index', value: 'nope');
      expect(await storage.read(key: 'signet.v2.rel.${oldRel.id}'), isNotNull,
          reason: 'fixture: the key is still there');
      final store = SecureStore(storage: storage);
      expect(await store.listRelationshipIds(), isNot(contains(oldRel.id)));
      expect(await store.getRelationshipById(oldRel.id), isNull);
      // Nor is it written back into the rebuilt index.
      expect(await storage.read(key: 'signet.v2.index'),
          isNot(contains(oldRel.id)));
    });
  });

  group('concurrent writes (plan Task 4.2)', () {
    Relationship rel(int i) => Relationship(
          id: 'id$i',
          label: 'Contact $i',
          pairedAt: DateTime.utc(2026, 1, 1),
          role: PairRole.a,
        );

    test('reads and writes at the same first touch never deadlock '
        '(Phase 4 review)', () async {
      final storage = _FaultyStorage();
      final store = SecureStore(storage: storage);
      await Future.wait(<Future<Object?>>[
        store.saveRelationshipV2(rel(1), sharedSecret: newSecret),
        store.listRelationships(),
        store.sweepOrphans(),
        store.getSharedSecretById('id1'),
        store.deleteRelationshipById('nobody'),
        store.listRelationshipIds(),
      ]).timeout(const Duration(seconds: 5));
      expect(await store.listRelationshipIds(), <String>['id1']);
    });

    test('...nor after a failed save resets migration', () async {
      final storage = await migratedEmpty();
      final store = SecureStore(storage: storage);
      storage.failWritesTo['signet.v2.secret.id1'] = 2;
      try {
        await store.saveRelationshipV2(rel(1), sharedSecret: newSecret);
      } catch (_) {}
      await Future.wait(<Future<Object?>>[
        store.saveRelationshipV2(rel(2), sharedSecret: newSecret),
        store.listRelationships(),
        store.getRelationshipById('id1'),
        store.saveRelationshipV2(rel(3), sharedSecret: newSecret),
      ]).timeout(const Duration(seconds: 5));
      expect((await store.listRelationshipIds()).toSet(),
          <String>{'id1', 'id2', 'id3'});
    });

    test('twenty saves at once all land, and the journal ends empty',
        () async {
      final storage = await migratedEmpty();
      final store = SecureStore(storage: storage);
      await Future.wait(<Future<void>>[
        for (var i = 0; i < 20; i++)
          store.saveRelationshipV2(rel(i), sharedSecret: newSecret),
      ]);
      expect((await store.listRelationshipIds()).toSet(),
          <String>{for (var i = 0; i < 20; i++) 'id$i'});
      expect(await storage.read(key: 'signet.v2.journal'), isNull);
      final fresh = SecureStore(storage: storage);
      expect(await fresh.listRelationshipIds(), hasLength(20));
    });

    test('saves, edits and deletes at once leave a consistent store',
        () async {
      final storage = await migratedEmpty();
      final store = SecureStore(storage: storage);
      for (var i = 0; i < 10; i++) {
        await store.saveRelationshipV2(rel(i), sharedSecret: newSecret);
      }
      await Future.wait(<Future<void>>[
        for (var i = 0; i < 5; i++) store.deleteRelationshipById('id$i'),
        for (var i = 5; i < 10; i++)
          store.updateRelationshipMetadataV2(
              rel(i).copyWith(label: 'Renamed $i')),
        for (var i = 10; i < 15; i++)
          store.saveRelationshipV2(rel(i), sharedSecret: newSecret),
      ]);
      final fresh = SecureStore(storage: storage);
      final ids = (await fresh.listRelationshipIds()).toSet();
      expect(ids, <String>{for (var i = 5; i < 15; i++) 'id$i'});
      for (var i = 0; i < 5; i++) {
        expect(await fresh.getSharedSecretById('id$i'), isNull);
      }
      expect((await fresh.getRelationshipById('id7'))!.label, 'Renamed 7');
    });
  });

  group('startup sweep (plan Task 4.4)', () {
    test('a secret with no relationship is removed; a good pair is kept',
        () async {
      final storage = await seededWithOld();
      await storage.write(key: 'signet.v2.secret.ghost', value: 'AAAA');
      final report = await SecureStore(storage: storage).sweepOrphans();
      expect(report.removed, 1);
      expect(await storage.read(key: 'signet.v2.secret.ghost'), isNull);
      expect(await SecureStore(storage: storage).getSharedSecretById(oldRel.id),
          oldSecret);
    });

    test('a secret whose save is still journaled is left alone', () async {
      final storage = await seededWithOld();
      // The save is journaled, but writing its relationship keeps failing.
      final kid = oldRel.copyWith(id: 'kid1', label: 'Kid');
      storage.failWritesTo['signet.v2.rel.kid1'] = 99;
      try {
        await SecureStore(storage: storage)
            .saveRelationshipV2(kid, sharedSecret: newSecret);
      } catch (_) {}
      // Its secret is on disk with no relationship key, and the replay
      // inside the sweep keeps failing too.
      expect(await storage.read(key: 'signet.v2.rel.kid1'), isNull);
      expect(await storage.read(key: 'signet.v2.secret.kid1'), isNotNull);
      await SecureStore(storage: storage).sweepOrphans();
      expect(await storage.read(key: 'signet.v2.secret.kid1'), isNotNull,
          reason: 'the journal will finish this save');
      storage.failWritesTo.clear();
      expect(await SecureStore(storage: storage).getSharedSecretById('kid1'),
          newSecret);
    });

    test('kept old secrets: removed without a readable contact, kept with one',
        () async {
      final storage = await seededWithOld();
      final store = SecureStore(storage: storage);
      await store.saveRelationshipV2(newRel,
          sharedSecret: newSecret, keepPrevious: true);
      await storage.write(key: 'signet.v2.prev.gone', value: '{}');
      await storage.write(key: 'signet.v2.rel.broken', value: '{"newer":1');
      await storage.write(key: 'signet.v2.secret.broken', value: 'AAAA');
      await storage.write(key: 'signet.v2.prev.broken', value: '{}');
      await SecureStore(storage: storage).sweepOrphans();
      expect(await storage.read(key: 'signet.v2.prev.gone'), isNull);
      expect(await storage.read(key: 'signet.v2.prev.broken'), isNull);
      expect(await storage.read(key: 'signet.v2.prev.${oldRel.id}'),
          isNotNull);
    });

    test('an unreadable contact is quarantined, not deleted, and can be '
        'removed', () async {
      final storage = await seededWithOld();
      final store = SecureStore(storage: storage);
      // A newer build wrote a shape this one cannot parse.
      await storage.write(
          key: 'signet.v2.rel.${oldRel.id}', value: '{"v":9,"x":[');
      await store.sweepOrphans();
      expect(await storage.read(key: 'signet.v2.rel.${oldRel.id}'), isNotNull);
      expect(await storage.read(key: 'signet.v2.secret.${oldRel.id}'),
          isNotNull);
      expect(await store.listRelationships(), isEmpty);
      expect(await store.listUnreadableRelationshipIds(), <String>[oldRel.id]);

      await store.deleteRelationshipById(oldRel.id);
      expect(await store.listUnreadableRelationshipIds(), isEmpty);
      expect(await storage.read(key: 'signet.v2.secret.${oldRel.id}'), isNull);
    });

    test('a readable contact missing from the index is put back', () async {
      final storage = await seededWithOld();
      await storage.write(key: 'signet.v2.index', value: '[]');
      final store = SecureStore(storage: storage);
      expect(await store.listRelationshipIds(), isEmpty);
      final report = await store.sweepOrphans();
      expect(report.restored, 1);
      expect(await store.listRelationshipIds(), <String>[oldRel.id]);
    });

    test('leftover v1 keys are removed once v2 is in place', () async {
      final storage = await seededWithOld();
      await storage.write(key: 'signet.v1.relationship', value: '{}');
      await storage.write(key: 'signet.v1.shared_secret', value: 'AAAA');
      await SecureStore(storage: storage).sweepOrphans();
      expect(await storage.read(key: 'signet.v1.relationship'), isNull);
      expect(await storage.read(key: 'signet.v1.shared_secret'), isNull);
    });

    test('a storage error stops the sweep without harming a good pair',
        () async {
      final storage = await seededWithOld();
      await storage.write(key: 'signet.v2.secret.ghost', value: 'AAAA');
      storage.failDeletesTo['signet.v2.secret.ghost'] = 1;
      final report = await SecureStore(storage: storage).sweepOrphans();
      expect(report.removed, 0);
      expect(await SecureStore(storage: storage).getSharedSecretById(oldRel.id),
          oldSecret);
    });
  });

  group('undecryptable values (Phase 4 review)', () {
    test('an undecryptable index is rebuilt', () async {
      final storage = await seededWithOld();
      storage.unreadableKey = 'signet.v2.index';
      final store = SecureStore(storage: storage);
      expect(await store.listRelationshipIds(), <String>[oldRel.id]);
      storage.unreadableKey = null;
      expect(await SecureStore(storage: storage).listRelationshipIds(),
          <String>[oldRel.id]);
    });

    test('an undecryptable contact is quarantined, not fatal', () async {
      final storage = await seededWithOld();
      final dad = oldRel.copyWith(id: 'dad1', label: 'Dad');
      await SecureStore(storage: storage)
          .saveRelationshipV2(dad, sharedSecret: newSecret);
      storage.unreadableKey = 'signet.v2.rel.${oldRel.id}';
      final store = SecureStore(storage: storage);
      expect((await store.listRelationships()).map((r) => r.label),
          <String>['Dad']);
      expect(await store.listUnreadableRelationshipIds(), <String>[oldRel.id]);
      await store.deleteRelationshipById(oldRel.id);
      expect(await store.listUnreadableRelationshipIds(), isEmpty);
    });

    test('a relationship left without its secret is finished off by the '
        'sweep and never rebuilt into the index', () async {
      final storage = await seededWithOld();
      await storage.delete(key: 'signet.v2.secret.${oldRel.id}');
      await storage.write(key: 'signet.v2.index', value: 'corrupt');
      final store = SecureStore(storage: storage);
      expect(await store.listRelationshipIds(), isEmpty,
          reason: 'rebuild needs the secret too');
      await store.sweepOrphans();
      expect(await storage.read(key: 'signet.v2.rel.${oldRel.id}'), isNull);
    });
  });
}

bool _eq(List<int>? a, List<int> b) => a != null && listEquals(a, b);
