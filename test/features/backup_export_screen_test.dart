import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/core/theme/signet_theme.dart';
import 'package:signet/features/inspect/backup_export_screen.dart';

import '../support/fake_secure_store.dart';

final _mom = Relationship(
  id: 'abcdef0011223344',
  label: 'Mom',
  pairedAt: DateTime.utc(2026, 2, 14, 15, 3),
  role: PairRole.a,
);
final _secret = List<int>.generate(32, (i) => i + 1);

Widget _wrap({required FakeSecureStore store, required String id}) {
  final router = GoRouter(
    initialLocation: '/inspect/export/$id',
    routes: <RouteBase>[
      GoRoute(
        path: '/inspect/export/:id',
        builder: (_, state) =>
            BackupExportScreen(relationshipId: state.pathParameters['id']!),
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

void main() {
  testWidgets('renders the three core sections after generation',
      (tester) async {
    await tester.pumpWidget(_wrap(
      store: FakeSecureStore(seeded: _mom, secret: _secret),
      id: _mom.id,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Back up Mom'), findsOneWidget);
    expect(find.text('STORE THESE SEPARATELY //'), findsOneWidget);
    expect(find.text('PAKE SECRET //'), findsOneWidget);
    expect(find.text('BACKUP PACKAGE //'), findsOneWidget);
    expect(find.text('REMEMBER //'), findsOneWidget);
    expect(find.text("I'VE SAVED IT"), findsOneWidget);
  });

  testWidgets('the displayed package is a valid LPR that decodes back',
      (tester) async {
    await tester.pumpWidget(_wrap(
      store: FakeSecureStore(seeded: _mom, secret: _secret),
      id: _mom.id,
    ));
    await tester.pumpAndSettle();

    // Pull the LPR wire out of the SelectableText.
    final selectables =
        tester.widgetList<SelectableText>(find.byType(SelectableText));
    final wire =
        selectables.firstWhere((s) => (s.data ?? '').startsWith('signet:tp1:'));
    expect(wire.data, isNotNull);

    // Pull the 8 PAKE words off screen (rendered at 16sp mono).
    final monoTexts = tester.widgetList<Text>(find.byType(Text)).where((t) {
      return t.style?.fontFamily == 'monospace' && t.style?.fontSize == 16;
    }).toList();
    expect(monoTexts.length >= 8, isTrue,
        reason: '8 PAKE words must be visible');
    final pakeWords =
        monoTexts.take(8).map((t) => t.data!).toList(growable: false);

    final decoded = await TransportPackage.decodeLpr(
      wire.data!,
      pakeWords: pakeWords,
    );
    expect(decoded.label, _mom.label);
    expect(decoded.role, _mom.role);
    expect(decoded.pairedAt.toUtc(), _mom.pairedAt.toUtc());
    expect(decoded.silentHaptics, _mom.silentHaptics);
    expect(decoded.sharedSecret.toList(), _secret);
  });

  testWidgets(
    'Share package button is present alongside Copy package',
    (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(seeded: _mom, secret: _secret),
        id: _mom.id,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Copy package'), findsOneWidget);
      expect(find.text('Share package'), findsOneWidget);
    },
  );

  testWidgets(
    "I'VE SAVED IT routes back to home",
    (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(seeded: _mom, secret: _secret),
        id: _mom.id,
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text("I'VE SAVED IT"));
      await tester.tap(find.text("I'VE SAVED IT"));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    },
  );

  testWidgets(
    'unknown relationship id surfaces the error state',
    (tester) async {
      await tester.pumpWidget(_wrap(
        store: FakeSecureStore(),
        id: 'no-such-id',
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not generate backup'),
          findsOneWidget);
    },
  );
}
