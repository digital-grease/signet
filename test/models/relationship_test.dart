import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/models/relationship.dart';

void main() {
  group('Relationship', () {
    test('fresh() mints a 32-hex-char id and UTC timestamp', () {
      final rel = Relationship.fresh(
        label: 'Mom',
        role: PairRole.a,
        now: DateTime.utc(2026, 4, 16, 12),
        random: Random(42),
      );
      expect(rel.label, 'Mom');
      expect(rel.id, hasLength(32));
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(rel.id), isTrue);
      expect(rel.pairedAt.isUtc, isTrue);
      expect(rel.role, PairRole.a);
    });

    test('fresh() is deterministic under a seeded RNG', () {
      final a = Relationship.fresh(
        label: 'Mom',
        role: PairRole.a,
        now: DateTime.utc(2026, 4, 16, 12),
        random: Random(7),
      );
      final b = Relationship.fresh(
        label: 'Mom',
        role: PairRole.a,
        now: DateTime.utc(2026, 4, 16, 12),
        random: Random(7),
      );
      expect(a.id, b.id);
    });

    test('fresh() uses a different id on each call with secure RNG', () {
      final a = Relationship.fresh(label: 'Mom', role: PairRole.a);
      final b = Relationship.fresh(label: 'Mom', role: PairRole.a);
      expect(a.id, isNot(b.id));
    });

    test('JSON round-trip preserves all fields including role', () {
      final original = Relationship(
        id: 'abc123',
        label: 'Jake',
        pairedAt: DateTime.utc(2026, 1, 15, 9, 30),
        role: PairRole.b,
      );
      final restored = Relationship.fromJson(original.toJson());
      expect(restored, equals(original));
      expect(restored.role, PairRole.b);
    });

    test('JSON round-trip with role a', () {
      final original = Relationship(
        id: 'xyz',
        label: 'Dad',
        pairedAt: DateTime.utc(2026, 2, 1),
        role: PairRole.a,
      );
      final restored = Relationship.fromJson(original.toJson());
      expect(restored, equals(original));
      expect(restored.role, PairRole.a);
    });

    test('fromJson throws on pre-Phase-8 blob without role', () {
      const legacy = '{"id":"abc","label":"Mom","pairedAtMs":1776000000000}';
      expect(() => Relationship.fromJson(legacy), throwsFormatException);
    });

    test('fromJson throws on unknown role wire name', () {
      const bad =
          '{"id":"abc","label":"Mom","pairedAtMs":1776000000000,"role":"c"}';
      expect(() => Relationship.fromJson(bad), throwsFormatException);
    });

    test('equality compares fields (including role)', () {
      final a = Relationship(
        id: 'x',
        label: 'L',
        pairedAt: DateTime.utc(2026, 1, 1),
        role: PairRole.a,
      );
      final b = Relationship(
        id: 'x',
        label: 'L',
        pairedAt: DateTime.utc(2026, 1, 1),
        role: PairRole.a,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different roles break equality even when other fields match', () {
      final a = Relationship(
        id: 'x',
        label: 'L',
        pairedAt: DateTime.utc(2026, 1, 1),
        role: PairRole.a,
      );
      final b = Relationship(
        id: 'x',
        label: 'L',
        pairedAt: DateTime.utc(2026, 1, 1),
        role: PairRole.b,
      );
      expect(a, isNot(equals(b)));
    });

    test('pairedAt is normalized to UTC on comparison', () {
      final utc = Relationship(
        id: 'x',
        label: 'L',
        pairedAt: DateTime.utc(2026, 1, 1, 12),
        role: PairRole.a,
      );
      final local = Relationship(
        id: 'x',
        label: 'L',
        pairedAt: DateTime.utc(2026, 1, 1, 12).toLocal(),
        role: PairRole.a,
      );
      expect(utc, equals(local));
    });
  });
}
