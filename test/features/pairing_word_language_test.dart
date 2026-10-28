// Word language at pairing and on an existing contact (v0.5.0 plan Task
// 1.5): the name screen's row, the confirm screen's switch (same indices,
// other list; the language on screen at Match is saved), rekey starting in
// the contact's language, the long-press "Word language" item, the
// language label on backup words, and the bulk-restore Overwrite note.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/backup_bundle.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/crypto/wordlists.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/prefs/app_prefs.dart';
import 'package:signet/core/prefs/settings_controller.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/features/home/home_screen.dart';
import 'package:signet/features/inspect/backup_export_screen.dart';
import 'package:signet/features/inspect/bulk_backup_import_screen.dart';
import 'package:signet/features/pairing/in_person_pairing_controller.dart';
import 'package:signet/features/pairing/pair_confirm_screen.dart';
import 'package:signet/features/pairing/pair_start_screen.dart';
import 'package:signet/l10n/app_localizations.dart';
import 'package:signet/shared/widgets/word_language_row.dart';

import '../support/fake_secure_store.dart';
import '../support/in_person_pairing.dart';
import '../support/test_prefs.dart';

final _mom = Relationship(
  id: 'mom-id',
  label: 'Mom',
  pairedAt: DateTime.utc(2026, 1, 1),
  role: PairRole.a,
  wordLanguage: 'fr',
);
final _secret = List<int>.generate(32, (i) => i + 5);

GoRouter _router(String path, Widget screen) => GoRouter(
      initialLocation: path,
      routes: <RouteBase>[
        GoRoute(path: path, builder: (_, _) => screen),
        GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
        GoRoute(path: '/pair/exchange', builder: (_, _) => const Text('EXCHANGE')),
        GoRoute(
          path: '/pair/practice/:id',
          builder: (_, _) => const Text('PRACTICE'),
        ),
        GoRoute(
          path: '/pair/complete/:id',
          builder: (_, _) => const Text('COMPLETE'),
        ),
      ],
    );

Future<ProviderContainer> _container(
  FakeSecureStore store, {
  AppPrefs? prefs,
}) async {
  final container = ProviderContainer(overrides: [
    testInPersonPhrase,
    secureStoreProvider.overrideWithValue(store),
    appPrefsProvider.overrideWithValue(prefs ?? await testPrefs()),
  ]);
  addTearDown(container.dispose);
  return container;
}

Widget _scope(ProviderContainer container, String path, Widget screen) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: _router(path, screen),
      ),
    );

/// The phrase as the confirm screen shows it (displaySmall rows).
List<String> _confirmWords(WidgetTester tester, List<String> canonical) {
  final shown = <String>[];
  for (final l in WordList.shipped) {
    final words = l.respell(canonical);
    if (words.every((w) => find.text(w).evaluate().isNotEmpty)) {
      shown.add(l.id);
    }
  }
  return shown;
}

