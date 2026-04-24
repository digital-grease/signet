import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/backup_bundle.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/core/theme/signet_theme.dart';
import 'package:signet/features/inspect/bulk_backup_export_screen.dart';

import '../support/fake_secure_store.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Future<FakeSecureStore> _storeWith(List<_Pair> pairs) async {
  final store = FakeSecureStore();
  for (final p in pairs) {
    await store.saveRelationshipV2(p.relationship, sharedSecret: p.secret);
  }
  return store;
}

class _Pair {
  _Pair(this.relationship, this.secret);
  final Relationship relationship;
  final List<int> secret;
}

_Pair _pair({
  required String id,
  required String label,
  PairRole role = PairRole.a,
  int secretSeed = 0,
  DateTime? pairedAt,
}) {
  return _Pair(
    Relationship(
      id: id,
      label: label,
      pairedAt: pairedAt ?? DateTime.utc(2026, 1, 1),
      role: role,
    ),
    List<int>.generate(32, (i) => (i + secretSeed) & 0xFF),
  );
}

Widget _wrap({required FakeSecureStore store}) {
  final router = GoRouter(
    initialLocation: '/inspect/export-bulk',
    routes: <RouteBase>[
      GoRoute(
        path: '/inspect/export-bulk',
        builder: (_, _) => const BulkBackupExportScreen(),
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
    'three relationships — preview shows counts + labels; Generate produces a valid BLK bundle',
    (tester) async {
      final store = await _storeWith(<_Pair>[
        _pair(id: 'id-mom', label: 'Mom', secretSeed: 1),
        _pair(id: 'id-dad', label: 'Dad', secretSeed: 2, role: PairRole.b),
        _pair(id: 'id-jake', label: 'Jake', secretSeed: 3),
      ]);

      await tester.pumpWidget(_wrap(store: store));
      await tester.pumpAndSettle();

      expect(find.text('Back up 3 relationships'), findsOneWidget);
      expect(find.text('Mom'), findsOneWidget);
      expect(find.text('Dad'), findsOneWidget);
      expect(find.text('Jake'), findsOneWidget);

      await tester.tap(find.text('GENERATE BULK BACKUP'));
      await tester.pumpAndSettle();

      expect(find.text('3 relationships backed up'), findsOneWidget);

      // Extract the wire from the SelectableText that starts with signet:tp1:.
      final selectables =
          tester.widgetList<SelectableText>(find.byType(SelectableText));
      final wire = selectables.firstWhere(
        (s) => (s.data ?? '').startsWith('signet:tp1:'),
      );
      expect(wire.data, isNotNull);

      // Extract the 8 PAKE words — rendered as Text at 16sp monospace.
      final monoTexts = tester.widgetList<Text>(find.byType(Text)).where((t) {
        return t.style?.fontFamily == 'monospace' && t.style?.fontSize == 16;
      }).toList();
      expect(monoTexts.length >= 8, isTrue,
          reason: '8 PAKE words must be visible');
      final pakeWords =
          monoTexts.take(8).map((t) => t.data!).toList(growable: false);

      // The wire + PAKE pair round-trips via the same BackupBundle wrapper
      // used by single-relationship exports, and decodes via decodeBlk
      // to yield all three records with correct labels + secrets + roles.
      final formattedBundle = BackupBundle.format(
        peerLabel: '3 relationships (bulk)',
        wire: wire.data!,
        pakeWords: pakeWords,
        generatedAt: DateTime.now(),
      );
      final parsed = BackupBundle.parse(formattedBundle);
      final decoded = await TransportPackage.decodeBlk(
        parsed.wire,
        pakeWords: parsed.pakeWords,
      );
      expect(decoded.records, hasLength(3));
      final decodedLabels = decoded.records.map((r) => r.label).toSet();
      expect(decodedLabels, {'Mom', 'Dad', 'Jake'});
      final dadRecord =
          decoded.records.firstWhere((r) => r.label == 'Dad');
      expect(dadRecord.role, PairRole.b);
      expect(dadRecord.sharedSecret,
          List<int>.generate(32, (i) => (i + 2) & 0xFF));
    },
  );

  testWidgets(
    'empty store — no Generate button, empty-state message surfaces',
    (tester) async {
      final store = FakeSecureStore();

      await tester.pumpWidget(_wrap(store: store));
      await tester.pumpAndSettle();

      expect(find.text('Nothing to back up yet.'), findsOneWidget);
      expect(find.text('GENERATE BULK BACKUP'), findsNothing);
    },
  );

  testWidgets(
    'single relationship — label reads "1 relationship" (singular), still generates',
    (tester) async {
      final store = await _storeWith(<_Pair>[
        _pair(id: 'id-mom', label: 'Mom', secretSeed: 1),
      ]);

      await tester.pumpWidget(_wrap(store: store));
      await tester.pumpAndSettle();

      expect(find.text('Back up 1 relationship'), findsOneWidget);

      await tester.tap(find.text('GENERATE BULK BACKUP'));
      await tester.pumpAndSettle();

      expect(find.text('1 relationship backed up'), findsOneWidget);
    },
  );
}
