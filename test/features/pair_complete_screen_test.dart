import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/core/theme/signet_theme.dart';
import 'package:signet/features/pairing/pair_complete_screen.dart';
import 'package:signet/l10n/app_localizations.dart';

import '../support/fake_secure_store.dart';

final _mom = Relationship(
  id: 'abc123',
  label: 'Mom',
  pairedAt: DateTime.utc(2026, 4, 16),
  role: PairRole.a,
);

Widget _wrap({
  required FakeSecureStore store,
  PairDistance distance = PairDistance.together,
}) {
  final router = GoRouter(
    initialLocation: '/pair/complete',
    routes: <RouteBase>[
      GoRoute(
        path: '/pair/complete',
        builder: (_, _) =>
            PairCompleteScreen(relationshipId: 'abc123', distance: distance),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/verify/:id',
        builder: (_, _) => const Scaffold(body: Text('VERIFY_ROUTE')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(store),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: signetTheme(dark: false),
      darkTheme: signetTheme(dark: true),
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets(
    'renders the pair-complete nudge with label-customized VERIFY button',
    (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(
          seeded: _mom,
          secret: List<int>.generate(32, (i) => i),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('PAIR COMMITTED //'), findsOneWidget);
      expect(find.text("You're both still here.\nTry a verify now."),
          findsOneWidget);
      expect(find.text('VERIFY MOM NOW'), findsOneWidget);
      expect(find.text('SKIP — DO IT LATER'), findsOneWidget);
    },
  );

  testWidgets(
    'VERIFY NOW routes to /verify',
    (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(
          seeded: _mom,
          secret: List<int>.generate(32, (i) => i),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('VERIFY MOM NOW'));
      await tester.pumpAndSettle();

      expect(find.text('VERIFY_ROUTE'), findsOneWidget);
    },
  );

  testWidgets(
    'SKIP routes to /',
    (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(
          seeded: _mom,
          secret: List<int>.generate(32, (i) => i),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SKIP — DO IT LATER'));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    },
  );

  group('after a long-distance pairing', () {
    FakeSecureStore store() => FakeSecureStore(
          seeded: _mom,
          secret: List<int>.generate(32, (i) => i),
        );

    testWidgets('the sender is not told the two are together',
        (tester) async {
      await tester.pumpWidget(
          _wrap(store: store(), distance: PairDistance.sent));
      await tester.pumpAndSettle();
      expect(find.textContaining("You're both still here"), findsNothing);
      expect(find.textContaining('Paired at a distance'), findsOneWidget);
      expect(find.textContaining('Next time you talk with Mom'),
          findsOneWidget);
      expect(find.textContaining('pasted your response'), findsNothing);
    });

    testWidgets('the receiver learns verify waits for the response',
        (tester) async {
      await tester.pumpWidget(
          _wrap(store: store(), distance: PairDistance.received));
      await tester.pumpAndSettle();
      expect(find.textContaining('Paired at a distance'), findsOneWidget);
      expect(
          find.text('Verify works once Mom has pasted your response package.'),
          findsOneWidget);
    });
  });
}
