import 'dart:async';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/models/label_policy.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/core/theme/signet_theme.dart';
import 'package:signet/features/inspect/bulk_backup_import_screen.dart';
import 'package:signet/l10n/app_localizations.dart';

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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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

      await tester.tap(find.text('Restore it as "Mom (restored)"'));
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

  // Plan Task 1.6: per-record repairs and newer-version skips are visible.
  testWidgets('preview tells the user about repaired and skipped records',
      (tester) async {
    final decoded = BlkPackage(
      records: <BlkRelationshipRecord>[
        _record(seed: 1, label: 'Mom'),
        BlkRelationshipRecord(
          sharedSecret: Uint8List.fromList(List<int>.filled(32, 9)),
          role: PairRole.a,
          label: 'Dad',
          pairedAt: DateTime.utc(2026, 1, 1),
          silentHaptics: false,
          repaired: true,
        ),
      ],
      timestamp: DateTime.utc(2026, 4, 22),
      skippedNeedsNewerVersion: 2,
    );
    await tester.pumpWidget(_wrap(store: FakeSecureStore(), decoded: decoded));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 relationship in this backup had an '
        'unreadable'), findsOneWidget);
    expect(find.text('FIXED'), findsOneWidget,
        reason: 'the repaired row is marked, as the notice promises');
    expect(find.textContaining('2 relationships in this backup need a newer'),
        findsOneWidget);
  });

  testWidgets('a backup whose records all need a newer Signet shows only '
      'the update notice', (tester) async {
    final decoded = BlkPackage(
      records: const <BlkRelationshipRecord>[],
      timestamp: DateTime.utc(2026, 4, 22),
      skippedNeedsNewerVersion: 1,
    );
    await tester.pumpWidget(_wrap(store: FakeSecureStore(), decoded: decoded));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 relationship in this backup needs a newer'),
        findsOneWidget);
    expect(find.textContaining('Restore 0'), findsNothing);
  });

  group('restored names (plan Task 3.6)', () {
    testWidgets(
        'invisible characters are removed and an unusable name is replaced',
        (tester) async {
      final store = FakeSecureStore();
      final decoded = _blk(<BlkRelationshipRecord>[
        _record(seed: 1, label: '\u202EMom'),
        _record(seed: 2, label: '0123456789abcdef0123'),
      ]);
      await tester.pumpWidget(_wrap(store: store, decoded: decoded));
      await tester.pumpAndSettle();
      expect(find.text('Restored contact'), findsOneWidget);

      await tester.tap(find.text('RESTORE 2'));
      await tester.pumpAndSettle();
      final labels =
          (await store.listRelationships()).map((r) => r.label).toSet();
      expect(labels, <String>{'Mom', 'Restored contact'});
    });

    testWidgets('" (restored)" never pushes a name past the backup limit',
        (tester) async {
      final long = '\u5988' * 21; // 63 bytes
      final existing = Relationship(
        id: 'existing',
        label: long,
        pairedAt: DateTime.utc(2025, 1, 1),
        role: PairRole.a,
      );
      final store = FakeSecureStore(
          seeded: existing, secret: List<int>.generate(32, (_) => 0xAA));
      final decoded = _blk(<BlkRelationshipRecord>[
        _record(seed: 1, label: long),
      ]);
      await tester.pumpWidget(_wrap(store: store, decoded: decoded));
      await tester.pumpAndSettle();
      final rename = find.textContaining('(restored)');
      await tester.ensureVisible(rename);
      await tester.tap(rename);
      await tester.pumpAndSettle();
      await tester.tap(find.text('RESTORE 1'));
      await tester.pumpAndSettle();

      final restored = (await store.listRelationships())
          .firstWhere((r) => r.id != 'existing');
      expect(restored.label, endsWith(' (restored)'));
      expect(LabelPolicy.isValid(restored.label), isTrue,
          reason: 'fits the 64-byte limit, so it can be backed up again');
    });
  });

  testWidgets(
      'an existing contact saved with an invisible mark still counts as '
      'the same name (plan Task 3.6 review)', (tester) async {
    final existing = Relationship(
      id: 'existing-mom',
      label: 'Mom\u200E',
      pairedAt: DateTime.utc(2025, 1, 1),
      role: PairRole.a,
    );
    final store = FakeSecureStore(
        seeded: existing, secret: List<int>.generate(32, (_) => 0xAA));
    await tester.pumpWidget(_wrap(
        store: store, decoded: _blk(<BlkRelationshipRecord>[
      _record(seed: 1, label: 'Mom'),
    ])));
    await tester.pumpAndSettle();
    expect(find.text('ALREADY PAIRED'), findsOneWidget);
  });

  testWidgets(
      'when the name matches two existing contacts, Overwrite is not offered',
      (tester) async {
    final store = FakeSecureStore(
        seeded: Relationship(
          id: 'mom-1',
          label: 'Mom',
          pairedAt: DateTime.utc(2025, 1, 1),
          role: PairRole.a,
        ),
        secret: List<int>.generate(32, (_) => 0xAA));
    await store.saveRelationshipV2(
      Relationship(
        id: 'mom-2',
        label: 'Mom\u200B',
        pairedAt: DateTime.utc(2025, 1, 1),
        role: PairRole.a,
      ),
      sharedSecret: List<int>.generate(32, (_) => 0xBB),
    );
    await tester.pumpWidget(_wrap(
        store: store, decoded: _blk(<BlkRelationshipRecord>[
      _record(seed: 1, label: 'Mom'),
    ])));
    await tester.pumpAndSettle();
    expect(find.text('ALREADY PAIRED'), findsOneWidget);
    expect(find.textContaining('Restore it as'), findsOneWidget);
    expect(find.text('Overwrite existing pairing'), findsNothing);
  });

  group('robustness (plan Task 4.5)', () {
    testWidgets('while saving, close and back are blocked', (tester) async {
      final store = FakeSecureStore()..saveGate = Completer<void>();
      await tester.pumpWidget(_wrap(
          store: store,
          decoded: _blk(<BlkRelationshipRecord>[
            _record(seed: 1, label: 'Mom'),
          ])));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RESTORE 1'));
      await tester.pump();

      final close = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.close));
      expect(close.onPressed, isNull);
      final popScope = tester.widget<PopScope<dynamic>>(
          find.byWidgetPredicate((w) => w is PopScope));
      expect(popScope.canPop, isFalse);

      store.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close))
              .onPressed,
          isNotNull);
    });

    testWidgets('one record that cannot be saved does not stop the others, '
        'and the summary says so', (tester) async {
      final store = FakeSecureStore()..failSaveForLabel = 'Dad';
      await tester.pumpWidget(_wrap(
          store: store,
          decoded: _blk(<BlkRelationshipRecord>[
            _record(seed: 1, label: 'Mom'),
            _record(seed: 2, label: 'Dad'),
            _record(seed: 3, label: 'Kid'),
          ])));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RESTORE 3'));
      await tester.pumpAndSettle();
      expect((await store.listRelationships()).map((r) => r.label).toSet(),
          <String>{'Mom', 'Kid'});
      expect(find.textContaining('COULD NOT SAVE //', findRichText: true),
          findsOneWidget);
      expect(find.textContaining('Some contacts could not be saved'),
          findsOneWidget);
    });

    testWidgets('two records cannot both overwrite the same contact',
        (tester) async {
      final store = FakeSecureStore(
          seeded: Relationship(
            id: 'existing-mom',
            label: 'Mom',
            pairedAt: DateTime.utc(2025, 1, 1),
            role: PairRole.a,
          ),
          secret: List<int>.generate(32, (_) => 0xAA));
      await tester.pumpWidget(_wrap(
          store: store,
          decoded: _blk(<BlkRelationshipRecord>[
            _record(seed: 1, label: 'Mom'),
            _record(seed: 2, label: 'Mom'),
          ])));
      await tester.pumpAndSettle();
      expect(find.text('Overwrite existing pairing'), findsNWidgets(2));
      await tester.tap(find.text('Overwrite existing pairing').first);
      await tester.pumpAndSettle();
      expect(find.text('Overwrite existing pairing'), findsOneWidget,
          reason: 'only the record that claimed it still offers it');
    });
  });

  testWidgets('a save that reported an error but landed counts as restored',
      (tester) async {
    final store = FakeSecureStore()..failAfterSaveForLabel = 'Dad';
    await tester.pumpWidget(_wrap(
        store: store,
        decoded: _blk(<BlkRelationshipRecord>[
          _record(seed: 1, label: 'Mom'),
          _record(seed: 2, label: 'Dad'),
        ])));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RESTORE 2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('COULD NOT SAVE //', findRichText: true),
        findsNothing);
    expect(find.textContaining('RESTORED //', findRichText: true),
        findsOneWidget);
  });
}
