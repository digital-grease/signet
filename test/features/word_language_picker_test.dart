// The default word language (v0.5.0 plan Task 1.4): a first-run picker
// before onboarding, preselected from the device's languages; existing
// installs set to English with no prompt and a one-time Home notice when
// the phone's language has a list; Settings changes the default for new
// contacts only; bulk backups spell their words in it.

import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signet/app.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/wordlists.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/prefs/app_prefs.dart';
import 'package:signet/core/prefs/settings_controller.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/features/home/home_screen.dart';
import 'package:signet/features/inspect/bulk_backup_export_screen.dart';
import 'package:signet/features/onboarding/word_language_screen.dart';
import 'package:signet/features/settings/settings_screen.dart';
import 'package:signet/l10n/app_localizations.dart';

import '../support/fake_secure_store.dart';
import '../support/test_prefs.dart';

Future<AppPrefs> _freshInstall() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return AppPrefs.load();
}

Widget _app(AppPrefs prefs, FakeSecureStore store, Widget screen,
    {String path = '/x'}) {
  final router = GoRouter(
    initialLocation: path,
    routes: <RouteBase>[
      GoRoute(path: path, builder: (_, _) => screen),
      GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
      GoRoute(path: '/onboarding', builder: (_, _) => const Text('INTRO')),
      GoRoute(path: '/settings', builder: (_, _) => const Text('SETTINGS')),
    ],
  );
  return ProviderScope(
    overrides: [
      appPrefsProvider.overrideWithValue(prefs),
      secureStoreProvider.overrideWithValue(store),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    ),
  );
}

/// Which option TalkBack hears as selected.
List<String> _checked(WidgetTester tester) => [
      for (final list in WordList.shipped)
        if (tester
            .getSemantics(find.bySemanticsLabel(RegExp('^${list.endonym}\\.')))
            .flagsCollection
            .isChecked == CheckedState.isTrue)
          list.endonym,
    ];

