// The NOT VERIFIED help sheet's step 04 points at a button that is
// actually there (plan Task 5.4): it opens this contact's binding phrase.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/features/verify/verify_screen.dart';
import 'package:signet/l10n/app_localizations.dart';

import '../support/fake_secure_store.dart';

void main() {
  testWidgets('the help sheet opens the binding phrase for this contact',
      (tester) async {
    final mom = Relationship(
      id: 'mom1',
      label: 'Mom',
      pairedAt: DateTime.utc(2026, 1, 1),
      role: PairRole.a,
    );
    final router = GoRouter(
      initialLocation: '/verify/mom1',
      routes: <RouteBase>[
        GoRoute(
          path: '/verify/:id',
          builder: (_, state) => VerifyScreen(
            relationshipId: state.pathParameters['id']!,
            unixTimeSecondsProvider: () => 1735776000,
          ),
        ),
        GoRoute(
          path: '/inspect/binding/:id',
          builder: (_, state) =>
              Scaffold(body: Text('BINDING_${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        secureStoreProvider.overrideWithValue(
            FakeSecureStore(seeded: mom, secret: List<int>.filled(32, 7))),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
    for (final (i, w) in <String>['abandon', 'ability', 'able', 'about'].indexed) {
      await tester.enterText(find.byType(TextField).at(i), w);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('WHAT SHOULD I DO?'));
    await tester.tap(find.text('WHAT SHOULD I DO?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tap "Check the binding phrase" below'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Check the binding phrase'));
    await tester.tap(find.text('Check the binding phrase'));
    await tester.pumpAndSettle();
    expect(find.text('BINDING_mom1'), findsOneWidget);
  });
}
