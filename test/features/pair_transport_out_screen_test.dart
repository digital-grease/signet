import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/pairing.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/core/theme/signet_theme.dart';
import 'package:signet/features/pairing/pair_transport_out_screen.dart';
import 'package:signet/l10n/app_localizations.dart';
import 'package:signet/shared/secure_clipboard.dart';

import '../support/fake_secure_store.dart';
import '../support/secure_clipboard_recorder.dart';

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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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

      await tester.enterText(find.byType(TextField).first, 'Alice');
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
      // Only the package can be copied; the 8 words cannot (bug R4).
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.text('Copy package'), findsOneWidget);
    },
  );

  // The response uses the same LDP format and PAKE words as the outgoing
  // package, so anyone on the channel can echo the sender's own package back
  // as the "response". The self-key check must stop the sender pairing with
  // herself; a low-order key must be refused too.
  for (final scenario in ['own package echoed back', 'low-order key']) {
    testWidgets('UNLOCK RESPONSE refuses $scenario', (tester) async {
      await tester.pumpWidget(_wrap(store: FakeSecureStore()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Alice');
      await tester.pumpAndSettle();
      await tester.tap(find.text('GENERATE PACKAGE'));
      await tester.pumpAndSettle();

      final extracted = await _extractOutgoing(tester);
      final responseWire = scenario == 'own package echoed back'
          ? extracted.outgoing
          : await TransportPackage.encodeLdp(
              publicKey: Uint8List(32),
              labelHint: '',
              pakeWords: extracted.pake,
            );

      await tester.enterText(find.byType(TextField).first, responseWire);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('UNLOCK RESPONSE'));
      await tester.tap(find.text('UNLOCK RESPONSE'));
      await tester.pumpAndSettle();

      // An echo is refused with what it is and what to do (plan Task 3.6,
      // P8); a low-order key is refused as unsafe.
      expect(
          find.textContaining(scenario == 'own package echoed back'
              ? 'This is the package you created'
              : 'not safe to use'),
          findsOneWidget);
      expect(find.text('PAIR-TIME PHRASE //'), findsNothing);
      expect(find.text('COMMIT PAIR'), findsNothing);
    });
  }

  testWidgets(
    'UNLOCK RESPONSE with matching PAKE reveals the pair-time phrase',
    (tester) async {
      await tester.pumpWidget(_wrap(store: FakeSecureStore()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Alice');
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

      await tester.enterText(find.byType(TextField).first, 'Alice');
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

      await tester.enterText(find.byType(TextField).first, 'Alice');
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

  testWidgets('Copy package uses the sensitive, timed clipboard',
      (tester) async {
    final clip = recordClipboard();
    await tester.pumpWidget(_wrap(store: FakeSecureStore()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Alice');
    await tester.pumpAndSettle();
    await tester.tap(find.text('GENERATE PACKAGE'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Copy package'));
    await tester.tap(find.text('Copy package'));
    await tester.pumpAndSettle();

    expect(clip.sensitive.single, startsWith('signet:tp1:'));
    expect(clip.plain, isEmpty);
    expect(find.textContaining('removes it from the clipboard'), findsOneWidget);
    SecureClipboard.resetForTesting();
  });

  group('names (plan Task 3.6)', () {
    Future<_Extracted> generate(WidgetTester tester,
        {String contact = 'Alice', String? ownName}) async {
      await tester.pumpWidget(_wrap(store: FakeSecureStore()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), contact);
      if (ownName != null) {
        await tester.enterText(find.byType(TextField).at(1), ownName);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('GENERATE PACKAGE'));
      await tester.pumpAndSettle();
      return _extractOutgoing(tester);
    }

    testWidgets(
        'the package carries the sender\'s own name, not the name they '
        'chose for the contact (P6)', (tester) async {
      final out = await generate(tester, contact: 'Bob', ownName: 'Alice');
      final ldp = await TransportPackage.decodeLdp(out.outgoing,
          pakeWords: out.pake);
      expect(ldp.labelHint, 'Alice');
    });

    testWidgets('no own name: the package carries no name', (tester) async {
      final out = await generate(tester, contact: 'Bob');
      final ldp = await TransportPackage.decodeLdp(out.outgoing,
          pakeWords: out.pake);
      expect(ldp.labelHint, isEmpty);
    });

    testWidgets('the own-name field stops at the 32-byte package limit (P7)',
        (tester) async {
      await tester.pumpWidget(_wrap(store: FakeSecureStore()));
      await tester.pumpAndSettle();
      final field = find.byType(TextField).at(1);
      await tester.enterText(field, '\u5988' * 10); // 30 bytes: fits
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, '\u5988' * 10);
      await tester.enterText(field, '\u5988' * 11); // 33 bytes
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, '\u5988' * 10,
          reason: 'cut back to what fits');
    });

    testWidgets('an own name past the limit (e.g. from an input method) is '
        'refused under its field, not as a raw error', (tester) async {
      await tester.pumpWidget(_wrap(store: FakeSecureStore()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Bob');
      // Set directly, as an IME commit can, past the field's formatter.
      tester
          .widget<TextField>(find.byType(TextField).at(1))
          .controller!
          .text = '\u5988' * 12;
      await tester.pumpAndSettle();
      await tester.tap(find.text('GENERATE PACKAGE'));
      await tester.pumpAndSettle();
      expect(find.text('That name is too long. Use a shorter one.'),
          findsOneWidget);
      expect(find.textContaining('Invalid argument'), findsNothing);
      expect(find.text('OUTGOING PACKAGE //'), findsNothing);
    });

    testWidgets('a data-shaped contact name is refused in the user\'s words',
        (tester) async {
      await tester.pumpWidget(_wrap(store: FakeSecureStore()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'signet:tp1:AAAA');
      await tester.pumpAndSettle();
      await tester.tap(find.text('GENERATE PACKAGE'));
      await tester.pumpAndSettle();
      expect(find.textContaining('looks like Signet data'), findsOneWidget);
    });

    testWidgets('pasting your own package as the response says so (P8)',
        (tester) async {
      final out = await generate(tester);
      await tester.enterText(find.byType(TextField).first, out.outgoing);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('UNLOCK RESPONSE'));
      await tester.tap(find.text('UNLOCK RESPONSE'));
      await tester.pumpAndSettle();
      expect(find.textContaining('This is the package you created'),
          findsOneWidget);
      expect(find.text('COMMIT PAIR'), findsNothing);
    });
  });
}