void main() {
  group('first run', () {
    testWidgets('a new install opens on the picker, then onboarding',
        (tester) async {
      final prefs = await _freshInstall();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appPrefsProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(FakeSecureStore()),
        ],
        child: SignetApp(prefs: prefs),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Word language'), findsOneWidget);
      await tester.tap(find.text('Français'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(prefs.wordLanguage, 'fr');
      // The first onboarding slide.
      expect(find.text('Word language'), findsNothing);
      expect(find.text('SKIP'), findsOneWidget);
    });

    testWidgets('a language chosen before quitting skips the picker',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'signet.word_language': 'fr',
      });
      final prefs = await AppPrefs.load();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appPrefsProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(FakeSecureStore()),
        ],
        child: SignetApp(prefs: prefs),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Word language'), findsNothing);
      expect(find.text('SKIP'), findsOneWidget);
    });

    for (final (codes, expected) in <(List<String>, String)>[
      (['fr'], 'Français'),
      (['de', 'fr', 'en'], 'Français'),
      (['en', 'fr'], 'English'),
      (['de'], 'English'),
      (<String>[], 'English'),
    ]) {
      testWidgets('device languages $codes preselect $expected',
          (tester) async {
        final handle = tester.ensureSemantics();
        final prefs = await _freshInstall();
        await tester.pumpWidget(_app(prefs, FakeSecureStore(),
            WordLanguageScreen(deviceLanguageCodes: codes)));
        await tester.pumpAndSettle();
        expect(_checked(tester), [expected]);
        // One tap keeps it.
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();
        expect(WordList.byId(prefs.wordLanguage!)!.endonym, expected);
        expect(find.text('INTRO'), findsOneWidget);
        handle.dispose();
      });
    }

    testWidgets('options carry the language and sample words for TalkBack',
        (tester) async {
      final handle = tester.ensureSemantics();
      final prefs = await _freshInstall();
      await tester.pumpWidget(_app(prefs, FakeSecureStore(),
          const WordLanguageScreen(deviceLanguageCodes: ['en'])));
      await tester.pumpAndSettle();
      final fr = tester.getSemantics(find.bySemanticsLabel(RegExp('^Français')));
      expect(fr.label, contains(WordList.french.wordAt(1916)));
      expect(fr.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      // Selectable through the accessibility tree (TalkBack double-tap,
      // Switch Access, Voice Access), not only by a touch on the row.
      tester.semantics.tap(find.semantics.byLabel(RegExp('^Français')));
      await tester.pumpAndSettle();
      expect(_checked(tester), ['Français']);
      handle.dispose();
    });

    for (final (size, scale) in <(Size, double)>[
      (const Size(360, 640), 1.3),
      (const Size(320, 568), 2.0),
    ]) {
      testWidgets('fits at ${scale}x text on ${size.width.toInt()} wide',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final prefs = await _freshInstall();
        await tester.pumpWidget(_app(prefs, FakeSecureStore(),
            const WordLanguageScreen(deviceLanguageCodes: ['fr'])));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('CONTINUE'), 100,
            scrollable: find.byType(Scrollable).first);
        expect(find.text('CONTINUE').hitTestable(), findsOneWidget);
      });
    }
  });

  group('upgrade from v0.4.0', () {
    Future<AppPrefs> upgraded() async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'signet.onboarding_completed': true,
      });
      return AppPrefs.load();
    }

    test('English with no prompt; a French phone gets the notice', () async {
      final prefs = await upgraded();
      await prefs.settleWordLanguageForUpgrade(['fr', 'en']);
      expect(prefs.wordLanguage, 'en');
      expect(prefs.wordLanguageNotice, WordList.french);
    });

    test('an English phone gets no notice', () async {
      final prefs = await upgraded();
      await prefs.settleWordLanguageForUpgrade(['en', 'fr']);
      expect(prefs.wordLanguage, 'en');
      expect(prefs.wordLanguageNotice, isNull);
    });

    test('a new install and a chosen default are left alone', () async {
      final fresh = await _freshInstall();
      await fresh.settleWordLanguageForUpgrade(['fr']);
      expect(fresh.wordLanguage, isNull);

      SharedPreferences.setMockInitialValues(<String, Object>{
        'signet.onboarding_completed': true,
        'signet.word_language': 'fr',
      });
      final chosen = await AppPrefs.load();
      await chosen.settleWordLanguageForUpgrade(['fr']);
      expect(chosen.wordLanguage, 'fr');
      expect(chosen.wordLanguageNotice, isNull);
    });

    Future<void> home(WidgetTester tester, AppPrefs prefs) async {
      final router = GoRouter(routes: <RouteBase>[
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const Text('SETTINGS')),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appPrefsProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(FakeSecureStore()),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('Home shows the notice once; GOT IT dismisses it for good',
        (tester) async {
      final prefs = await upgraded();
      await prefs.settleWordLanguageForUpgrade(['fr']);
      await home(tester, prefs);
      expect(find.textContaining('show your words in Français'),
          findsOneWidget);
      await tester.tap(find.text('GOT IT'));
      await tester.pumpAndSettle();
      expect(find.textContaining('show your words in'), findsNothing);
      expect(prefs.wordLanguageNotice, isNull);
      expect(prefs.wordLanguage, 'en', reason: 'the notice changes nothing');
    });

    for (final (size, scale) in <(Size, double)>[
      (const Size(412, 915), 2.0),
      (const Size(320, 568), 2.0),
    ]) {
      testWidgets(
          'at ${scale}x text on ${size.width.toInt()} wide the notice '
          'scrolls, and GOT IT and the contacts stay reachable',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final prefs = await upgraded();
        await prefs.settleWordLanguageForUpgrade(['fr']);
        final router = GoRouter(routes: <RouteBase>[
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        ]);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            appPrefsProvider.overrideWithValue(prefs),
            secureStoreProvider.overrideWithValue(FakeSecureStore(
              seeded: Relationship(
                id: 'm',
                label: 'Mom',
                pairedAt: DateTime.utc(2026),
                role: PairRole.a,
              ),
              secret: List.filled(32, 1),
            )),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            routerConfig: router,
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final list = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(find.text('Mom'), 100,
            scrollable: list);
        expect(find.text('Mom').hitTestable(), findsOneWidget);
        await tester.scrollUntilVisible(find.text('GOT IT'), -100,
            scrollable: list);
        expect(find.text('GOT IT').hitTestable(), findsOneWidget);
      });
    }

    testWidgets('choosing the suggested language in Settings retires the '
        'notice', (tester) async {
      final prefs = await upgraded();
      await prefs.settleWordLanguageForUpgrade(['fr']);
      await tester.pumpWidget(_app(prefs, FakeSecureStore(),
          const SettingsScreen(), path: '/s'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Français'));
      await tester.tap(find.text('Français'));
      await tester.pumpAndSettle();
      expect(prefs.wordLanguageNotice, isNull);
    });

    testWidgets('SETTINGS on the notice opens Settings and dismisses it',
        (tester) async {
      final prefs = await upgraded();
      await prefs.settleWordLanguageForUpgrade(['fr']);
      await home(tester, prefs);
      await tester.tap(find.text('SETTINGS'));
      await tester.pumpAndSettle();
      expect(find.text('SETTINGS'), findsOneWidget);
      expect(prefs.wordLanguageNotice, isNull);
    });
  });

  group('Settings', () {
    testWidgets('changes the default for new contacts only', (tester) async {
      final mom = Relationship(
        id: 'm',
        label: 'Mom',
        pairedAt: DateTime.utc(2026),
        role: PairRole.a,
      );
      final store = FakeSecureStore(seeded: mom, secret: List.filled(32, 1));
      final prefs = await testPrefs();
      await tester.pumpWidget(
          _app(prefs, store, const SettingsScreen(), path: '/s'));
      await tester.pumpAndSettle();
      expect(find.text('WORD LANGUAGE'), findsOneWidget);
      await tester.ensureVisible(find.text('Français'));
      await tester.tap(find.text('Français'));
      await tester.pumpAndSettle();
      expect(prefs.wordLanguage, 'fr');
      expect((await store.getRelationshipById('m'))!.wordLanguage, 'en');
    });
  });

  testWidgets('bulk backup words follow the default', (tester) async {
    final mom = Relationship(
      id: 'm',
      label: 'Mom',
      pairedAt: DateTime.utc(2026),
      role: PairRole.a,
    );
    final store = FakeSecureStore(seeded: mom, secret: List.filled(32, 1));
    final prefs = await testPrefs({'signet.word_language': 'fr'});
    await tester.pumpWidget(
        _app(prefs, store, const BulkBackupExportScreen(), path: '/b'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GENERATE BULK BACKUP'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('I saved it another way'));
    await tester.tap(find.text('I saved it another way'));
    await tester.pumpAndSettle();
    final words = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) =>
            t.style?.fontFamily == 'monospace' && t.style?.fontSize == 16)
        .take(8)
        .map((t) => t.data!)
        .toList();
    expect(words, hasLength(8));
    expect(words.every(WordList.french.contains), isTrue, reason: '$words');
  });
}
