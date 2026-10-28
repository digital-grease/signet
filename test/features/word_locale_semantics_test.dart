// Words carry their list's language for screen readers (v0.5.0 plan Task
// 1.5b): on an English UI, a French contact's words are marked fr so
// TalkBack reads them with a French voice, and the reverse.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/challenge_response_grid.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/totp_words.dart';
import 'package:signet/core/crypto/verification.dart';
import 'package:signet/core/crypto/wordlists.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/prefs/settings_controller.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/features/inspect/backup_export_screen.dart';
import 'package:signet/features/inspect/binding_phrase_screen.dart';
import 'package:signet/features/inspect/cr_grid_screen.dart';
import 'package:signet/features/pairing/in_person_pairing_controller.dart';
import 'package:signet/features/pairing/pair_confirm_screen.dart';
import 'package:signet/features/verify/verify_screen.dart';
import 'package:signet/features/verify/word_input.dart';
import 'package:signet/l10n/app_localizations.dart';
import 'package:signet/shared/widgets/word_language_options.dart';
import 'package:signet/shared/widgets/words_display.dart';
import 'package:signet/shared/word_semantics.dart';

import '../support/fake_secure_store.dart';
import '../support/in_person_pairing.dart';
import '../support/test_prefs.dart';
import '../support/word_locale.dart';

const _t = 1735776000;
final _secret = List<int>.generate(32, (i) => i * 3 + 1);
final _mom = Relationship(
  id: 'abcdef0011223344',
  label: 'Mom',
  pairedAt: DateTime.utc(2026, 2, 14),
  role: PairRole.a,
  wordLanguage: 'fr',
);

Future<void> _pump(WidgetTester tester, Widget screen,
    {ProviderContainer? container}) async {
  final router = GoRouter(
    initialLocation: '/x',
    routes: <RouteBase>[
      GoRoute(path: '/x', builder: (_, _) => screen),
      GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
    ],
  );
  final app = MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    routerConfig: router,
  );
  if (container != null) {
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: app));
  } else {
    final store = FakeSecureStore(seeded: _mom, secret: _secret);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        secureStoreProvider.overrideWithValue(store),
        appPrefsProvider.overrideWithValue(await testPrefs()),
      ],
      child: app,
    ));
  }
  await tester.pumpAndSettle();
}

