import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/storage/secure_store.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockStorage mockStorage;
  late SecureStore store;

  setUp(() {
    mockStorage = _MockStorage();
    store = SecureStore(storage: mockStorage);

    when(() => mockStorage.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});
    when(() => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async {});
    // Catchall so unmocked reads (any key) resolve to null. Without this,
    // mocktail raises a type error ("null is not a Future<String?>") when
    // migration probes keys the individual test didn't bother to mock.
    when(() => mockStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
  });

  final relationship = Relationship(
    id: 'abc123',
    label: 'Mom',
    pairedAt: DateTime.utc(2026, 4, 16, 12),
    role: PairRole.a,
  );
  final sharedSecret = List<int>.generate(32, (i) => i);

  group('hasRelationship', () {
    test('returns false when no relationship is stored', () async {
      when(() => mockStorage.read(key: 'signet.v1.relationship'))
          .thenAnswer((_) async => null);
      expect(await store.hasRelationship(), isFalse);
    });

    test('returns true when a relationship is stored', () async {
      when(() => mockStorage.read(key: 'signet.v1.relationship'))
          .thenAnswer((_) async => relationship.toJson());
      expect(await store.hasRelationship(), isTrue);
    });
  });

  group('saveRelationship', () {
    test('clears prior slot, writes secret, then writes relationship',
        () async {
      await store.saveRelationship(relationship, sharedSecret: sharedSecret);

      verifyInOrder([
        () => mockStorage.delete(key: 'signet.v1.relationship'),
        () => mockStorage.delete(key: 'signet.v1.shared_secret'),
        () => mockStorage.write(
              key: 'signet.v1.shared_secret',
              value: base64Encode(sharedSecret),
            ),
        () => mockStorage.write(
              key: 'signet.v1.relationship',
              value: relationship.toJson(),
            ),
      ]);
    });

    test('rejects empty shared secret', () async {
      expect(
        () => store.saveRelationship(relationship, sharedSecret: const []),
        throwsArgumentError,
      );
      verifyNever(() => mockStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ));
    });

    test('never persists the shared secret on the relationship metadata',
        () async {
      await store.saveRelationship(relationship, sharedSecret: sharedSecret);
      final metadataCall = verify(() => mockStorage.write(
            key: 'signet.v1.relationship',
            value: captureAny(named: 'value'),
          ))
        ..called(1);
      final written = metadataCall.captured.single as String;
      expect(written.contains(base64Encode(sharedSecret)), isFalse);
      expect(written.contains('shared_secret'), isFalse);
    });
  });

  group('getRelationship', () {
    test('returns null when nothing is stored', () async {
      when(() => mockStorage.read(key: 'signet.v1.relationship'))
          .thenAnswer((_) async => null);
      expect(await store.getRelationship(), isNull);
    });

    test('round-trips a stored relationship', () async {
      when(() => mockStorage.read(key: 'signet.v1.relationship'))
          .thenAnswer((_) async => relationship.toJson());
      expect(await store.getRelationship(), equals(relationship));
    });

    test(
      'wipes both slots and returns null when the stored blob is pre-Phase-8 '
      '(no role field)',
      () async {
        const legacy =
            '{"id":"abc","label":"Mom","pairedAtMs":1776000000000}';
        when(() => mockStorage.read(key: 'signet.v1.relationship'))
            .thenAnswer((_) async => legacy);
        expect(await store.getRelationship(), isNull);
        verify(() => mockStorage.delete(key: 'signet.v1.relationship'))
            .called(1);
        verify(() => mockStorage.delete(key: 'signet.v1.shared_secret'))
            .called(1);
      },
    );

    test(
      'wipes both slots and returns null when the stored blob has an '
      'unknown role wire name',
      () async {
        const bad =
            '{"id":"abc","label":"Mom","pairedAtMs":1776000000000,"role":"c"}';
        when(() => mockStorage.read(key: 'signet.v1.relationship'))
            .thenAnswer((_) async => bad);
        expect(await store.getRelationship(), isNull);
        verify(() => mockStorage.delete(key: 'signet.v1.relationship'))
            .called(1);
        verify(() => mockStorage.delete(key: 'signet.v1.shared_secret'))
            .called(1);
      },
    );
  });

  group('getSharedSecret', () {
    test('returns null when nothing is stored', () async {
      when(() => mockStorage.read(key: 'signet.v1.shared_secret'))
          .thenAnswer((_) async => null);
      expect(await store.getSharedSecret(), isNull);
    });

    test('decodes the stored base64 secret', () async {
      when(() => mockStorage.read(key: 'signet.v1.shared_secret'))
          .thenAnswer((_) async => base64Encode(sharedSecret));
      final out = await store.getSharedSecret();
      expect(out, isNotNull);
      expect(out!.toList(), equals(sharedSecret));
    });
  });

  group('deleteRelationship', () {
    test('deletes both metadata and shared-secret slots', () async {
      await store.deleteRelationship();
      verify(() => mockStorage.delete(key: 'signet.v1.relationship'))
          .called(1);
      verify(() => mockStorage.delete(key: 'signet.v1.shared_secret'))
          .called(1);
    });
  });

  // ========================================================================
  // v2 keyed API (Phase 10.1). Covers the new multi-slot layer. Migration
  // from v1 is a separate task (10.2) and gets its own tests there.
  // ========================================================================

  group('v2 listRelationshipIds', () {
    test('returns empty list when no index entry exists', () async {
      when(() => mockStorage.read(key: 'signet.v2.index'))
          .thenAnswer((_) async => null);
      expect(await store.listRelationshipIds(), isEmpty);
    });

    test('decodes the stored JSON array', () async {
      when(() => mockStorage.read(key: 'signet.v2.index'))
          .thenAnswer((_) async => '["abc","def"]');
      expect(await store.listRelationshipIds(), <String>['abc', 'def']);
    });

    test('returns empty list when index blob is malformed', () async {
      when(() => mockStorage.read(key: 'signet.v2.index'))
          .thenAnswer((_) async => '{not-json');
      expect(await store.listRelationshipIds(), isEmpty);
    });
  });

  group('v2 saveRelationshipV2', () {
    test('writes secret + metadata + appends to index', () async {
      when(() => mockStorage.read(key: 'signet.v2.index'))
          .thenAnswer((_) async => null);
      await store.saveRelationshipV2(
        relationship,
        sharedSecret: sharedSecret,
      );
      verifyInOrder([
        () => mockStorage.delete(key: 'signet.v2.rel.abc123'),
        () => mockStorage.delete(key: 'signet.v2.secret.abc123'),
        () => mockStorage.write(
              key: 'signet.v2.secret.abc123',
              value: base64Encode(sharedSecret),
            ),
        () => mockStorage.write(
              key: 'signet.v2.rel.abc123',
              value: relationship.toJson(),
            ),
        () => mockStorage.write(
              key: 'signet.v2.index',
              value: '["abc123"]',
            ),
      ]);
    });

    test('does not re-add id to index when it is already present', () async {
      when(() => mockStorage.read(key: 'signet.v2.index'))
          .thenAnswer((_) async => '["abc123"]');
      await store.saveRelationshipV2(
        relationship,
        sharedSecret: sharedSecret,
      );
      // The index write should NOT be called with a duplicated id.
      verifyNever(() => mockStorage.write(
            key: 'signet.v2.index',
            value: any(named: 'value'),
          ));
    });

    test('rejects empty shared secret', () async {
      expect(
        () => store.saveRelationshipV2(
          relationship,
          sharedSecret: const <int>[],
        ),
        throwsArgumentError,
      );
    });
  });

  group('v2 getRelationshipById / getSharedSecretById', () {
    test('returns null when id is not in the store', () async {
      when(() => mockStorage.read(key: 'signet.v2.rel.nope'))
          .thenAnswer((_) async => null);
      when(() => mockStorage.read(key: 'signet.v2.secret.nope'))
          .thenAnswer((_) async => null);
      expect(await store.getRelationshipById('nope'), isNull);
      expect(await store.getSharedSecretById('nope'), isNull);
    });

    test('decodes stored relationship + secret for a known id', () async {
      when(() => mockStorage.read(key: 'signet.v2.rel.abc123'))
          .thenAnswer((_) async => relationship.toJson());
      when(() => mockStorage.read(key: 'signet.v2.secret.abc123'))
          .thenAnswer((_) async => base64Encode(sharedSecret));
      expect(await store.getRelationshipById('abc123'), equals(relationship));
      final got = await store.getSharedSecretById('abc123');
      expect(got, isNotNull);
      expect(got!.toList(), sharedSecret);
    });

    test('getRelationshipById returns null on malformed metadata blob',
        () async {
      when(() => mockStorage.read(key: 'signet.v2.rel.abc123'))
          .thenAnswer((_) async => 'not-json');
      expect(await store.getRelationshipById('abc123'), isNull);
    });
  });

  group('v2 listRelationships', () {
    test('returns entries for every id in the index', () async {
      final second = Relationship(
        id: 'def456',
        label: 'Dad',
        pairedAt: DateTime.utc(2026, 1, 1),
        role: PairRole.b,
      );
      when(() => mockStorage.read(key: 'signet.v2.index'))
          .thenAnswer((_) async => '["abc123","def456"]');
      when(() => mockStorage.read(key: 'signet.v2.rel.abc123'))
          .thenAnswer((_) async => relationship.toJson());
      when(() => mockStorage.read(key: 'signet.v2.rel.def456'))
          .thenAnswer((_) async => second.toJson());
      final got = await store.listRelationships();
      expect(got, hasLength(2));
      expect(got.first.id, 'abc123');
      expect(got.last.id, 'def456');
    });

    test('skips entries whose metadata failed to parse', () async {
      when(() => mockStorage.read(key: 'signet.v2.index'))
          .thenAnswer((_) async => '["abc123","bad"]');
      when(() => mockStorage.read(key: 'signet.v2.rel.abc123'))
          .thenAnswer((_) async => relationship.toJson());
      when(() => mockStorage.read(key: 'signet.v2.rel.bad'))
          .thenAnswer((_) async => '{malformed');
      final got = await store.listRelationships();
      expect(got, hasLength(1));
      expect(got.single.id, 'abc123');
    });
  });

  group('v2 deleteRelationshipById', () {
    test('removes the metadata, secret, and index entry for that id',
        () async {
      when(() => mockStorage.read(key: 'signet.v2.index'))
          .thenAnswer((_) async => '["abc123","def456"]');
      await store.deleteRelationshipById('abc123');
      verify(() => mockStorage.delete(key: 'signet.v2.rel.abc123'))
          .called(1);
      verify(() => mockStorage.delete(key: 'signet.v2.secret.abc123'))
          .called(1);
      verify(() => mockStorage.write(
            key: 'signet.v2.index',
            value: '["def456"]',
          )).called(1);
    });

    test('is a no-op when id is not in the index', () async {
      when(() => mockStorage.read(key: 'signet.v2.index'))
          .thenAnswer((_) async => '[]');
      await store.deleteRelationshipById('abc123');
      // Both key deletes still fire (cheap; covers partial-state cleanup)
      // but the index write should not, because nothing changed.
      verifyNever(() => mockStorage.write(
            key: 'signet.v2.index',
            value: any(named: 'value'),
          ));
    });
  });

  // ========================================================================
  // Migration v1 → v2 (Phase 10.2). Runs lazily on the first v2 call.
  // ========================================================================

  group('v1 → v2 migration', () {
    test(
      'fresh install with no v1 data writes an empty v2 index',
      () async {
        when(() => mockStorage.read(key: 'signet.v2.index'))
            .thenAnswer((_) async => null);
        when(() => mockStorage.read(key: 'signet.v1.relationship'))
            .thenAnswer((_) async => null);
        when(() => mockStorage.read(key: 'signet.v1.shared_secret'))
            .thenAnswer((_) async => null);

        expect(await store.listRelationshipIds(), isEmpty);
        verify(() => mockStorage.write(
              key: 'signet.v2.index',
              value: '[]',
            )).called(1);
      },
    );

    test(
      'valid v1 data is promoted to v2 keys and v1 keys are deleted',
      () async {
        // Stateful mock for the index: returns null until migration writes
        // to it, then returns the written value on subsequent reads. This
        // matches real storage semantics and lets `listRelationshipIds`
        // see the post-migration index on its second read.
        String? indexValue;
        when(() => mockStorage.read(key: 'signet.v2.index'))
            .thenAnswer((_) async => indexValue);
        when(() => mockStorage.write(
              key: 'signet.v2.index',
              value: any(named: 'value'),
            )).thenAnswer((inv) async {
          indexValue = inv.namedArguments[const Symbol('value')] as String;
        });
        when(() => mockStorage.read(key: 'signet.v1.relationship'))
            .thenAnswer((_) async => relationship.toJson());
        when(() => mockStorage.read(key: 'signet.v1.shared_secret'))
            .thenAnswer((_) async => base64Encode(sharedSecret));

        final ids = await store.listRelationshipIds();
        expect(ids, <String>['abc123']);
        verify(() => mockStorage.write(
              key: 'signet.v2.rel.abc123',
              value: relationship.toJson(),
            )).called(1);
        verify(() => mockStorage.write(
              key: 'signet.v2.secret.abc123',
              value: base64Encode(sharedSecret),
            )).called(1);
        verify(() => mockStorage.write(
              key: 'signet.v2.index',
              value: '["abc123"]',
            )).called(1);
        verify(() => mockStorage.delete(key: 'signet.v1.relationship'))
            .called(1);
        verify(() => mockStorage.delete(key: 'signet.v1.shared_secret'))
            .called(1);
      },
    );

    test(
      'corrupt v1 blob is discarded; v2 index starts empty; v1 keys wiped',
      () async {
        when(() => mockStorage.read(key: 'signet.v2.index'))
            .thenAnswer((_) async => null);
        when(() => mockStorage.read(key: 'signet.v1.relationship'))
            .thenAnswer((_) async => '{not-json');
        when(() => mockStorage.read(key: 'signet.v1.shared_secret'))
            .thenAnswer((_) async => base64Encode(sharedSecret));

        expect(await store.listRelationshipIds(), isEmpty);
        verify(() => mockStorage.write(
              key: 'signet.v2.index',
              value: '[]',
            )).called(1);
        verify(() => mockStorage.delete(key: 'signet.v1.relationship'))
            .called(1);
        verify(() => mockStorage.delete(key: 'signet.v1.shared_secret'))
            .called(1);
      },
    );

    test(
      'pre-Phase-8 v1 blob (no role field) is treated as corrupt and wiped',
      () async {
        const legacy =
            '{"id":"abc","label":"Mom","pairedAtMs":1776000000000}';
        when(() => mockStorage.read(key: 'signet.v2.index'))
            .thenAnswer((_) async => null);
        when(() => mockStorage.read(key: 'signet.v1.relationship'))
            .thenAnswer((_) async => legacy);
        when(() => mockStorage.read(key: 'signet.v1.shared_secret'))
            .thenAnswer((_) async => base64Encode(sharedSecret));

        expect(await store.listRelationshipIds(), isEmpty);
        verify(() => mockStorage.delete(key: 'signet.v1.relationship'))
            .called(1);
      },
    );

    test(
      'v1 metadata present but secret missing → treated as corrupt',
      () async {
        when(() => mockStorage.read(key: 'signet.v2.index'))
            .thenAnswer((_) async => null);
        when(() => mockStorage.read(key: 'signet.v1.relationship'))
            .thenAnswer((_) async => relationship.toJson());
        when(() => mockStorage.read(key: 'signet.v1.shared_secret'))
            .thenAnswer((_) async => null);

        expect(await store.listRelationshipIds(), isEmpty);
        verify(() => mockStorage.write(
              key: 'signet.v2.index',
              value: '[]',
            )).called(1);
      },
    );

    test(
      'migration is a no-op when v2 index already exists',
      () async {
        when(() => mockStorage.read(key: 'signet.v2.index'))
            .thenAnswer((_) async => '["abc123"]');

        await store.listRelationshipIds();
        verifyNever(() => mockStorage.read(key: 'signet.v1.relationship'));
        verifyNever(() => mockStorage.read(key: 'signet.v1.shared_secret'));
        verifyNever(() => mockStorage.delete(key: 'signet.v1.relationship'));
      },
    );

    test(
      'migration runs exactly once across multiple v2 calls on same store',
      () async {
        // First call sees no index; subsequent calls see the (just-written)
        // index and take the fast path. The instance-level guard ensures
        // we never re-attempt the migration dance.
        var indexRead = 0;
        when(() => mockStorage.read(key: 'signet.v2.index')).thenAnswer(
          (_) async {
            indexRead++;
            // Return null for the first look (migration trigger), then
            // the empty index afterward.
            return indexRead == 1 ? null : '[]';
          },
        );
        when(() => mockStorage.read(key: 'signet.v1.relationship'))
            .thenAnswer((_) async => null);
        when(() => mockStorage.read(key: 'signet.v1.shared_secret'))
            .thenAnswer((_) async => null);

        await store.listRelationshipIds();
        await store.listRelationshipIds();
        await store.listRelationshipIds();

        // Only one migration-path delete attempt (which is zero here since
        // v1 was empty). Only one v2 index *write* from migration.
        verify(() => mockStorage.write(
              key: 'signet.v2.index',
              value: '[]',
            )).called(1);
      },
    );
  });

  group('v2 updateRelationshipMetadataV2', () {
    test('rewrites metadata for an id already in the index', () async {
      when(() => mockStorage.read(key: 'signet.v2.index'))
          .thenAnswer((_) async => '["abc123"]');
      final renamed = relationship.copyWith(label: 'Mother');
      await store.updateRelationshipMetadataV2(renamed);
      verify(() => mockStorage.write(
            key: 'signet.v2.rel.abc123',
            value: renamed.toJson(),
          )).called(1);
    });

    test('is a no-op for an id not in the index', () async {
      when(() => mockStorage.read(key: 'signet.v2.index'))
          .thenAnswer((_) async => '[]');
      await store.updateRelationshipMetadataV2(relationship);
      verifyNever(() => mockStorage.write(
            key: 'signet.v2.rel.abc123',
            value: any(named: 'value'),
          ));
    });
  });
}
