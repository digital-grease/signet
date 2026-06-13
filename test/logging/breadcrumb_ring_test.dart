import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/logging/breadcrumb.dart';
import 'package:signet/core/models/relationship.dart';

void main() {
  Relationship rel(String id, String label) => Relationship(
        id: id,
        label: label,
        pairedAt: DateTime.utc(2026, 1, 1),
        role: PairRole.a,
      );

  group('Breadcrumb.format', () {
    test('renders relative offset, event wire, ref, and n', () {
      const c = Breadcrumb(
        atMs: 1234,
        event: BreadcrumbEvent.verifyWindowWalk,
        ref: 'a1b2',
        n: 3,
      );
      expect(c.format(), '+1234ms verify.window_walk ref=a1b2 n=3');
    });

    test('omits ref and n when absent', () {
      const c = Breadcrumb(atMs: 0, event: BreadcrumbEvent.appStart);
      expect(c.format(), '+0ms app.start');
    });
  });

  group('write-time discipline (leak prevention)', () {
    test('Breadcrumb.of records the opaque id, NEVER the label', () {
      const canaryLabel = 'CONFIDENTIAL_SOURCE';
      final r = rel('0a1b2c3d4e5f60718293a4b5c6d7e8f9', canaryLabel);
      final c = Breadcrumb.of(
        atMs: 10,
        event: BreadcrumbEvent.verifyStart,
        relationship: r,
      );
      expect(c.ref, r.id);
      expect(c.format(), isNot(contains(canaryLabel)));
      expect(c.format(), contains(r.id));
    });

    test('every BreadcrumbEvent wire is a plain dotted token (no spaces)', () {
      for (final e in BreadcrumbEvent.values) {
        expect(e.wire, matches(RegExp(r'^[a-z]+(\.[a-z_]+)+$')),
            reason: 'event ${e.name} has a non-constant-looking wire');
      }
    });
  });

  group('BreadcrumbRing', () {
    test('evicts oldest past capacity', () {
      final ring = BreadcrumbRing(capacity: 3);
      for (var i = 0; i < 5; i++) {
        ring.add(Breadcrumb(atMs: i, event: BreadcrumbEvent.navTo, n: i));
      }
      expect(ring.length, 3);
      final dump = ring.dump();
      // Oldest two (n=0, n=1) evicted; newest three remain.
      expect(dump, isNot(contains('n=0')));
      expect(dump, isNot(contains('n=1')));
      expect(dump, contains('n=2'));
      expect(dump, contains('n=4'));
    });

    test('dump is oldest-first, newline-joined; empty when empty', () {
      final ring = BreadcrumbRing(capacity: 10);
      expect(ring.dump(), '');
      ring.add(const Breadcrumb(atMs: 1, event: BreadcrumbEvent.appStart));
      ring.add(const Breadcrumb(atMs: 2, event: BreadcrumbEvent.appResumed));
      expect(ring.dump(), '+1ms app.start\n+2ms app.resumed');
    });

    test('clear empties the ring', () {
      final ring = BreadcrumbRing(capacity: 4)
        ..add(const Breadcrumb(atMs: 1, event: BreadcrumbEvent.appStart));
      ring.clear();
      expect(ring.length, 0);
      expect(ring.dump(), '');
    });

    test('snapshot is unmodifiable', () {
      final ring = BreadcrumbRing()
        ..add(const Breadcrumb(atMs: 1, event: BreadcrumbEvent.appStart));
      final snap = ring.snapshot();
      expect(
        () => snap.add(const Breadcrumb(atMs: 2, event: BreadcrumbEvent.navTo)),
        throwsUnsupportedError,
      );
    });
  });
}
