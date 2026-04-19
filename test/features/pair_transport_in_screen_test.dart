import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/pairing.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/core/theme/signet_theme.dart';
import 'package:signet/features/pairing/pair_transport_in_screen.dart';

import '../support/fake_secure_store.dart';

const goodPake = <String>[
  'abandon',
  'ability',
  'able',
  'about',
  'above',
  'absent',
  'absorb',
  'abstract',
];

Widget _wrap({required FakeSecureStore store}) {
  final router = GoRouter(
    initialLocation: '/pair/transport-in',
    routes: <RouteBase>[
      GoRoute(
        path: '/pair/transport-in',
        builder: (_, _) => const PairTransportInScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/pair/complete/:id',
        builder: (_, state) =>
            Scaffold(body: Text('COMPLETE_${state.pathParameters['id']}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(store),
    ],
    child: MaterialApp.router(
      theme: signetTheme(dark: false),
      darkTheme: signetTheme(dark: true),
      routerConfig: router,
    ),
  );
}

Future<void> _enterPakeWords(WidgetTester tester, List<String> words) async {
  // The receiver flow's PAKE slot is the second WordInput in the tree
  // (after the package TextField). Using the paste distribution path —
  // the WordInput recognizes space-separated input in slot 0 and fans
  // it across all 8 slots.
  final pakeSlot = find.byType(TextField).at(1);
  await tester.enterText(pakeSlot, words.join(' '));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Unlock pane renders the expected sections', (tester) async {
    await tester.pumpWidget(_wrap(store: FakeSecureStore()));
    await tester.pumpAndSettle();

    expect(find.text('INCOMING PACKAGE //'), findsOneWidget);
    expect(find.text('PAKE SECRET //'), findsOneWidget);
    expect(find.text('UNLOCK PACKAGE'), findsOneWidget);
  });

  testWidgets(
    'UNLOCK with empty inputs shows an inline error',
    (tester) async {
      await tester.pumpWidget(_wrap(store: FakeSecureStore()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('UNLOCK PACKAGE'));
      await tester.tap(find.text('UNLOCK PACKAGE'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Paste the package'), findsOneWidget);
    },
  );

  testWidgets(
    'UNLOCK with wrong PAKE words surfaces InvalidPakeException inline',
    (tester) async {
      // Forge a valid LDP package so only the PAKE secret is the failure.
      final wire = await TransportPackage.encodeLdp(
        publicKey: List<int>.generate(32, (i) => i),
        labelHint: 'Alice',
        pakeWords: goodPake,
      );

      await tester.pumpWidget(_wrap(store: FakeSecureStore()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, wire);
      await tester.pumpAndSettle();
      await _enterPakeWords(tester, const <String>[
        'abandon',
        'ability',
        'able',
        'about',
        'above',
        'absent',
        'absorb',
        'absurd', // wrong last word
      ]);
      await tester.ensureVisible(find.text('UNLOCK PACKAGE'));
      await tester.tap(find.text('UNLOCK PACKAGE'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not unlock'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'successful unlock transitions to the confirm pane with phrase + response',
    (tester) async {
      final kp = await PairingHandshake.generateEphemeralKeyPair();
      final wire = await TransportPackage.encodeLdp(
        publicKey: kp.publicKey,
        labelHint: 'Alice',
        pakeWords: goodPake,
      );

      await tester.pumpWidget(_wrap(store: FakeSecureStore()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, wire);
      await tester.pumpAndSettle();
      await _enterPakeWords(tester, goodPake);
      await tester.ensureVisible(find.text('UNLOCK PACKAGE'));
      await tester.tap(find.text('UNLOCK PACKAGE'));
      await tester.pumpAndSettle();

      expect(find.text('PAIR-TIME PHRASE //'), findsOneWidget);
      expect(find.text('YOUR RESPONSE //'), findsOneWidget);
      expect(find.text('NAME THIS CONTACT //'), findsOneWidget);
      expect(find.text('COMMIT PAIR'), findsOneWidget);
      // The sender's labelHint pre-fills the name field.
      expect(find.widgetWithText(TextField, 'Alice'), findsOneWidget);
    },
  );

  testWidgets(
    'COMMIT writes the relationship and navigates to /pair/complete/:id',
    (tester) async {
      final kp = await PairingHandshake.generateEphemeralKeyPair();
      final wire = await TransportPackage.encodeLdp(
        publicKey: kp.publicKey,
        labelHint: 'Alice',
        pakeWords: goodPake,
      );
      final store = FakeSecureStore();

      await tester.pumpWidget(_wrap(store: store));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, wire);
      await tester.pumpAndSettle();
      await _enterPakeWords(tester, goodPake);
      await tester.ensureVisible(find.text('UNLOCK PACKAGE'));
      await tester.tap(find.text('UNLOCK PACKAGE'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('COMMIT PAIR'));
      await tester.tap(find.text('COMMIT PAIR'));
      await tester.pumpAndSettle();

      final stored = await store.listRelationships();
      expect(stored, hasLength(1));
      expect(stored.single.label, 'Alice');
      // Routed to /pair/complete/<id>.
      expect(
        find.textContaining('COMPLETE_${stored.single.id}'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'COMMIT with empty label is blocked with an inline error',
    (tester) async {
      final kp = await PairingHandshake.generateEphemeralKeyPair();
      final wire = await TransportPackage.encodeLdp(
        publicKey: kp.publicKey,
        labelHint: 'Alice',
        pakeWords: goodPake,
      );
      final store = FakeSecureStore();

      await tester.pumpWidget(_wrap(store: store));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, wire);
      await tester.pumpAndSettle();
      await _enterPakeWords(tester, goodPake);
      await tester.ensureVisible(find.text('UNLOCK PACKAGE'));
      await tester.tap(find.text('UNLOCK PACKAGE'));
      await tester.pumpAndSettle();

      // Clear the pre-filled label.
      await tester.enterText(
        find.widgetWithText(TextField, 'Alice'),
        '   ',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('COMMIT PAIR'));
      await tester.tap(find.text('COMMIT PAIR'));
      await tester.pumpAndSettle();

      expect(find.text('Give this contact a name.'), findsOneWidget);
      expect(await store.listRelationships(), isEmpty);
    },
  );
}