void main() {
  group('attributedWords', () {
    test('marks every occurrence, skipping words inside marked ones', () {
      final a = attributedWords('table able cat able', WordList.french,
          words: ['able', 'table']);
      expect([
        for (final x in a.attributes) a.string.substring(x.range.start, x.range.end)
      ], ['table', 'able', 'able']);
    });

    test('whole words only, and only inside the substituted words', () {
      final a = attributedWords(
          'Verification phrase: phrase élève, 12 secondes', WordList.french,
          words: ['phrase', 'élève', 'second'], within: 'phrase élève');
      expect([
        for (final x in a.attributes) a.string.substring(x.range.start, x.range.end)
      ], ['phrase', 'élève']);
      expect(a.attributes.first.range.start, 'Verification phrase: '.length);
    });

    test('a list word inside a longer UI word is not marked', () {
      final a = attributedWords('12 secondes restantes', WordList.english,
          words: ['second', 'rest']);
      expect(a.attributes, isEmpty);
    });

    testWidgets('show-my-words marks the words, not the same word in the UI',
        (tester) async {
      final handle = tester.ensureSemantics();
      // "phrase" is a French list word and also part of the English label.
      const words = ['phrase', 'élève', 'trésor', 'pouce'];
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: WordsDisplay(
            words: words,
            list: WordList.french,
            secondsRemaining: 12,
            windowSeconds: 30,
          ),
        ),
      ));
      final label = tester
          .getSemantics(find.byType(WordsDisplay))
          .getSemanticsData()
          .attributedLabel;
      expect(label.string, startsWith('Verification phrase: '));
      expect(label.attributes, hasLength(4));
      expect(label.attributes.first.range.start, 'Verification phrase: '.length);
      handle.dispose();
    });

    test('a locale keeps script and region', () {
      expect(wordLocale(WordList.french), const Locale('fr'));
    });

    test('marks the whole text without words, with the list locale', () {
      final a = attributedWords('élève', WordList.french);
      final attr = a.attributes.single as LocaleStringAttribute;
      expect(attr.range, const TextRange(start: 0, end: 5));
      expect(attr.locale, const Locale('fr'));
    });

    test('every list has a language tag the locale keeps', () {
      for (final l in WordList.shipped) {
        expect(wordLocale(l).toLanguageTag(), l.languageTag);
      }
    });
  });

  group('a French contact on an English UI', () {
    testWidgets('show my words', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
          tester,
          VerifyScreen(
              relationshipId: _mom.id, unixTimeSecondsProvider: () => _t));
      await tester.ensureVisible(find.text('Show my 4 words'));
      await tester.tap(find.text('Show my 4 words'));
      await tester.pumpAndSettle();
      expectMarked(
          tester,
          await TotpWords.generate(
              secret: _secret,
              unixTimeSeconds: _t,
              senderRole: _mom.role,
              list: WordList.french),
          'fr');
      handle.dispose();
    });

    testWidgets('verify chips', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
          tester,
          VerifyScreen(
              relationshipId: _mom.id, unixTimeSecondsProvider: () => _t));
      await tester.enterText(find.byType(TextField).first, 'élè');
      await tester.pumpAndSettle();
      expect(find.byType(ActionChip), findsWidgets);
      expectMarked(tester, ['élève'], 'fr');
      handle.dispose();
    });

    testWidgets('a typed or chosen word in a verify slot', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
          tester,
          VerifyScreen(
              relationshipId: _mom.id, unixTimeSecondsProvider: () => _t));
      await tester.enterText(find.byType(TextField).first, 'élève');
      await tester.pumpAndSettle();
      expectMarked(tester, ['élève'], 'fr');
      handle.dispose();
    });

    testWidgets('grid cell dialog title and the explanation', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, CrGridScreen(relationshipId: _mom.id));
      final grid =
          await ChallengeResponseGrid.derive(_secret, list: WordList.french);
      List<String> markedIn(Finder f) {
        final label = tester.getSemantics(f).getSemanticsData().attributedLabel;
        return [
          for (final x in label.attributes)
            if (x is LocaleStringAttribute && x.locale == const Locale('fr'))
              label.string.substring(x.range.start, x.range.end),
        ];
      }

      // The explanation's own node, not the grid headers.
      expect(markedIn(find.textContaining('×').first),
          containsAll([grid.rowLabels.first, grid.colLabels.first]));
      await tester.tap(find.text(grid.cells[0][0].first));
      await tester.pumpAndSettle();
      expect(
          markedIn(find.descendant(
              of: find.byType(AlertDialog),
              matching: find.textContaining(grid.rowLabels.first))),
          containsAll([grid.rowLabels.first, grid.colLabels.first]));
      handle.dispose();
    });

    testWidgets('challenge grid', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, CrGridScreen(relationshipId: _mom.id));
      final grid =
          await ChallengeResponseGrid.derive(_secret, list: WordList.french);
      // Labels (also in the explanation above) and a cell's words, which
      // appear only in the grid.
      expectMarked(tester,
          [grid.rowLabels.first, grid.colLabels.first, ...grid.cells[0][0]],
          'fr');
      handle.dispose();
    });

    testWidgets('binding phrase', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, BindingPhraseScreen(relationshipId: _mom.id));
      expectMarked(
          tester,
          await PairingVerification.derivePhrase(
              sharedSecret: _secret, list: WordList.french),
          'fr');
      handle.dispose();
    });

    testWidgets('backup words and their label', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, BackupExportScreen(relationshipId: _mom.id));
      await tester.ensureVisible(find.text('I saved it another way'));
      await tester.tap(find.text('I saved it another way'));
      await tester.pumpAndSettle();
      final words = tester
          .widgetList<WordText>(find.byType(WordText))
          .map((w) => w.word)
          .toList();
      expect(words, hasLength(8));
      expectMarked(tester, [...words, 'Français'], 'fr');
      handle.dispose();
    });
  });

  testWidgets('in-person confirm phrase follows the switch', (tester) async {
    final handle = tester.ensureSemantics();
    final container = ProviderContainer(overrides: [
      testInPersonPhrase,
      secureStoreProvider.overrideWithValue(FakeSecureStore()),
      appPrefsProvider.overrideWithValue(await testPrefs()),
    ]);
    addTearDown(container.dispose);
    container
        .read(inPersonPairingControllerProvider.notifier)
        .setLabel('Mom', wordList: WordList.french);
    await tester.runAsync(() => driveToConfirm(container));
    final phrase = container.read(inPersonPairingControllerProvider).phrase!;
    await _pump(tester, const PairConfirmScreen(), container: container);
    expectMarked(tester, WordList.french.respell(phrase), 'fr');
    expectMarked(tester, ['Français'], 'fr');
    container
        .read(inPersonPairingControllerProvider.notifier)
        .setWordList(WordList.english);
    await tester.pumpAndSettle();
    expectMarked(tester, WordList.english.respell(phrase), 'en');
    handle.dispose();
  });

  testWidgets('language options read their name and samples in their voice',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: WordLanguageOptions(selected: WordList.english, onChanged: (_) {}),
      ),
    ));
    expectMarked(tester, ['Français', WordList.french.wordAt(1916)], 'fr');
    expectMarked(tester, ['English', WordList.english.wordAt(1916)], 'en');
    handle.dispose();
  });

  testWidgets('chips of a multi-list input carry each chip\'s own list',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: WordInput(
            wordCount: 8,
            lists: WordList.shipped,
            onWordsChanged: (_) {},
          ),
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField).first, 'aban');
    await tester.pumpAndSettle();
    expectMarked(tester, ['abandon'], 'en');
    handle.dispose();
  });
}
