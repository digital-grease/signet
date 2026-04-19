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
final _secret = List<int>.generate(32, (i) => i + 1);

void main() {
  testWidgets('renders PAIR-TIME PHRASE and the 4 derived words',
      (tester) async {
    await tester.pumpWidget(_wrap(
      store: FakeSecureStore(seeded: _mom, secret: _secret),
      child: const BindingPhraseScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('PAIR-TIME PHRASE //'), findsOneWidget);
    expect(find.text('VERIFY BINDING'), findsOneWidget);

    final expected = await PairingVerification.derivePhrase(
      sharedSecret: _secret,
    );
    for (final word in expected) {
      expect(find.text(word), findsOneWidget);
    }
  });

  testWidgets('shows an error block when no relationship is paired',
      (tester) async {
    await tester.pumpWidget(_wrap(
      store: FakeSecureStore(),
      child: const BindingPhraseScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Could not read your pairing.'), findsOneWidget);
    expect(find.text('BACK TO HOME'), findsOneWidget);
  });

  testWidgets('renders the "IF THEY DO NOT MATCH" guidance block',
      (tester) async {
    await tester.pumpWidget(_wrap(
      store: FakeSecureStore(seeded: _mom, secret: _secret),
      child: const BindingPhraseScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('IF THEY DO NOT MATCH //'), findsOneWidget);
    expect(
      find.textContaining('Unpair and re-pair in person'),
      findsOneWidget,
    );
  });
}
