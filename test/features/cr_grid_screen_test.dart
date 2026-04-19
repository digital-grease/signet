import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/challenge_response_grid.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/core/theme/signet_theme.dart';
import 'package:signet/features/inspect/cr_grid_screen.dart';

import '../support/fake_secure_store.dart';

final _mom = Relationship(
  id: 'abc123',
  label: 'Mom',
  pairedAt: DateTime.utc(2026, 2, 14),
  role: PairRole.a,
);
final _secret = List<int>.generate(32, (i) => i + 1);

Widget _wrap({required FakeSecureStore store, required String id}) {
  final router = GoRouter(
    initialLocation: '/inspect/cr-grid/$id',
    routes: <RouteBase>[
      GoRoute(
        path: '/inspect/cr-grid/:id',
        builder: (_, state) => CrGridScreen(
          relationshipId: state.pathParameters['id']!,
        ),
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

void main() {
  testWidgets(
    'renders the header, warning, grid section, and airplane ribbon',
    (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(seeded: _mom, secret: _secret),
        id: _mom.id,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Grid for Mom'), findsOneWidget);
      expect(find.text('GRID // 8×8 //'), findsOneWidget);
      expect(find.textContaining('FALLBACK'), findsOneWidget);
      expect(
        find.text('AIRPLANE // NO NETWORK · NO TELEMETRY · STRONGBOX'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'renders all 8 row labels and all 8 col labels from the derived grid',
    (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(seeded: _mom, secret: _secret),
        id: _mom.id,
      ));
      await tester.pumpAndSettle();

      final grid = await ChallengeResponseGrid.derive(_secret);
      // Each label should appear at least once on screen. The row
      // labels go on the leading column; col labels on the header
      // row. Horizontal scrolling keeps them laid out; we rely on
      // find.text's ability to see off-screen-but-in-tree widgets.
      for (final row in grid.rowLabels) {
        expect(find.text(row), findsWidgets);
      }
      for (final col in grid.colLabels) {
        expect(find.text(col), findsWidgets);
      }
    },
  );

  testWidgets(
    'tapping a cell opens a dialog with the 3-word answer in big type',
    (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(seeded: _mom, secret: _secret),
        id: _mom.id,
      ));
      await tester.pumpAndSettle();

      final grid = await ChallengeResponseGrid.derive(_secret);
      final cell = grid.cells[0][0];

      // The first cell's first word should be tappable from the table
      // (horizontally scrolled or not). Use text lookup to find the
      // cell's first word — this hits the body of cell [0][0].
      await tester.ensureVisible(find.text(cell[0]).first);
      await tester.tap(find.text(cell[0]).first);
      await tester.pumpAndSettle();

      // Dialog title is "{rowLabel} × {colLabel}".
      expect(
        find.text('${grid.rowLabels[0]} × ${grid.colLabels[0]}'),
        findsOneWidget,
      );
      // All 3 words appear in the dialog body.
      for (final word in cell) {
        expect(find.text(word), findsWidgets);
      }
      expect(find.text('CLOSE'), findsOneWidget);

      // Dismiss.
      await tester.tap(find.text('CLOSE'));
      await tester.pumpAndSettle();
      expect(
        find.text('${grid.rowLabels[0]} × ${grid.colLabels[0]}'),
        findsNothing,
      );
    },
  );

  testWidgets('Print grid button is present in the AppBar',
      (tester) async {
    await tester.pumpWidget(_wrap(
      store: FakeSecureStore(seeded: _mom, secret: _secret),
      id: _mom.id,
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.print_outlined), findsOneWidget);
    final printButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.print_outlined),
        matching: find.byType(IconButton),
      ),
    );
    expect(printButton.onPressed, isNotNull,
        reason: 'print action is enabled once grid loads');
  });

  testWidgets(
    'Print button is disabled while the grid is still loading',
    (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(),
        id: 'no-such-id',
      ));
      await tester.pump(); // one frame, still loading / error path

      final printButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.print_outlined),
          matching: find.byType(IconButton),
        ),
      );
      expect(printButton.onPressed, isNull);
    },
  );

  testWidgets('unknown relationship id surfaces the error state',
      (tester) async {
    await tester.pumpWidget(_wrap(
      store: FakeSecureStore(),
      id: 'no-such-id',
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load grid'), findsOneWidget);
  });
}
