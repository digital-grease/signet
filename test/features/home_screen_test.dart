import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/features/home/home_screen.dart';

import '../support/fake_secure_store.dart';

Widget _wrap({
  required Widget child,
  required FakeSecureStore store,
}) {
  return ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(store),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('HomeScreen — empty state', () {
    testWidgets('shows "Pair a contact" primary action', (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(),
        child: const HomeScreen(),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text("You haven't paired with anyone yet."),
        findsOneWidget,
      );
      expect(find.text('Pair a contact'), findsOneWidget);
    });

    testWidgets('does not show "Verify" or "Unpair"', (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(),
        child: const HomeScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Verify '), findsNothing);
      expect(find.text('Unpair'), findsNothing);
    });
  });

  group('HomeScreen — paired state', () {
    final mom = Relationship(
      id: 'abc',
      label: 'Mom',
      pairedAt: DateTime.utc(2026, 4, 16),
    );

    testWidgets('shows "Verify Mom" primary and "Unpair" secondary', (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(
          seeded: mom,
          secret: List<int>.generate(32, (i) => i),
        ),
        child: const HomeScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Mom'), findsOneWidget);
      expect(find.text('Verify Mom'), findsOneWidget);
      expect(find.text('Unpair'), findsOneWidget);
    });

    testWidgets('tapping "Unpair" opens a confirmation dialog', (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(
          seeded: mom,
          secret: List<int>.generate(32, (i) => i),
        ),
        child: const HomeScreen(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unpair'));
      await tester.pumpAndSettle();

      expect(find.text('Unpair from Mom?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('confirming unpair clears storage and re-renders empty state', (tester) async {
      final store = FakeSecureStore(
        seeded: mom,
        secret: List<int>.generate(32, (i) => i),
      );
      await tester.pumpWidget(_wrap(store: store, child: const HomeScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unpair'));
      await tester.pumpAndSettle();

      // The destructive "Unpair" button is in the dialog, alongside "Cancel".
      final dialogUnpair = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Unpair'),
      );
      await tester.tap(dialogUnpair);
      await tester.pumpAndSettle();

      expect(await store.hasRelationship(), isFalse);
      expect(
        find.text("You haven't paired with anyone yet."),
        findsOneWidget,
      );
    });

    testWidgets('cancelling unpair leaves storage alone', (tester) async {
      final store = FakeSecureStore(
        seeded: mom,
        secret: List<int>.generate(32, (i) => i),
      );
      await tester.pumpWidget(_wrap(store: store, child: const HomeScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unpair'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await store.hasRelationship(), isTrue);
      expect(find.text('Verify Mom'), findsOneWidget);
    });
  });
}
