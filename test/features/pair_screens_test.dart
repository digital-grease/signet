import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/features/pairing/pair_confirm_screen.dart';
import 'package:signet/features/pairing/pair_start_screen.dart';
import 'package:signet/features/pairing/pairing_controller.dart';

import '../support/fake_secure_store.dart';

/// Minimal `go_router` harness so screens using `context.go(...)` don't crash.
/// Any path that's navigated to lands on a placeholder whose text appears in
/// the widget tree, letting us assert navigation occurred.
GoRouter _routerFor({
  required String initialLocation,
  required Widget Function(BuildContext) screen,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => const _NavTarget('HOME')),
      GoRoute(
        path: '/pair/start',
        builder: (context, _) => screen(context),
      ),
      GoRoute(
        path: '/pair/exchange',
        builder: (_, _) => const _NavTarget('EXCHANGE'),
      ),
      GoRoute(
        path: '/pair/confirm',
        builder: (context, _) => screen(context),
      ),
    ],
  );
}

class _NavTarget extends StatelessWidget {
  const _NavTarget(this.label);
  final String label;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

Widget _wrap({
  required Widget Function(BuildContext) screenBuilder,
  required String initialLocation,
  FakeSecureStore? store,
}) {
  final router = _routerFor(
    initialLocation: initialLocation,
    screen: screenBuilder,
  );
  return ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(store ?? FakeSecureStore()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('PairStartScreen', () {
    testWidgets('empty label shows inline error and does not navigate',
        (tester) async {
      await tester.pumpWidget(_wrap(
        initialLocation: '/pair/start',
        screenBuilder: (_) => const PairStartScreen(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a name for this contact.'), findsOneWidget);
      expect(find.text('EXCHANGE'), findsNothing);
    });

    testWidgets('valid label stores and navigates to exchange', (tester) async {
      await tester.pumpWidget(_wrap(
        initialLocation: '/pair/start',
        screenBuilder: (_) => const PairStartScreen(),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Mom');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('EXCHANGE'), findsOneWidget);
    });
  });

  group('PairConfirmScreen', () {
    testWidgets('renders the 4-word phrase and both action buttons',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Pre-drive the pairing flow to a ready-to-confirm state.
      final ctrl = container.read(pairingControllerProvider.notifier);
      ctrl.setLabel('Mom');
      await ctrl.ensureOurKeyPair();
      await ctrl.recordTheirPublicKey(Uint8List.fromList(List.filled(32, 7)));
      final phrase = container.read(pairingControllerProvider).phrase!;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: _routerFor(
              initialLocation: '/pair/confirm',
              screen: (_) => const PairConfirmScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final word in phrase) {
        expect(find.text(word), findsOneWidget);
      }
      expect(find.text('It matches'), findsOneWidget);
      expect(find.text('No match — start over'), findsOneWidget);
    });

    testWidgets('match commits to storage and returns home', (tester) async {
      final store = FakeSecureStore();
      final container = ProviderContainer(overrides: [
        secureStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);
      final ctrl = container.read(pairingControllerProvider.notifier);
      ctrl.setLabel('Mom');
      await ctrl.ensureOurKeyPair();
      await ctrl.recordTheirPublicKey(Uint8List.fromList(List.filled(32, 2)));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: _routerFor(
              initialLocation: '/pair/confirm',
              screen: (_) => const PairConfirmScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Snapshot the two public keys before commit so we can compute the
      // expected role independently.
      final preCommitState = container.read(pairingControllerProvider);
      final ourPub = preCommitState.ourKeyPair!.publicKey;
      final theirPub = preCommitState.theirPublicKey!;
      final expectedRole = PairRole.assign(
        ourPublicKey: ourPub,
        theirPublicKey: theirPub,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'It matches'));
      await tester.pumpAndSettle();

      expect(await store.hasRelationship(), isTrue);
      final saved = await store.getRelationship();
      expect(saved!.label, 'Mom');
      expect(
        saved.role,
        expectedRole,
        reason:
            'commit must store the role derived from lexicographic compare '
            'of the two X25519 public keys (reflection-attack defense)',
      );
      expect(find.text('HOME'), findsOneWidget);
      // Controller should be reset for the next pairing.
      expect(container.read(pairingControllerProvider).label, isNull);
    });
  });
}
