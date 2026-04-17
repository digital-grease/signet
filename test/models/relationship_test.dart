import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/models/relationship.dart';

void main() {
  group('Relationship', () {
    test('fresh() mints a 32-hex-char id and UTC timestamp', () {
      final rel = Relationship.fresh(
        label: 'Mom',
        now: DateTime.utc(2026, 4, 16, 12),
        random: Random(42),
      );
      expect(rel.label, 'Mom');
      expect(rel.id, hasLength(32));
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(rel.id), isTrue);
      expect(rel.pairedAt.isUtc, isTrue);
    });

    test('fresh() is deterministic under a seeded RNG', () {
      final a = Relationship.fresh(
        label: 'Mom',
        now: DateTime.utc(2026, 4, 16, 12),
        random: Random(7),
      );
      final b = Relationship.fresh(
        label: 'Mom',
        now: DateTime.utc(2026, 4, 16, 12),
        random: Random(7),
      );
      expect(a.id, b.id);
    });

    test('fresh() uses a different id on each call with secure RNG', () {
      final a = Relationship.fresh(label: 'Mom');
      final b = Relationship.fresh(label: 'Mom');
      expect(a.id, isNot(b.id));
    });

    test('JSON round-trip preserves all fields', () {
      final original = Relationship(
        id: 'abc123',
        label: 'Jake',
        pairedAt: DateTime.utc(2026, 1, 15, 9, 30),
      );
      final restored = Relationship.fromJson(original.toJson());
      expect(restored, equals(original));
    });

    test('equality compares fields (not identity)', () {
      final a = Relationship(
        id: 'x',
        label: 'L',
        pairedAt: DateTime.utc(2026, 1, 1),
      );
      final b = Relationship(
        id: 'x',
        label: 'L',
        pairedAt: DateTime.utc(2026, 1, 1),
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('pairedAt is normalized to UTC on comparison', () {
      final utc = Relationship(
        id: 'x',
        label: 'L',
        pairedAt: DateTime.utc(2026, 1, 1, 12),
      );
      final local = Relationship(
        id: 'x',
        label: 'L',
        pairedAt: DateTime.utc(2026, 1, 1, 12).toLocal(),
      );
      expect(utc, equals(local));
    });
  });
}
