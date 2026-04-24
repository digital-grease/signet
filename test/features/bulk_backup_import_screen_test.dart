import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/core/theme/signet_theme.dart';
import 'package:signet/features/inspect/bulk_backup_import_screen.dart';

import '../support/fake_secure_store.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

BlkRelationshipRecord _record({
  required int seed,
  required String label,
  PairRole role = PairRole.a,
  bool silentHaptics = false,
  DateTime? pairedAt,
}) =>
    BlkRelationshipRecord(
      sharedSecret:
          Uint8List.fromList(List<int>.generate(32, (i) => (i + seed) & 0xFF)),
      role: role,
      label: label,
      pairedAt: pairedAt ?? DateTime.utc(2026, 1, 1),
      silentHaptics: silentHaptics,
    );

BlkPackage _blk(List<BlkRelationshipRecord> records) =>
    BlkPackage(records: records, timestamp: DateTime.utc(2026, 4, 22));

Widget _wrap({required FakeSecureStore store, required BlkPackage decoded}) {
  final router = GoRouter(
    initialLocation: '/inspect/import-bulk',
    routes: <RouteBase>[
      GoRoute(
        path: '/inspect/import-bulk',
        builder: (_, _) => BulkBackupImportScreen(decoded: decoded),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [secureStoreProvider.overrideWithValue(store)],
    child: MaterialApp.router(
      theme: signetTheme(dark: false),
      darkTheme: signetTheme(dark: true),
      routerConfig: router,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets(
    'three records, no collisions — default all selected, RESTORE 3 commits 3 fresh entries',
    (tester) async {
      final store = FakeSecureStore();
      final decoded = _blk(<BlkRelationshipRecord>[
        _record(seed: 1, label: 'Mom'),
        _record(seed: 2, label: 'Dad'),
        _record(seed: 3, label: 'Jake'),
      ]);

      await tester.pumpWidget(_wrap(store: store, decoded: decoded));
      await tester.pumpAndSettle();

      // All three labels rendered, button reads "RESTORE 3".
      expect(find.text('Mom'), findsOneWidget);
      expect(find.text('Dad'), findsOneWidget);
      expect(find.text('Jake'), findsOneWidget);
      expect(find.text('RESTORE 3'), findsOneWidget);

      await tester.ensureVisible(find.text('RESTORE 3'));
      await tester.tap(find.text('RESTORE 3'));
      await tester.pumpAndSettle();

      expect(find.text('Restore complete.'), findsOneWidget);
      // Three entries committed, none renamed/overwritten/skipped.
      final relationships = await store.listRelationships();
      expect(relationships, hasLength(3));
      final labels = relationships.map((r) => r.label).toSet();
      expect(labels, {'Mom', 'Dad', 'Jake'});
    },
  );

  testWidgets(
    'unchecking two records drops them — RESTORE 1 commits only the one',
    (tester) async {
      final store = FakeSecureStore();
      final decoded = _blk(<BlkRelationshipRecord>[
        _record(seed: 1, label: 'Mom'),
        _record(seed: 2, label: 'Dad'),
        _record(seed: 3, label: 'Jake'),
      ]);

      await tester.pumpWidget(_wrap(store: store, decoded: decoded));
      await tester.pumpAndSettle();

      // Uncheck the first two non-conflict rows.
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(3));
      await tester.tap(checkboxes.at(0));
      await tester.pumpAndSettle();
      await tester.tap(checkboxes.at(1));
      await tester.pumpAndSettle();

      expect(find.text('RESTORE 1'), findsOneWidget);
      await tester.tap(find.text('RESTORE 1'));
      await tester.pumpAndSettle();

      final relationships = await store.listRelationships();
      expect(relationships, hasLength(1));
      expect(relationships.single.label, 'Jake');
    },
  );

  testWidgets(
    'collision — default Skip leaves the existing pairing intact',
    (tester) async {
      // Pre-seed store with an existing "Mom" (different secret) so
      // the conflict branch fires on the first record.
      final existingSecret = List<int>.generate(32, (_) => 0xAA);
      final existing = Relationship(
        id: 'existing-mom',
        label: 'Mom',
        pairedAt: DateTime.utc(2025, 1, 1),
        role: PairRole.a,
      );
      final store = FakeSecureStore(
        seeded: existing,
        secret: existingSecret,
      );
      final decoded = _blk(<BlkRelationshipRecord>[
        _record(seed: 1, label: 'Mom'), // conflicts
        _record(seed: 2, label: 'Dad'),
      ]);

      await tester.pumpWidget(_wrap(store: store, decoded: decoded));
      await tester.pumpAndSettle();

      // Collision badge rendered.
      expect(find.text('ALREADY PAIRED'), findsOneWidget);
      // Default: Skip chosen → only Dad selected → RESTORE 1.
      expect(find.text('RESTORE 1'), findsOneWidget);

      await tester.tap(find.text('RESTORE 1'));
      await tester.pumpAndSettle();

      final relationships = await store.listRelationships();
      // Existing Mom untouched; Dad newly created.
      expect(relationships, hasLength(2));
      final momMatches = relationships.where((r) => r.label == 'Mom').toList();
      expect(momMatches, hasLength(1));
      expect(momMatches.single.id, 'existing-mom');
      final momSecret = await store.getSharedSecretById('existing-mom');
      expect(momSecret, Uint8List.fromList(existingSecret));
      expect(relationships.where((r) => r.label == 'Dad'), hasLength(1));
    },
  );

  testWidgets(
    'collision — Rename creates a " (restored)" copy alongside the original',
    (tester) async {
      final existingSecret = List<int>.generate(32, (_) => 0xAA);
      final existing = Relationship(
        id: 'existing-mom',
        label: 'Mom',
        pairedAt: DateTime.utc(2025, 1, 1),
        role: PairRole.a,
      );
      final store = FakeSecureStore(
        seeded: existing,
        secret: existingSecret,
      );
      final decoded = _blk(<BlkRelationshipRecord>[
        _record(seed: 1, label: 'Mom'),
      ]);

      await tester.pumpWidget(_wrap(store: store, decoded: decoded));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Rename restored copy'));
      await tester.pumpAndSettle();

      expect(find.text('RESTORE 1'), findsOneWidget);
      await tester.tap(find.text('RESTORE 1'));
      await tester.pumpAndSettle();

      final relationships = await store.listRelationships();
      expect(relationships, hasLength(2));
      final labels = relationships.map((r) => r.label).toSet();
      expect(labels, {'Mom', 'Mom (restored)'});
      // Existing Mom's secret is NOT overwritten.
      final origMom = await store.getSharedSecretById('existing-mom');
      expect(origMom, Uint8List.fromList(existingSecret));
    },
  );

  testWidgets(
    'collision — Overwrite replaces secret + role on the existing relationship',
    (tester) async {
      final existingSecret = List<int>.generate(32, (_) => 0xAA);
      final existing = Relationship(
        id: 'existing-mom',
        label: 'Mom',
        pairedAt: DateTime.utc(2025, 1, 1),
        role: PairRole.a,
      );
      final store = FakeSecureStore(
        seeded: existing,
        secret: existingSecret,
      );
      final record = _record(
        seed: 1,
        label: 'Mom',
        role: PairRole.b,
        silentHaptics: true,
      );
      final decoded = _blk(<BlkRelationshipRecord>[record]);

      await tester.pumpWidget(_wrap(store: store, decoded: decoded));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Overwrite existing pairing'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('RESTORE 1'));
      await tester.pumpAndSettle();

      final relationships = await store.listRelationships();
      // Id preserved → still exactly one Mom, and still 'existing-mom'.
      expect(relationships, hasLength(1));
      final mom = relationships.single;
      expect(mom.id, 'existing-mom');
      expect(mom.label, 'Mom');
      expect(mom.role, PairRole.b, reason: 'role replaced from record');
      expect(mom.silentHaptics, isTrue, reason: 'haptics replaced from record');
      final newSecret = await store.getSharedSecretById('existing-mom');
      expect(newSecret, record.sharedSecret,
          reason: 'shared secret replaced from record');
    },
  );

  testWidgets(
    'nothing selected — RESTORE button is disabled',
    (tester) async {
      final store = FakeSecureStore();
      final decoded = _blk(<BlkRelationshipRecord>[
        _record(seed: 1, label: 'Mom'),
      ]);

      await tester.pumpWidget(_wrap(store: store, decoded: decoded));
      await tester.pumpAndSettle();

      // Uncheck the one row.
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Button text flips + disables.
      expect(find.text('NOTHING SELECTED'), findsOneWidget);
      final filled = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(filled.onPressed, isNull);
    },
  );
}
