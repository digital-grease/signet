// Contacts that cannot be read (plan Task 4.4): Settings says so and can
// remove them in one step; bulk backup warns that it skips them.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/prefs/app_prefs.dart';
import 'package:signet/core/prefs/settings_controller.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/features/inspect/bulk_backup_export_screen.dart';
import 'package:signet/features/settings/settings_screen.dart';
import 'package:signet/l10n/app_localizations.dart';

import '../support/fake_secure_store.dart';

void main() {
  late FakeSecureStore store;

  setUp(() {
    store = FakeSecureStore(
      seeded: Relationship(
        id: 'mom',
        label: 'Mom',
        pairedAt: DateTime.utc(2026, 1, 1),
        role: PairRole.a,
      ),
      secret: List<int>.filled(32, 1),
    );
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'signet.onboarding_completed': true,
    });
    final prefs = await AppPrefs.load();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appPrefsProvider.overrideWithValue(prefs),
        secureStoreProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SettingsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('no unreadable contacts: no notice', (tester) async {
    await pumpSettings(tester);
    expect(find.text('CONTACTS THAT COULD NOT BE READ'), findsNothing);
  });

  testWidgets('unreadable contacts are counted and can be removed',
      (tester) async {
    store.unreadable.addAll(<String>['x1', 'x2']);
    await pumpSettings(tester);
    expect(find.text('CONTACTS THAT COULD NOT BE READ'), findsOneWidget);
    expect(find.textContaining('2 paired contacts could not be read'),
        findsOneWidget);

    await tester.ensureVisible(find.text('Remove unreadable contacts'));
    await tester.tap(find.text('Remove unreadable contacts'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(store.unreadable, isEmpty);
    expect(find.text('CONTACTS THAT COULD NOT BE READ'), findsNothing);
    expect(await store.listRelationships(), hasLength(1),
        reason: 'readable contacts are untouched');
  });

  testWidgets('bulk backup warns that it skips unreadable contacts',
      (tester) async {
    store.unreadable.add('x1');
    final router = GoRouter(
      initialLocation: '/inspect/export-bulk',
      routes: <RouteBase>[
        GoRoute(
          path: '/inspect/export-bulk',
          builder: (_, _) => const BulkBackupExportScreen(),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [secureStoreProvider.overrideWithValue(store)],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('1 contact could not be read and will not be in '
            'this backup'),
        findsOneWidget);
  });

  testWidgets('a failed removal says so and leaves the notice accurate',
      (tester) async {
    store.unreadable.addAll(<String>['x1', 'x2']);
    store.failDeleteIds.add('x2');
    await pumpSettings(tester);
    await tester.ensureVisible(find.text('Remove unreadable contacts'));
    await tester.tap(find.text('Remove unreadable contacts'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Some of them could not be removed. Try again.'),
        findsOneWidget);
    expect(find.textContaining('1 paired contact could not be read'),
        findsOneWidget);
  });

  testWidgets('a stuck startup sweep does not keep the list from loading',
      (tester) async {
    store.sweepHangs = true;
    final container = ProviderContainer(
        overrides: [secureStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    final listed = container.read(relationshipsProvider.future);
    await tester.pump(const Duration(seconds: 4));
    expect((await listed).map((r) => r.label), <String>['Mom']);
  });
}
