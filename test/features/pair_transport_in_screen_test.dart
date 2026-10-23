import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/pairing.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/crypto/verification.dart';
import 'package:signet/core/crypto/wordlists.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/core/theme/signet_theme.dart';
import 'package:signet/features/pairing/pair_transport_in_screen.dart';
import 'package:signet/l10n/app_localizations.dart';
import 'package:signet/shared/secure_clipboard.dart';

import '../support/fake_secure_store.dart';
import '../support/secure_clipboard_recorder.dart';

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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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

/// The pair-time phrase as shown, in order (the 22-point monospace rows).
List<String> _shownPhrase(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .where((t) =>
        t.style?.fontFamily == 'monospace' && t.style?.fontSize == 22)
    .map((t) => t.data ?? '')
    .toList();

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
      final wire = await TransportPackage.encodeLdpRequest(
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
    'a package carrying a low-order key is rejected as tampered (C1)',
    (tester) async {
      // An attacker who controls the package channel and knows the PAKE
      // words could swap in the all-zero point; both sides would then
      // derive the same public secret and matching phrases.
      final wire = await TransportPackage.encodeLdpRequest(
        publicKey: Uint8List(32),
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

      expect(find.textContaining('not safe to use'), findsOneWidget);
      expect(find.text('PAIR-TIME PHRASE //'), findsNothing);
      expect(find.text('COMMIT PAIR'), findsNothing);
    },
  );

  testWidgets(
    'successful unlock transitions to the confirm pane with phrase + response',
    (tester) async {
      final kp = await PairingHandshake.generateEphemeralKeyPair();
      final wire = await TransportPackage.encodeLdpRequest(
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
      final wire = await TransportPackage.encodeLdpRequest(
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
      final wire = await TransportPackage.encodeLdpRequest(
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

      final error = find.text('Give this contact a name.');
      expect(error, findsOneWidget);
      expect(
        find.ancestor(
          of: error,
          matching: find.widgetWithText(TextField, '   '),
        ),
        findsOneWidget,
      );
      expect(await store.listRelationships(), isEmpty);

      // Typing in the field clears the error.
      await tester.enterText(find.widgetWithText(TextField, '   '), 'A');
      await tester.pumpAndSettle();
      expect(error, findsNothing);
    },
  );

  // Plan Task 1.7g: a request without the strong-phrase tag (Signet 0.3.6
  // and older, or a stripped tag) is refused, never answered with the weak
  // phrase; an accepted request gets a version 2 response with the tag.
  testWidgets('a request from an older Signet is refused', (tester) async {
    final kp = await PairingHandshake.generateEphemeralKeyPair();
    final wire = await TransportPackage.encodeLdp(
      publicKey: kp.publicKey,
      labelHint: 'Alice',
      pakeWords: goodPake,
      version: 1,
    );
    await tester.pumpWidget(_wrap(store: FakeSecureStore()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, wire);
    await tester.pumpAndSettle();
    await _enterPakeWords(tester, goodPake);
    await tester.ensureVisible(find.text('UNLOCK PACKAGE'));
    await tester.tap(find.text('UNLOCK PACKAGE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('made by an older version of Signet'),
        findsOneWidget);
    expect(
      find.byWidgetPredicate((w) =>
          w is SelectableText && (w.data ?? '').startsWith('signet:tp1:')),
      findsNothing,
      reason: 'no response is produced',
    );
  });

  // Plan Task 1.7j: a request from a newer Signet asks to update, before
  // or after the words unlock it, and produces no response.
  Future<void> unlockRequest(WidgetTester tester, String wire) async {
    await tester.pumpWidget(_wrap(store: FakeSecureStore()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, wire);
    await tester.pumpAndSettle();
    await _enterPakeWords(tester, goodPake);
    await tester.ensureVisible(find.text('UNLOCK PACKAGE'));
    await tester.tap(find.text('UNLOCK PACKAGE'));
    await tester.pumpAndSettle();
  }

  testWidgets('a pasted request from a newer Signet says so before the '
      'words, and a good one clears it', (tester) async {
    final good = await TransportPackage.encodeLdpRequest(
      publicKey: Uint8List(32)..[0] = 9,
      labelHint: 'Alice',
      pakeWords: goodPake,
    );
    await tester.pumpWidget(_wrap(store: FakeSecureStore()));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).first, 'signet:tp2:AQIDBAUGBwgJ');
    await tester.pumpAndSettle();
    expect(find.textContaining('needs a newer version of Signet'),
        findsOneWidget);
    await tester.enterText(find.byType(TextField).first, good);
    await tester.pumpAndSettle();
    expect(find.textContaining('needs a newer version of Signet'),
        findsNothing);
  });

  testWidgets('a request from a newer Signet asks to update', (tester) async {
    final v2 = await TransportPackage.encodeLdpRequest(
      publicKey: Uint8List(32)..[0] = 9,
      labelHint: 'Alice',
      pakeWords: goodPake,
    );
    final body = base64Url.decode(_pad(v2.substring('signet:tp1:'.length)));
    body[0] = 3;
    final v3 = 'signet:tp1:${base64Url.encode(body).replaceAll('=', '')}';
    for (final wire in [v3, 'signet:tp2:AQIDBAUGBwgJ']) {
      await unlockRequest(tester, wire);
      expect(find.textContaining('needs a newer version of Signet'),
          findsOneWidget, reason: wire);
      expect(find.text('YOUR RESPONSE //'), findsNothing);
    }
  });

  testWidgets('an unlocked request with a field this build does not know '
      'asks to update', (tester) async {
    final wire = await TransportPackage.encodeLdp(
      publicKey: Uint8List(32)..[0] = 9,
      labelHint: 'Alice',
      pakeWords: goodPake,
      version: 2,
      extensions: const [
        TransportExtension(TransportPackage.ldpStrongPhraseTag, [0x01]),
        TransportExtension(0x8F, [1]),
      ],
    );
    await unlockRequest(tester, wire);
    expect(find.textContaining('made by a newer version of Signet'),
        findsOneWidget);
    expect(find.text('YOUR RESPONSE //'), findsNothing);
  });

  testWidgets('the response is version 2 with the strong-phrase tag',
      (tester) async {
    final kp = await PairingHandshake.generateEphemeralKeyPair();
    final wire = await TransportPackage.encodeLdpRequest(
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

    final response = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((t) => t.data ?? '')
        .firstWhere((t) => t.startsWith('signet:tp1:'));
    final decoded = await TransportPackage.decodeLdpStrict(
      response,
      pakeWords: goodPake,
    );
    expect(decoded.version, 2);
    expect(decoded.hasStrongPhrase, isTrue);

    // The words shown are the 8-word phrase over both keys: the requester
    // (this test holds its private key) derives the same ones.
    final shared = await PairingHandshake.deriveSharedSecret(
      ours: kp,
      theirPublicKey: decoded.publicKey,
    );
    final expected = await PairingVerification.deriveLongDistancePhrase(
      sharedSecret: shared,
      ownPublicKey: kp.publicKey,
      peerPublicKey: decoded.publicKey,
    );
    expect(expected, hasLength(8));
    expect(_shownPhrase(tester), expected);
  });

  testWidgets('Copy response uses the sensitive, timed clipboard',
      (tester) async {
    final clip = recordClipboard();
    final kp = await PairingHandshake.generateEphemeralKeyPair();
    final wire = await TransportPackage.encodeLdpRequest(
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

    await tester.ensureVisible(find.text('Copy response'));
    await tester.tap(find.text('Copy response'));
    await tester.pumpAndSettle();

    expect(clip.sensitive.single, startsWith('signet:tp1:'));
    expect(clip.plain, isEmpty);
    expect(find.textContaining('removes it from the clipboard'), findsOneWidget);
    SecureClipboard.resetForTesting();
  });

  testWidgets(
      'the response is keyed on the reading of the words that opened the '
      'request (plan Task 8.4b)', (tester) async {
    // Words spelled the same in English and French, at different indices:
    // the phrase reads two ways, and the sender used the French reading.
    final shared = [
      for (final w in WordList.english.words)
        if (WordList.french.indexOf(w) case final i?
            when WordList.french.wordAt(i) == w)
          w,
    ].take(8).toList();
    final readings = TransportPackage.pakeCandidates(shared);
    expect(readings, hasLength(2));
    final senderWords = readings.last;

    final clip = recordClipboard();
    final kp = await PairingHandshake.generateEphemeralKeyPair();
    final wire = await TransportPackage.encodeLdpRequest(
      publicKey: kp.publicKey,
      labelHint: 'Alice',
      pakeWords: senderWords,
    );
    await tester.pumpWidget(_wrap(store: FakeSecureStore()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, wire);
    await tester.pumpAndSettle();
    await _enterPakeWords(tester, shared);
    await tester.ensureVisible(find.text('UNLOCK PACKAGE'));
    await tester.tap(find.text('UNLOCK PACKAGE'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Copy response'));
    await tester.tap(find.text('Copy response'));
    await tester.pumpAndSettle();

    final response = await tester.runAsync(() =>
        TransportPackage.decodeLdpStrict(
          clip.sensitive.single,
          pakeWords: senderWords,
        ));
    expect(response!.publicKey, hasLength(32));
    SecureClipboard.resetForTesting();
  });

  group('the suggested name (plan Task 3.6)', () {
    Future<String> unlockWithHint(WidgetTester tester, String hint) async {
      final kp = await PairingHandshake.generateEphemeralKeyPair();
      final wire = await TransportPackage.encodeLdpRequest(
        publicKey: kp.publicKey,
        labelHint: hint,
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
      return tester
          .widget<TextField>(find.byType(TextField).last)
          .controller!
          .text;
    }

    testWidgets('direction-changing characters are removed', (tester) async {
      expect(await unlockWithHint(tester, '\u202Eecila'), 'ecila');
    });

    testWidgets('a data-shaped hint is not suggested', (tester) async {
      expect(await unlockWithHint(tester, '0123456789abcdef0123'), isEmpty);
    });

    testWidgets('a normal hint is suggested as is', (tester) async {
      expect(await unlockWithHint(tester, 'Alice'), 'Alice');
    });
  });

  testWidgets('a word corrected after all 8 were entered is the one used',
      (tester) async {
    final kp = await PairingHandshake.generateEphemeralKeyPair();
    final wire = await TransportPackage.encodeLdpRequest(
      publicKey: kp.publicKey,
      labelHint: 'Alice',
      pakeWords: goodPake,
    );
    await tester.pumpWidget(_wrap(store: FakeSecureStore()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, wire);
    await tester.pumpAndSettle();
    await _enterPakeWords(tester, <String>[...goodPake.take(7), 'absurd']);
    // Fix the last word (slot 8 is TextField index 8).
    await tester.enterText(find.byType(TextField).at(8), goodPake.last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('UNLOCK PACKAGE'));
    await tester.tap(find.text('UNLOCK PACKAGE'));
    await tester.pumpAndSettle();
    expect(find.text('PAIR-TIME PHRASE //'), findsOneWidget);
  });

  // Large text (CLAUDE.md: large-text mode is first-class): the 8-word
  // confirm pane fits or scrolls, the number labels stay on one line, and
  // COMMIT stays reachable.
  for (final (size, scale) in const [
    (Size(360, 640), 1.3),
    (Size(360, 640), 2.0),
    (Size(412, 915), 2.0),
  ]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()} @${scale}x';
    testWidgets('the 8-word confirm pane works at large text, $tag',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final kp = await PairingHandshake.generateEphemeralKeyPair();
      final wire = await TransportPackage.encodeLdpRequest(
        publicKey: kp.publicKey,
        labelHint: 'Alice',
        pakeWords: goodPake,
      );
      await tester.pumpWidget(_wrap(store: FakeSecureStore()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'unlock pane');
      await tester.enterText(find.byType(TextField).first, wire);
      await tester.pumpAndSettle();
      await _enterPakeWords(tester, goodPake);
      await tester.ensureVisible(find.text('UNLOCK PACKAGE'));
      await tester.tap(find.text('UNLOCK PACKAGE'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_shownPhrase(tester), hasLength(8));
      final label = find.byWidgetPredicate(
          (w) => w is Text && w.data == '8.' && w.style?.fontSize == 16);
      expect(tester.getSize(label).height, lessThan(16 * scale * 1.8),
          reason: '"8." on one line');
      await tester.ensureVisible(find.text('COMMIT PAIR'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

String _pad(String s) => s + '=' * ((4 - s.length % 4) % 4);
