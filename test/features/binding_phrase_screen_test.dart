import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/verification.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/core/theme/signet_theme.dart';
import 'package:signet/features/inspect/binding_phrase_screen.dart';

import '../support/fake_secure_store.dart';

Widget _wrap({required Widget child, required FakeSecureStore store}) {
  return ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(store),
    ],
    child: MaterialApp(
      theme: signetTheme(dark: false),
      darkTheme: signetTheme(dark: true),
      home: child,
    ),
  );
}

final _mom = Relationship(
  id: 'abc',
  label: 'Mom',
  pairedAt: DateTime.utc(2026, 4, 16),
  role: PairRole.a,
);
final _dad = Relationship(
  id: 'xyz',
  label: 'Dad',
  pairedAt: DateTime.utc(2026, 4, 17),
  role: PairRole.b,
);
final _momSecret = List<int>.generate(32, (i) => i + 1);
final _dadSecret = List<int>.generate(32, (i) => 255 - i);

void main() {
  testWidgets('renders PAIR-TIME PHRASE and the 4 derived words',
      (tester) async {
    await tester.pumpWidget(_wrap(
      store: FakeSecureStore(seeded: _mom, secret: _momSecret),
      child: const BindingPhraseScreen(relationshipId: 'abc'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('PAIR-TIME PHRASE //'), findsOneWidget);
    expect(find.text('VERIFY BINDING'), findsOneWidget);

    final expected = await PairingVerification.derivePhrase(
      sharedSecret: _momSecret,
    );
    for (final word in expected) {
      expect(find.text(word), findsOneWidget);
    }
  });

  testWidgets('shows an error block when no relationship is paired',
      (tester) async {
    await tester.pumpWidget(_wrap(
      store: FakeSecureStore(),
      child: const BindingPhraseScreen(relationshipId: 'abc'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Could not read your pairing.'), findsOneWidget);
    expect(find.text('BACK TO HOME'), findsOneWidget);
  });

  testWidgets('renders the "IF THEY DO NOT MATCH" guidance block',
      (tester) async {
    await tester.pumpWidget(_wrap(
      store: FakeSecureStore(seeded: _mom, secret: _momSecret),
      child: const BindingPhraseScreen(relationshipId: 'abc'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('IF THEY DO NOT MATCH //'), findsOneWidget);
    expect(
      find.textContaining('Unpair and re-pair in person'),
      findsOneWidget,
    );
  });

  testWidgets(
    'multi-peer: renders the selected peer phrase, not the first-paired one',
    (tester) async {
      // Regression test for the v0.2 multi-peer bug: the screen used to pick
      // relationships.first, so long-pressing Dad would display Mom's phrase
      // (or vice versa, depending on keyed-store ordering). With the
      // relationshipId param wired up, the selected peer's phrase must win.
      final store = FakeSecureStore(seeded: _mom, secret: _momSecret);
      await store.saveRelationshipV2(_dad, sharedSecret: _dadSecret);

      await tester.pumpWidget(_wrap(
        store: store,
        child: const BindingPhraseScreen(relationshipId: 'xyz'),
      ));
      await tester.pumpAndSettle();

      final dadPhrase = await PairingVerification.derivePhrase(
        sharedSecret: _dadSecret,
      );
      final momPhrase = await PairingVerification.derivePhrase(
        sharedSecret: _momSecret,
      );

      // Dad's phrase is rendered.
      for (final word in dadPhrase) {
        expect(find.text(word), findsOneWidget);
      }
      // Mom's phrase is not (assuming the two derivations don't collide,
      // which for two independent 32-byte secrets is cryptographic
      // certainty — but assert per-word to fail loudly if it ever did).
      final overlap = momPhrase.toSet().intersection(dadPhrase.toSet());
      for (final word in momPhrase) {
        if (overlap.contains(word)) continue;
        expect(find.text(word), findsNothing);
      }

      // Body copy names the selected peer, not the first-paired one.
      expect(find.textContaining('Dad'), findsWidgets);
    },
  );

  testWidgets(
    'renders the error block when the relationshipId points to no peer',
    (tester) async {
      final store = FakeSecureStore(seeded: _mom, secret: _momSecret);
      await tester.pumpWidget(_wrap(
        store: store,
        child: const BindingPhraseScreen(relationshipId: 'not-a-real-id'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Could not read your pairing.'), findsOneWidget);
      expect(find.text('PAIR-TIME PHRASE //'), findsNothing);
    },
  );
}
