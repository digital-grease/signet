import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/core/theme/signet_theme.dart';
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
    // Pump under the real Signet theme — HomeScreen depends on theme
    // (uppercase button letter-spacing comes from here) and the dialog's
    // scheme-derived error colors are inherited too.
    child: MaterialApp(
      theme: signetTheme(dark: false),
      darkTheme: signetTheme(dark: true),
      home: child,
    ),
  );
}

void main() {
  group('HomeScreen — empty state', () {
    testWidgets('shows "PAIR CONTACT" primary action', (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(),
        child: const HomeScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Nothing paired yet.'), findsOneWidget);
      expect(find.text('PAIR CONTACT'), findsOneWidget);
    });

    testWidgets('does not show "VERIFY" or "UNPAIR"', (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(),
        child: const HomeScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('VERIFY '), findsNothing);
      expect(find.text('UNPAIR'), findsNothing);
    });
  });

  group('HomeScreen — paired state', () {
    final mom = Relationship(
      id: 'abc',
      label: 'Mom',
      pairedAt: DateTime.utc(2026, 4, 16),
      role: PairRole.a,
    );

    testWidgets('shows the peer label, VERIFY and UNPAIR actions',
        (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(
          seeded: mom,
          secret: List<int>.generate(32, (i) => i),
        ),
        child: const HomeScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Mom'), findsOneWidget);
      expect(find.text('VERIFY MOM'), findsOneWidget);
      expect(find.text('UNPAIR'), findsOneWidget);
    });

    testWidgets('tapping UNPAIR opens a confirmation dialog', (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(
          seeded: mom,
          secret: List<int>.generate(32, (i) => i),
        ),
        child: const HomeScreen(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('UNPAIR'));
      await tester.pumpAndSettle();

      expect(find.text('Unpair from Mom?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('confirming unpair clears storage and re-renders empty state',
        (tester) async {
      final store = FakeSecureStore(
        seeded: mom,
        secret: List<int>.generate(32, (i) => i),
      );
      await tester.pumpWidget(_wrap(store: store, child: const HomeScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('UNPAIR'));
      await tester.pumpAndSettle();

      // The destructive "Unpair" button is in the dialog, alongside "Cancel".
      // The dialog's button text is mixed-case "Unpair" (standard Material
      // AlertDialog convention) while the home screen's button is "UNPAIR"
      // (operator style) — intentional, per Task 9.2.
      final dialogUnpair = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Unpair'),
      );
      await tester.tap(dialogUnpair);
      await tester.pumpAndSettle();

      expect(await store.hasRelationship(), isFalse);
      expect(find.text('Nothing paired yet.'), findsOneWidget);
    });

    testWidgets('cancelling unpair leaves storage alone', (tester) async {
      final store = FakeSecureStore(
        seeded: mom,
        secret: List<int>.generate(32, (i) => i),
      );
      await tester.pumpWidget(_wrap(store: store, child: const HomeScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('UNPAIR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await store.hasRelationship(), isTrue);
      expect(find.text('VERIFY MOM'), findsOneWidget);
    });

    testWidgets('shows the monospace metadata block (fingerprint, bound, cipher)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(
          seeded: mom,
          secret: List<int>.generate(32, (i) => i),
        ),
        child: const HomeScreen(),
      ));
      await tester.pumpAndSettle();

      // PEER section header
      expect(find.text('PEER //'), findsOneWidget);

      // RichText-based KV rows aren't findable with find.text() directly, so
      // we look for the rendered strings inside RichText widgets via a
      // predicate that recursively inspects the `text.toPlainText()`.
      expect(_findRichContaining('FINGERPRINT //'), findsOneWidget);
      expect(_findRichContaining('BOUND //'), findsOneWidget);
      expect(_findRichContaining('CIPHER //'), findsOneWidget);
      // Role-derived fingerprint prefix (id='abc' → "AB" pad-shown).
      expect(_findRichContaining('role:A'), findsOneWidget);
    });

    testWidgets('shows the OFFLINE-FREE status chip', (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(
          seeded: mom,
          secret: List<int>.generate(32, (i) => i),
        ),
        child: const HomeScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('OFFLINE-FREE'), findsOneWidget);
    });
  });
}

Finder _findRichContaining(String needle) {
  return find.byWidgetPredicate((w) {
    if (w is! RichText) return false;
    return w.text.toPlainText().contains(needle);
  });
}
