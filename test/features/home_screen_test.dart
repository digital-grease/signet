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

    testWidgets(
      'tapping UNDO within the snackbar window restores the relationship',
      (tester) async {
        final store = FakeSecureStore(
          seeded: mom,
          secret: List<int>.generate(32, (i) => i),
        );
        await tester
            .pumpWidget(_wrap(store: store, child: const HomeScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('UNPAIR'));
        await tester.pumpAndSettle();
        final dialogUnpair = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Unpair'),
        );
        await tester.tap(dialogUnpair);
        await tester.pumpAndSettle();

        expect(await store.hasRelationship(), isFalse);
        expect(find.text('UNDO'), findsOneWidget);

        await tester.tap(find.text('UNDO'));
        await tester.pumpAndSettle();

        expect(await store.hasRelationship(), isTrue);
        final restored = await store.getRelationship();
        expect(restored?.id, mom.id);
        expect(restored?.label, mom.label);
        final secret = await store.getSharedSecret();
        expect(secret, isNotNull);
        expect(secret!.length, 32);
        // Home re-renders the paired state.
        expect(find.text('VERIFY MOM'), findsOneWidget);
      },
    );

    testWidgets(
      'letting the undo snackbar expire leaves the relationship deleted',
      (tester) async {
        final store = FakeSecureStore(
          seeded: mom,
          secret: List<int>.generate(32, (i) => i),
        );
        await tester
            .pumpWidget(_wrap(store: store, child: const HomeScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('UNPAIR'));
        await tester.pumpAndSettle();
        final dialogUnpair = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Unpair'),
        );
        await tester.tap(dialogUnpair);
        await tester.pumpAndSettle();

        expect(await store.hasRelationship(), isFalse);
        expect(find.text('UNDO'), findsOneWidget);

        // The SnackBar's 5-second duration uses a real Timer; advance
        // the fake clock past it and let the dismiss animation settle.
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle(const Duration(seconds: 1));

        expect(await store.hasRelationship(), isFalse);
        // The home screen is back in the empty state even if the
        // SnackBar dismiss animation is mid-frame. The store-state
        // assertion above is the load-bearing check here — the UI
        // assertion is a belt-and-braces sanity test.
        expect(find.text('Nothing paired yet.'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the peer label opens a rename dialog that saves new label',
      (tester) async {
        final store = FakeSecureStore(
          seeded: mom,
          secret: List<int>.generate(32, (i) => i),
        );
        await tester
            .pumpWidget(_wrap(store: store, child: const HomeScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Mom'));
        await tester.pumpAndSettle();

        expect(find.text('Rename peer'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Mother');
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();

        final stored = await store.getRelationship();
        expect(stored?.label, 'Mother');
        // Home re-renders with the new label.
        expect(find.text('Mother'), findsOneWidget);
        expect(find.text('VERIFY MOTHER'), findsOneWidget);
      },
    );

    testWidgets(
      'rename dialog Cancel leaves the label unchanged',
      (tester) async {
        final store = FakeSecureStore(
          seeded: mom,
          secret: List<int>.generate(32, (i) => i),
        );
        await tester
            .pumpWidget(_wrap(store: store, child: const HomeScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Mom'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Stepmom');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        final stored = await store.getRelationship();
        expect(stored?.label, 'Mom');
        expect(find.text('Mom'), findsOneWidget);
      },
    );

    testWidgets(
      'rename dialog refuses an empty name',
      (tester) async {
        final store = FakeSecureStore(
          seeded: mom,
          secret: List<int>.generate(32, (i) => i),
        );
        await tester
            .pumpWidget(_wrap(store: store, child: const HomeScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Mom'));
        await tester.pumpAndSettle();

        // Clear the field — should make Save reject the input.
        await tester.enterText(find.byType(TextField), '   ');
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();

        expect(find.text('Name cannot be empty.'), findsOneWidget);
        // Dialog still open.
        expect(find.text('Rename peer'), findsOneWidget);
        final stored = await store.getRelationship();
        expect(stored?.label, 'Mom');
      },
    );

    testWidgets('HAPTICS row reads ON by default; tap toggles to OFF',
        (tester) async {
      final store = FakeSecureStore(
        seeded: mom,
        secret: List<int>.generate(32, (i) => i),
      );
      await tester.pumpWidget(_wrap(store: store, child: const HomeScreen()));
      await tester.pumpAndSettle();

      expect(_findRichContaining('HAPTICS //'), findsOneWidget);
      expect(find.text('ON'), findsOneWidget);

      await tester.tap(find.text('ON'));
      await tester.pumpAndSettle();

      expect(find.text('OFF'), findsOneWidget);
      final stored = await store.getRelationship();
      expect(stored?.silentHaptics, isTrue);
    });

    testWidgets('HAPTICS toggle persists back to ON on second tap',
        (tester) async {
      final store = FakeSecureStore(
        seeded: mom.copyWith(silentHaptics: true),
        secret: List<int>.generate(32, (i) => i),
      );
      await tester.pumpWidget(_wrap(store: store, child: const HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('OFF'), findsOneWidget);
      await tester.tap(find.text('OFF'));
      await tester.pumpAndSettle();

      expect(find.text('ON'), findsOneWidget);
      final stored = await store.getRelationship();
      expect(stored?.silentHaptics, isFalse);
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
