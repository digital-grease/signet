import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/core/theme/signet_theme.dart';
import 'package:signet/features/inspect/backup_import_screen.dart';

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
    initialLocation: '/inspect/import',
    routes: <RouteBase>[
      GoRoute(
        path: '/inspect/import',
        builder: (_, _) => const BackupImportScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
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

Future<String> _mintLprWire({
  String label = 'Mom',
  PairRole role = PairRole.a,
  bool silentHaptics = false,
  required List<int> sharedSecret,
  List<String> pake = goodPake,
}) {
  return TransportPackage.encodeLpr(
    label: label,
    role: role,
    pairedAt: DateTime.utc(2026, 2, 14, 15, 3),
    silentHaptics: silentHaptics,
    sharedSecret: sharedSecret,
    pakeWords: pake,
  );
}

Future<void> _enterPake(WidgetTester tester, List<String> words) async {
  // Slot 0 of the WordInput (TextField index 1 — index 0 is the paste field).
  final slot = find.byType(TextField).at(1);
  await tester.enterText(slot, words.join(' '));
  await tester.pumpAndSettle();
}

void main() {
  final secret = List<int>.generate(32, (i) => i + 7);

  testWidgets('unlock pane shows both Paste and Load-from-file actions',
      (tester) async {
    await tester.pumpWidget(_wrap(store: FakeSecureStore()));
    await tester.pumpAndSettle();
    expect(find.text('Paste from clipboard'), findsOneWidget);
    expect(find.text('Load from file'), findsOneWidget);
  });

  testWidgets('unlock pane renders and blocks empty submit', (tester) async {
    await tester.pumpWidget(_wrap(store: FakeSecureStore()));
    await tester.pumpAndSettle();

    expect(find.text('BACKUP PACKAGE //'), findsOneWidget);
    expect(find.text('PAKE SECRET //'), findsOneWidget);
    expect(find.text('UNLOCK BACKUP'), findsOneWidget);

    await tester.ensureVisible(find.text('UNLOCK BACKUP'));
    await tester.tap(find.text('UNLOCK BACKUP'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paste your backup'), findsOneWidget);
  });

  testWidgets('successful unlock reveals the commit pane with peer preview',
      (tester) async {
    final wire = await _mintLprWire(sharedSecret: secret);
    await tester.pumpWidget(_wrap(store: FakeSecureStore()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, wire);
    await tester.pumpAndSettle();
    await _enterPake(tester, goodPake);
    await tester.ensureVisible(find.text('UNLOCK BACKUP'));
    await tester.tap(find.text('UNLOCK BACKUP'));
    await tester.pumpAndSettle();

    expect(find.text('RESTORED PEER //'), findsOneWidget);
    expect(find.text('Mom'), findsOneWidget);
    expect(find.text('COMMIT IMPORT'), findsOneWidget);
  });

  testWidgets(
    'COMMIT IMPORT writes a fresh Relationship with the decoded label + role',
    (tester) async {
      final wire = await _mintLprWire(
        label: 'Mom',
        role: PairRole.b,
        sharedSecret: secret,
      );
      final store = FakeSecureStore();

      await tester.pumpWidget(_wrap(store: store));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, wire);
      await tester.pumpAndSettle();
      await _enterPake(tester, goodPake);
      await tester.ensureVisible(find.text('UNLOCK BACKUP'));
      await tester.tap(find.text('UNLOCK BACKUP'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('COMMIT IMPORT'));
      await tester.tap(find.text('COMMIT IMPORT'));
      await tester.pumpAndSettle();

      final stored = await store.listRelationships();
      expect(stored, hasLength(1));
      expect(stored.single.label, 'Mom');
      expect(stored.single.role, PairRole.b);

      final storedSecret =
          await store.getSharedSecretById(stored.single.id);
      expect(storedSecret?.toList(), secret);
      expect(find.text('HOME'), findsOneWidget);
    },
  );

  testWidgets('wrong PAKE surfaces an inline error', (tester) async {
    final wire = await _mintLprWire(sharedSecret: secret);
    await tester.pumpWidget(_wrap(store: FakeSecureStore()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, wire);
    await tester.pumpAndSettle();
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
    await _enterPake(tester, wrongPake);
    await tester.ensureVisible(find.text('UNLOCK BACKUP'));
    await tester.tap(find.text('UNLOCK BACKUP'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not unlock'), findsOneWidget);
  });

  testWidgets('mis-typed (LDP instead of LPR) wire is rejected as package type',
      (tester) async {
    // Phase 14: dispatch peeks the payload-type byte before attempting
    // decryption and rejects LDP wires with a targeted "pairing invitation"
    // message — users who try to import a pair-start QR get pointed at the
    // right flow instead of a cryptic "wrong payload type" error.
    final ldpWire = await TransportPackage.encodeLdp(
      publicKey: List<int>.generate(32, (i) => i),
      labelHint: 'Mom',
      pakeWords: goodPake,
    );
    await tester.pumpWidget(_wrap(store: FakeSecureStore()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, ldpWire);
    await tester.pumpAndSettle();
    await _enterPake(tester, goodPake);
    await tester.ensureVisible(find.text('UNLOCK BACKUP'));
    await tester.tap(find.text('UNLOCK BACKUP'));
    await tester.pumpAndSettle();

    expect(find.textContaining('pairing invitation'), findsOneWidget);
  });

  // --- Clipboard mock helpers ---------------------------------------
  //
  // Flutter's platform channel mock is strongly typed around
  // invokeMethod<Map<String, dynamic>>, so the handler must return either
  // `null` (no ClipboardData at all — matches "nothing has ever been
  // copied" on a fresh emulator) or a concrete Map<String, dynamic>
  // (matches a real clipboard payload). Returning a mis-typed map throws
  // a cast error that manifests as the test silently seeing no paste.
  void installClipboardMock({required String? text}) {
    TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        if (text == null) return null;
        return <String, dynamic>{'text': text};
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  }

  testWidgets(
    'Paste from clipboard with empty clipboard surfaces a user-visible error',
    (tester) async {
      installClipboardMock(text: null);
      await tester.pumpWidget(_wrap(store: FakeSecureStore()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Paste from clipboard'));
      await tester.tap(find.text('Paste from clipboard'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Clipboard is empty'),
        findsOneWidget,
        reason:
            'User in a crisis moment taps Paste with nothing on the clipboard; '
            'silent no-op would leave them re-tapping with no feedback.',
      );
    },
  );

  testWidgets(
    'Paste from clipboard with whitespace-only clipboard is treated as empty',
    (tester) async {
      installClipboardMock(text: '   \n  ');
      await tester.pumpWidget(_wrap(store: FakeSecureStore()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Paste from clipboard'));
      await tester.tap(find.text('Paste from clipboard'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Clipboard is empty'), findsOneWidget);
    },
  );

  testWidgets(
    'Paste with real content clears any prior error and fills the wire field',
    (tester) async {
      installClipboardMock(text: 'signet:tp1:DEADBEEF');
      await tester.pumpWidget(_wrap(store: FakeSecureStore()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Paste from clipboard'));
      await tester.tap(find.text('Paste from clipboard'));
      await tester.pumpAndSettle();

      final wireField = tester.widget<TextField>(find.byType(TextField).first);
      expect(wireField.controller!.text, 'signet:tp1:DEADBEEF');
      expect(find.textContaining('Clipboard is empty'), findsNothing);
    },
  );

  testWidgets('silentHaptics = true is preserved through the import',
      (tester) async {
    final wire = await _mintLprWire(
      silentHaptics: true,
      sharedSecret: secret,
    );
    final store = FakeSecureStore();
    await tester.pumpWidget(_wrap(store: store));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, wire);
    await tester.pumpAndSettle();
    await _enterPake(tester, goodPake);
    await tester.ensureVisible(find.text('UNLOCK BACKUP'));
    await tester.tap(find.text('UNLOCK BACKUP'));
    await tester.pumpAndSettle();

    // The HAPTICS row is rendered via RichText (no find.text hit).
    final hapticsOff = find.byWidgetPredicate((w) {
      if (w is! RichText) return false;
      final text = w.text.toPlainText();
      return text.contains('HAPTICS //') && text.contains('OFF');
    });
    expect(hapticsOff, findsOneWidget,
        reason: 'preview shows HAPTICS // OFF when silent');

    await tester.ensureVisible(find.text('COMMIT IMPORT'));
    await tester.tap(find.text('COMMIT IMPORT'));
    await tester.pumpAndSettle();

    final stored = await store.listRelationships();
    expect(stored.single.silentHaptics, isTrue);
  });
}
