import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/pairing.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/core/theme/signet_theme.dart';
import 'package:signet/features/pairing/pair_transport_out_screen.dart';

import '../support/fake_secure_store.dart';

Widget _wrap({required FakeSecureStore store}) {
  final router = GoRouter(
    initialLocation: '/pair/transport-out',
    routes: <RouteBase>[
      GoRoute(
        path: '/pair/transport-out',
        builder: (_, _) => const PairTransportOutScreen(),
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

/// Pull the current outgoing wire + PAKE words off the screen so an
/// in-test "receiver" can craft a matching response LDP package.
Future<_Extracted> _extractOutgoing(WidgetTester tester) async {
  // PAKE words rendered at font-size 16 in the left column. Scan for
  // every Text widget whose style has fontFamily='monospace' and whose
  // content is a single BIP-39 wordlist word — the first 8 in tree
  // order are the PAKE words.
  final wires = <String>[];
  final pakeWords = <String>[];
  final selectables = tester.widgetList<SelectableText>(
    find.byType(SelectableText),
  );
  for (final st in selectables) {
    final text = st.data ?? '';
    if (text.startsWith('signet:tp1:')) {
      wires.add(text);
    }
  }
  final textWidgets = tester.widgetList<Text>(find.byType(Text));
  for (final t in textWidgets) {
    final style = t.style;
    if (style?.fontFamily != 'monospace') continue;
    final size = style?.fontSize;
    if (size != 16) continue;
    final data = t.data ?? '';
    if (data.length <= 2 || data.contains(' ') || data.contains('.')) continue;
    pakeWords.add(data);
    if (pakeWords.length == 8) break;
  }
  return _Extracted(outgoing: wires.single, pake: pakeWords);
}

class _Extracted {
  _Extracted({required this.outgoing, required this.pake});
  final String outgoing;
  final List<String> pake;
}

Future<String> _craftReceiverResponse({
  required List<String> pakeWords,
}) async {
  final receiverKp = await PairingHandshake.generateEphemeralKeyPair();
  return TransportPackage.encodeLdp(
    publicKey: receiverKp.publicKey,
    labelHint: '',
    pakeWords: pakeWords,
  );
}

void main() {
  testWidgets('setup pane renders and blocks empty label on GENERATE',
      (tester) async {
    await tester.pumpWidget(_wrap(store: FakeSecureStore()));
    await tester.pumpAndSettle();

    expect(find.text('NAME THIS CONTACT //'), findsOneWidget);
    expect(find.text('GENERATE PACKAGE'), findsOneWidget);

    await tester.tap(find.text('GENERATE PACKAGE'));
    await tester.pumpAndSettle();

    expect(find.text('Give this contact a name.'), findsOneWidget);
  });

  testWidgets(
    'GENERATE with a label mints a package + PAKE and transitions to share pane',
    (tester) async {
      await tester.pumpWidget(_wrap(store: FakeSecureStore()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pumpAndSettle();
      await tester.tap(find.text('GENERATE PACKAGE'));
      await tester.pumpAndSettle();

      expect(find.text('OUTGOING PACKAGE //'), findsOneWidget);
      expect(find.text('PAKE SECRET //'), findsOneWidget);
      expect(find.text('RECEIVE RESPONSE //'), findsOneWidget);
      expect(find.text('UNLOCK RESPONSE'), findsOneWidget);
      // Outgoing wire actually rendered.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SelectableText &&
              (w.data ?? '').startsWith('signet:tp1:'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'UNLOCK RESPONSE with matching PAKE reveals the pair-time phrase',
    (tester) async {
      await tester.pumpWidget(_wrap(store: FakeSecureStore()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pumpAndSettle();
      await tester.tap(find.text('GENERATE PACKAGE'));
      await tester.pumpAndSettle();

      final extracted = await _extractOutgoing(tester);
      final responseWire = await _craftReceiverResponse(
        pakeWords: extracted.pake,
      );

      // The response textfield is the second TextField (the first was
      // the label input, which is no longer in the tree; now the FIRST
      // and only TextField is the response field).
      final responseField = find.byType(TextField).first;
      await tester.enterText(responseField, responseWire);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('UNLOCK RESPONSE'));
      await tester.tap(find.text('UNLOCK RESPONSE'));
      await tester.pumpAndSettle();

      expect(find.text('PAIR-TIME PHRASE //'), findsOneWidget);
      expect(find.text('COMMIT PAIR'), findsOneWidget);
    },
  );

  testWidgets(
    'COMMIT writes the relationship and routes to /pair/complete/:id',
    (tester) async {
      final store = FakeSecureStore();
      await tester.pumpWidget(_wrap(store: store));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pumpAndSettle();
      await tester.tap(find.text('GENERATE PACKAGE'));
      await tester.pumpAndSettle();

      final extracted = await _extractOutgoing(tester);
      final responseWire = await _craftReceiverResponse(
        pakeWords: extracted.pake,
      );
      await tester.enterText(find.byType(TextField).first, responseWire);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('UNLOCK RESPONSE'));
      await tester.tap(find.text('UNLOCK RESPONSE'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('COMMIT PAIR'));
      await tester.tap(find.text('COMMIT PAIR'));
      await tester.pumpAndSettle();

      final stored = await store.listRelationships();
      expect(stored, hasLength(1));
      expect(stored.single.label, 'Alice');
      expect(
        find.textContaining('COMPLETE_${stored.single.id}'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'UNLOCK RESPONSE with a non-matching response surfaces an error',
    (tester) async {
      await tester.pumpWidget(_wrap(store: FakeSecureStore()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pumpAndSettle();
      await tester.tap(find.text('GENERATE PACKAGE'));
      await tester.pumpAndSettle();

      // Response encoded with a WRONG PAKE list — unlock should fail.
      const wrongPake = <String>[
        'abandon',
        'ability',
        'able',
        'about',
        'above',
        'absent',
        'absorb',
        'absurd',
      ];
      final responseWire = await _craftReceiverResponse(pakeWords: wrongPake);
      await tester.enterText(find.byType(TextField).first, responseWire);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('UNLOCK RESPONSE'));
      await tester.tap(find.text('UNLOCK RESPONSE'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not unlock response'),
        findsOneWidget,
      );
    },
  );
}
