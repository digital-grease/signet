import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/core/theme/signet_theme.dart';
import 'package:signet/features/home/home_screen.dart';

import '../support/fake_secure_store.dart';

Widget _wrap({required FakeSecureStore store}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '/verify/:id',
        builder: (_, _) => const Scaffold(body: Text('VERIFY_ROUTE')),
      ),
      GoRoute(
        path: '/pair/start',
        builder: (_, _) => const Scaffold(body: Text('PAIR_START_ROUTE')),
      ),
      GoRoute(
        path: '/pair/exchange',
        builder: (_, _) => const Scaffold(body: Text('PAIR_EXCHANGE_ROUTE')),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const Scaffold(body: Text('ONBOARDING_ROUTE')),
      ),
      GoRoute(
        path: '/inspect/binding',
        builder: (_, _) => const Scaffold(body: Text('BINDING_ROUTE')),
      ),
      GoRoute(
        path: '/inspect/export/:id',
        builder: (_, state) =>
            Scaffold(body: Text('EXPORT_${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/liveness/:id',
        builder: (_, state) =>
            Scaffold(body: Text('LIVENESS_${state.pathParameters['id']}')),
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

Relationship _rel({
  required String id,
  required String label,
  PairRole role = PairRole.a,
  bool silentHaptics = false,
}) =>
    Relationship(
      id: id,
      label: label,
      pairedAt: DateTime.utc(2026, 4, 16),
      role: role,
      silentHaptics: silentHaptics,
    );

void main() {
  final mom = _rel(id: 'ab123cdef', label: 'Mom');
  final secret = List<int>.generate(32, (i) => i);

  group('HomeScreen — empty state', () {
    testWidgets('shows PAIR CONTACT primary and no relationships', (tester) async {
      await tester
          .pumpWidget(_wrap(store: FakeSecureStore()));
      await tester.pumpAndSettle();

      expect(find.text('Nothing paired yet.'), findsOneWidget);
      expect(find.text('PAIR CONTACT'), findsOneWidget);
      // The PAIR FAB is hidden in the empty state (the big primary button is
      // the entry point).
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('tapping PAIR CONTACT routes to /pair/start', (tester) async {
      await tester
          .pumpWidget(_wrap(store: FakeSecureStore()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('PAIR CONTACT'));
      await tester.pumpAndSettle();

      expect(find.text('PAIR_START_ROUTE'), findsOneWidget);
    });
  });

  group('HomeScreen — paired list', () {
    testWidgets('renders a row for each relationship', (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(seeded: mom, secret: secret),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Mom'), findsOneWidget);
      expect(find.text('RELATIONSHIPS //'), findsOneWidget);
      // Mono metadata line for the row.
      expect(find.textContaining('role:A'), findsOneWidget);
      // Chevron indicates tap-to-verify.
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('shows the OFFLINE-FREE chip and a PAIR FAB', (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(seeded: mom, secret: secret),
      ));
      await tester.pumpAndSettle();

      expect(find.text('OFFLINE-FREE'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      // FAB label is "PAIR".
      expect(find.widgetWithText(FloatingActionButton, 'PAIR'),
          findsOneWidget);
    });

    testWidgets('tapping the FAB opens a bottom-sheet pair menu', (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(seeded: mom, secret: secret),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Pair in person'), findsOneWidget);
      expect(find.text('Send a package'), findsOneWidget);
      expect(find.text('I have a package'), findsOneWidget);

      await tester.tap(find.text('Pair in person'));
      await tester.pumpAndSettle();
      expect(find.text('PAIR_START_ROUTE'), findsOneWidget);
    });

    testWidgets('tapping a row routes to /verify', (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(seeded: mom, secret: secret),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mom'));
      await tester.pumpAndSettle();

      expect(find.text('VERIFY_ROUTE'), findsOneWidget);
    });

    testWidgets(
      'long-press opens a bottom sheet menu with Rename / Haptics / Binding / Unpair',
      (tester) async {
        await tester.pumpWidget(_wrap(
          store: FakeSecureStore(seeded: mom, secret: secret),
        ));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Mom'));
        await tester.pumpAndSettle();

        expect(find.text('Rename Mom'), findsOneWidget);
        expect(find.text('Turn haptics off'), findsOneWidget);
        expect(find.text('Show binding phrase'), findsOneWidget);
        expect(find.text('Unpair from Mom'), findsOneWidget);
      },
    );

    testWidgets(
      'Unpair from menu → dialog → confirm deletes and shows UNDO',
      (tester) async {
        final store = FakeSecureStore(seeded: mom, secret: secret);
        await tester.pumpWidget(_wrap(store: store));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Mom'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Unpair from Mom'));
        await tester.pumpAndSettle();

        expect(find.text('Unpair from Mom?'), findsOneWidget);
        final dialogUnpair = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Unpair'),
        );
        await tester.tap(dialogUnpair);
        await tester.pumpAndSettle();

        expect(await store.hasRelationship(), isFalse);
        expect(find.text('UNDO'), findsOneWidget);
      },
    );

    testWidgets(
      'UNDO after unpair restores the relationship and re-renders the row',
      (tester) async {
        final store = FakeSecureStore(seeded: mom, secret: secret);
        await tester.pumpWidget(_wrap(store: store));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Mom'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Unpair from Mom'));
        await tester.pumpAndSettle();
        final dialogUnpair = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Unpair'),
        );
        await tester.tap(dialogUnpair);
        await tester.pumpAndSettle();
        await tester.tap(find.text('UNDO'));
        await tester.pumpAndSettle();

        expect(await store.hasRelationship(), isTrue);
        expect(find.text('Mom'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      },
    );

    testWidgets(
      'Rename from menu opens dialog and persists the new label',
      (tester) async {
        final store = FakeSecureStore(seeded: mom, secret: secret);
        await tester.pumpWidget(_wrap(store: store));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Mom'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rename Mom'));
        await tester.pumpAndSettle();

        expect(find.text('Rename peer'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Mother');
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();

        final stored = await store.getRelationship();
        expect(stored?.label, 'Mother');
        expect(find.text('Mother'), findsOneWidget);
      },
    );

    testWidgets(
      'Haptics toggle from menu flips silentHaptics on and shows badge',
      (tester) async {
        final store = FakeSecureStore(seeded: mom, secret: secret);
        await tester.pumpWidget(_wrap(store: store));
        await tester.pumpAndSettle();

        expect(find.text('HAPTICS // OFF'), findsNothing);

        await tester.longPress(find.text('Mom'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Turn haptics off'));
        await tester.pumpAndSettle();

        final stored = await store.getRelationship();
        expect(stored?.silentHaptics, isTrue);
        // Silent badge now appears on the row.
        expect(find.text('HAPTICS // OFF'), findsOneWidget);
      },
    );

    testWidgets(
      'Liveness challenge from menu routes to /liveness/:id',
      (tester) async {
        await tester.pumpWidget(_wrap(
          store: FakeSecureStore(seeded: mom, secret: secret),
        ));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Mom'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Liveness challenge'));
        await tester.pumpAndSettle();

        expect(find.text('LIVENESS_${mom.id}'), findsOneWidget);
      },
    );

    testWidgets(
      'Back up to paper from menu routes to /inspect/export/:id',
      (tester) async {
        await tester.pumpWidget(_wrap(
          store: FakeSecureStore(seeded: mom, secret: secret),
        ));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Mom'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Back up to paper'));
        await tester.pumpAndSettle();

        expect(find.text('EXPORT_${mom.id}'), findsOneWidget);
      },
    );

    testWidgets(
      'Rekey from menu seeds controller state and routes to /pair/exchange',
      (tester) async {
        await tester.pumpWidget(_wrap(
          store: FakeSecureStore(seeded: mom, secret: secret),
        ));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Mom'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rekey Mom'));
        await tester.pumpAndSettle();

        expect(find.text('PAIR_EXCHANGE_ROUTE'), findsOneWidget);
      },
    );

    testWidgets(
      'Show binding from menu routes to /inspect/binding',
      (tester) async {
        await tester.pumpWidget(_wrap(
          store: FakeSecureStore(seeded: mom, secret: secret),
        ));
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Mom'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Show binding phrase'));
        await tester.pumpAndSettle();

        expect(find.text('BINDING_ROUTE'), findsOneWidget);
      },
    );
  });

  group('HomeScreen — AppBar overflow', () {
    testWidgets('Show intro again routes to /onboarding', (tester) async {
      await tester.pumpWidget(_wrap(store: FakeSecureStore()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show intro again'));
      await tester.pumpAndSettle();

      expect(find.text('ONBOARDING_ROUTE'), findsOneWidget);
    });
  });
}
