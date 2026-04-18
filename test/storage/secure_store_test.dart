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
}