Future<void> _pickInSheet(WidgetTester tester, String endonym) async {
  await tester.ensureVisible(find.text('CHANGE'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('CHANGE'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(endonym).last);
  await tester.pumpAndSettle();
}

void main() {
  group('in person', () {
    testWidgets('the name screen preselects the default; CHANGE overrides it',
        (tester) async {
      final container = await _container(FakeSecureStore(),
          prefs: await testPrefs({'signet.word_language': 'fr'}));
      await tester.pumpWidget(
          _scope(container, '/pair/start', const PairStartScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Words: Français'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Mom');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(container.read(inPersonPairingControllerProvider).wordList,
          WordList.french);

      await tester.pumpWidget(
          _scope(container, '/pair/start', const PairStartScreen()));
      await tester.pumpAndSettle();
      await _pickInSheet(tester, 'English');
      expect(find.text('Words: English'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Dad');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(container.read(inPersonPairingControllerProvider).wordList,
          WordList.english);
    });

    testWidgets(
        'confirm shows the chosen list, the switch re-shows the same phrase, '
        'and Match saves the language on screen', (tester) async {
      final store = FakeSecureStore();
      final container = await _container(store);
      container
          .read(inPersonPairingControllerProvider.notifier)
          .setLabel('Mom', wordList: WordList.french);
      await tester.runAsync(() => driveToConfirm(container));
      final phrase = container.read(inPersonPairingControllerProvider).phrase!;

      await tester.pumpWidget(
          _scope(container, '/pair/confirm', const PairConfirmScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Words: Français'), findsOneWidget);
      expect(_confirmWords(tester, phrase), contains('fr'));

      await _pickInSheet(tester, 'English');
      expect(find.text('Words: English'), findsOneWidget);
      expect(_confirmWords(tester, phrase), contains('en'));
      expect(container.read(inPersonPairingControllerProvider).phrase, phrase,
          reason: 'switching never touches the attempt');

      await tester.ensureVisible(find.text('It matches'));
      await tester.tap(find.text('It matches'));
      await tester.pumpAndSettle();
      expect((await store.listRelationships()).single.wordLanguage, 'en');
    });

    for (final (keep, expected) in [(true, 'fr'), (false, 'en')]) {
      testWidgets(
          'rekey starts in the contact\'s language; '
          '${keep ? 'keeping it leaves no change date' : 'switching dates it'}',
          (tester) async {
        final store = FakeSecureStore(seeded: _mom, secret: _secret);
        final container = await _container(store);
        container.read(inPersonPairingControllerProvider.notifier).startRekey(
              id: _mom.id,
              label: _mom.label,
              wordList: _mom.knownWordList,
            );
        await tester.runAsync(() => driveToConfirm(container));
        await tester.pumpWidget(
            _scope(container, '/pair/confirm', const PairConfirmScreen()));
        await tester.pumpAndSettle();
        expect(find.text('Words: Français'), findsOneWidget);
        if (!keep) await _pickInSheet(tester, 'English');
        await tester.ensureVisible(find.text('It matches'));
        await tester.tap(find.text('It matches'));
        await tester.pumpAndSettle();
        final saved = (await store.getRelationshipById(_mom.id))!;
        expect(saved.wordLanguage, expected);
        expect(saved.wordLanguageChangedAt == null, keep);
      });
    }
  });

  group('confirm screen layout', () {
    Future<void> confirmAt(WidgetTester tester, Size size, double scale) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = await _container(FakeSecureStore());
      container
          .read(inPersonPairingControllerProvider.notifier)
          .setLabel('Mom', wordList: WordList.french);
      await tester.runAsync(() => driveToConfirm(container));
      await tester.pumpWidget(
          _scope(container, '/pair/confirm', const PairConfirmScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('at normal text on 360x640 "It matches" needs no scrolling',
        (tester) async {
      await confirmAt(tester, const Size(360, 640), 1.0);
      expect(find.text('It matches').hitTestable(), findsOneWidget);
    });

    for (final size in [const Size(320, 568), const Size(412, 915)]) {
      testWidgets('at 2x text on ${size.width.toInt()} wide the row stays '
          'compact and the words and button are reachable', (tester) async {
        await confirmAt(tester, size, 2.0);
        final row = find.byType(WordLanguageRow);
        expect(tester.getSize(row).height, lessThan(size.height * 0.75));
        final list = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(find.text('It matches'), 100,
            scrollable: list);
        expect(find.text('It matches').hitTestable(), findsOneWidget);
      });
    }

    testWidgets('CHANGE says what it changes to TalkBack', (tester) async {
      final handle = tester.ensureSemantics();
      await confirmAt(tester, const Size(412, 915), 1.0);
      expect(find.bySemanticsLabel('Change word language'), findsOneWidget);
      handle.dispose();
    });
  });

  group('Home menu', () {
    Future<void> openMenu(WidgetTester tester, FakeSecureStore store,
        ProviderContainer container) async {
      await tester.pumpWidget(_scope(container, '/home', const HomeScreen()));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Mom'));
      await tester.pumpAndSettle();
    }

    testWidgets('Word language shows the contact\'s, saves and dates a change',
        (tester) async {
      final store = FakeSecureStore(seeded: _mom, secret: _secret);
      final container = await _container(store);
      await openMenu(tester, store, container);
      expect(find.text('Word language'), findsOneWidget);
      expect(find.text('Français'), findsOneWidget, reason: 'menu subtitle');
      await tester.tap(find.text('Word language'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mom must choose the same language'),
          findsOneWidget);
      expect(find.textContaining('never because a caller asks you to'),
          findsOneWidget);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final saved = (await store.getRelationshipById(_mom.id))!;
      expect(saved.wordLanguage, 'en');
      expect(saved.wordLanguageChangedAt, isNotNull);
      expect(find.textContaining("Mom's words are now in English"),
          findsOneWidget);
    });

    testWidgets('the dialog shows when the language last changed',
        (tester) async {
      final dated =
          _mom.copyWith(wordLanguageChangedAt: DateTime.utc(2026, 3, 4, 12));
      final store = FakeSecureStore(seeded: dated, secret: _secret);
      final container = await _container(store);
      await openMenu(tester, store, container);
      await tester.tap(find.text('Word language'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Last changed'), findsOneWidget);
    });

    testWidgets('Save without a change writes nothing', (tester) async {
      final store = FakeSecureStore(seeded: _mom, secret: _secret);
      final container = await _container(store);
      await openMenu(tester, store, container);
      await tester.tap(find.text('Word language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect((await store.getRelationshipById(_mom.id))!.wordLanguageChangedAt,
          isNull);
    });

    testWidgets('rekey from the menu starts in the contact\'s language',
        (tester) async {
      final store = FakeSecureStore(seeded: _mom, secret: _secret);
      final container = await _container(store);
      await openMenu(tester, store, container);
      await tester.ensureVisible(find.text('Rekey Mom'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rekey Mom'));
      await tester.pumpAndSettle();
      expect(container.read(inPersonPairingControllerProvider).wordList,
          WordList.french);
    });

    testWidgets('no rekey while the language is unknown', (tester) async {
      final store = FakeSecureStore(
          seeded: _mom.copyWith(wordLanguage: 'zh-9'), secret: _secret);
      final container = await _container(store);
      await openMenu(tester, store, container);
      expect(find.text('Word language'), findsOneWidget);
      expect(find.text('Unknown: update Signet'), findsOneWidget);
      expect(find.text('Rekey Mom'), findsNothing);
    });
  });

  group('backup words carry their language', () {
    testWidgets('single export labels the words', (tester) async {
      final store = FakeSecureStore(seeded: _mom, secret: _secret);
      final container = await _container(store);
      await tester.pumpWidget(_scope(container, '/export',
          BackupExportScreen(relationshipId: _mom.id)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('I saved it another way'));
      await tester.tap(find.text('I saved it another way'));
      await tester.pumpAndSettle();
      expect(find.text('Words: Français'), findsOneWidget);
    });

    test('the WORDS file names the language and still reads back', () {
      final words = TransportPackage.mintPakeWords(list: WordList.french);
      final file = BackupFiles.formatWords(
        pakeWords: words,
        fingerprint: '123 456',
        generatedAt: DateTime.utc(2026, 5, 1),
        language: 'Français',
      );
      expect(file, contains('# Words: Français\n'));
      expect(BackupText.read(file).pakeWords, words);
    });
  });

  group('bulk restore Overwrite', () {
    BlkRelationshipRecord record(String? id) => BlkRelationshipRecord(
          sharedSecret: Uint8List.fromList(List<int>.filled(32, 9)),
          role: PairRole.b,
          label: 'Mom',
          pairedAt: DateTime.utc(2026, 1, 1),
          silentHaptics: false,
          extensions: {
            if (id != null)
              TransportPackage.wordListTag:
                  TransportPackage.wordListExtension(id).value,
          },
        );

    for (final (id, note) in <(String?, bool)>[
      ('en', true),
      (null, true),
      ('fr', false),
    ]) {
      testWidgets(
          'a ${id ?? 'v0.4.0'} record against a French contact '
          '${note ? 'says' : 'does not say'} it changes the language',
          (tester) async {
        final store = FakeSecureStore(seeded: _mom, secret: _secret);
        final container = await _container(store);
        await tester.pumpWidget(_scope(
          container,
          '/import',
          BulkBackupImportScreen(
            decoded: BlkPackage(
                records: [record(id)], timestamp: DateTime.utc(2026, 4, 22)),
          ),
        ));
        await tester.pumpAndSettle();
        expect(
            find.text('Also changes the word language to English.'),
            note ? findsOneWidget : findsNothing);
      });
    }
  });
}
