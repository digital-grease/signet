// WordInput with several word lists (plan Task 8.4c): the 8-word PAKE
// inputs accept French words, accented or not, and report them in the
// list's own spelling; Verify (the default) stays English only.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/wordlists.dart';
import 'package:signet/features/verify/word_input.dart';
import 'package:signet/l10n/app_localizations.dart';

void main() {
  const english = <String>[
    'abandon', 'ability', 'able', 'about', //
    'above', 'absent', 'absorb', 'abstract',
  ];
  final french = [
    for (final w in english) WordList.french.wordAt(WordList.english.indexOf(w)!),
  ];

  Widget host({
    required ValueChanged<List<String>?> onWordsChanged,
    List<WordList> lists = const <WordList>[],
    int wordCount = 8,
  }) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: WordInput(
              wordCount: wordCount,
              lists: lists,
              autofocus: false,
              onWordsChanged: onWordsChanged,
            ),
          ),
        ),
      );

  Finder slot(int i) => find.byType(TextField).at(i);
  List<String> chips(WidgetTester tester) => [
        for (final c in tester.widgetList<ActionChip>(find.byType(ActionChip)))
          (c.label as Text).data!,
      ];

  testWidgets('French words typed without accents report the French spelling',
      (tester) async {
    List<String>? reported;
    await tester.pumpWidget(host(
      lists: WordList.shipped,
      onWordsChanged: (w) => reported = w,
    ));
    for (var i = 0; i < 8; i++) {
      await tester.enterText(slot(i), WordList.french.fold(french[i])!);
      await tester.pump();
    }
    expect(reported, french);
    expect(find.text(
      AppLocalizations.of(tester.element(slot(0))).wordInputInvalidWordError,
    ), findsNothing);
  });

  testWidgets('a pasted French phrase fills every slot', (tester) async {
    List<String>? reported;
    await tester.pumpWidget(host(
      lists: WordList.shipped,
      onWordsChanged: (w) => reported = w,
    ));
    await tester.enterText(slot(0), french.join(' '));
    await tester.pump();
    expect(reported, french);
  });

  testWidgets('chips follow the language of the words typed so far',
      (tester) async {
    await tester.pumpWidget(host(
      lists: WordList.shipped,
      onWordsChanged: (_) {},
    ));
    await tester.enterText(slot(1), 'ab');
    await tester.pump();
    final before = chips(tester);
    expect(before, contains('abandon')); // English and French both start here
    // A French-only word in the first slot switches the chips to French.
    await tester.enterText(slot(0), 'abeille');
    await tester.pump();
    await tester.enterText(slot(1), 'ab');
    await tester.pump();
    final after = chips(tester);
    expect(after, isNotEmpty);
    expect(after.every(WordList.french.contains), isTrue, reason: '$after');
    expect(after, isNot(contains('ability')));
  });

  testWidgets('accented chips are offered for an accent-free prefix',
      (tester) async {
    await tester.pumpWidget(host(
      lists: WordList.shipped,
      onWordsChanged: (_) {},
    ));
    await tester.enterText(slot(0), 'elev');
    await tester.pump();
    expect(chips(tester), contains('élève'));
  });

  /// Types [word] into [index] one letter at a time, as a keyboard would,
  /// and returns whether that slot kept focus until the last letter.
  Future<bool> typeLetters(WidgetTester tester, int index, String word) async {
    for (var n = 1; n <= word.length; n++) {
      await tester.enterText(slot(index), word.substring(0, n));
      await tester.pump();
      final focused =
          tester.widget<TextField>(slot(index)).focusNode!.hasFocus;
      if (n < word.length && !focused) return false;
    }
    return true;
  }

  // A word that is the start of a longer word of ANY accepted list must
  // wait: "absurd" (English) on the way to "absurde" (French), "futur"
  // (French) on the way to "future" (English). Review finding 2026-10-20.
  for (final (typed, longer) in [
    ('absurde', 'absurd'),
    ('aboutir', 'about'),
    ('future', 'futur'),
    ('volcano', 'volcan'),
  ]) {
    testWidgets('typing "$typed" letter by letter is not cut off at "$longer"',
        (tester) async {
      List<String>? reported;
      await tester.pumpWidget(host(
        lists: WordList.shipped,
        onWordsChanged: (w) => reported = w,
      ));
      await tester.tap(slot(0));
      await tester.pump();
      expect(await typeLetters(tester, 0, typed), isTrue);
      expect(
        tester.widget<TextField>(slot(0)).controller!.text,
        WordList.french.fold(typed),
      );
      expect(tester.widget<TextField>(slot(1)).controller!.text, isEmpty);
      expect(reported, isNull);
    });
  }

  testWidgets('a half-typed word does not narrow the chips to one language',
      (tester) async {
    await tester.pumpWidget(host(
      lists: WordList.shipped,
      onWordsChanged: (_) {},
    ));
    await tester.tap(slot(0));
    await tester.pump();
    await typeLetters(tester, 0, 'absurd');
    // English "absurd" is still on its way to French "absurde".
    expect(chips(tester), contains('absurde'));
  });

  testWidgets('a confirmed accent-free word shows its own spelling',
      (tester) async {
    await tester.pumpWidget(host(
      lists: WordList.shipped,
      onWordsChanged: (_) {},
    ));
    await tester.tap(slot(0));
    await tester.pump();
    await typeLetters(tester, 0, 'abeille');
    await typeLetters(tester, 1, 'eleve ');
    expect(tester.widget<TextField>(slot(1)).controller!.text, 'élève');
  });

  testWidgets('a prefix word confirmed with a space shows its own spelling',
      (tester) async {
    // An accented French word that starts a longer word, so only the space
    // (not auto-confirm) can confirm it.
    final foldedAll = [
      for (final l in WordList.shipped) ...l.words.map(l.fold),
    ];
    final word = WordList.french.words.firstWhere((w) {
      final f = WordList.french.fold(w)!;
      return w != f && foldedAll.any((o) => o != f && o!.startsWith(f));
    });
    await tester.pumpWidget(host(
      lists: WordList.shipped,
      onWordsChanged: (_) {},
    ));
    await tester.tap(slot(0));
    await tester.pump();
    await typeLetters(tester, 0, '${WordList.french.fold(word)!} ');
    expect(tester.widget<TextField>(slot(0)).controller!.text, word);
  });

  testWidgets('after a French word, a word starting an English one still waits',
      (tester) async {
    await tester.pumpWidget(host(
      lists: WordList.shipped,
      onWordsChanged: (_) {},
    ));
    await tester.tap(slot(0));
    await tester.pump();
    await typeLetters(tester, 0, 'abeille');
    // French "volcan" is the start of English "volcano".
    expect(await typeLetters(tester, 1, 'volcano'), isTrue);
    expect(tester.widget<TextField>(slot(2)).controller!.text, isEmpty);
  });

  testWidgets('a word no other word starts with still moves on by itself',
      (tester) async {
    await tester.pumpWidget(host(
      lists: WordList.shipped,
      onWordsChanged: (_) {},
    ));
    await tester.tap(slot(0));
    await tester.pump();
    await typeLetters(tester, 0, 'abeille');
    expect(tester.widget<TextField>(slot(1)).focusNode!.hasFocus, isTrue);
  });

  testWidgets('Verify (English only by default) refuses French words',
      (tester) async {
    List<String>? reported = const ['unset'];
    await tester.pumpWidget(host(
      wordCount: 4,
      onWordsChanged: (w) => reported = w,
    ));
    for (var i = 0; i < 4; i++) {
      await tester.enterText(slot(i), 'élève');
      await tester.pump();
    }
    expect(reported, isNull);
  });

  testWidgets('Verify reports an accented English word in English spelling',
      (tester) async {
    List<String>? reported;
    await tester.pumpWidget(host(
      wordCount: 4,
      onWordsChanged: (w) => reported = w,
    ));
    for (final (i, w) in ['ábandon', 'ability', 'able', 'about'].indexed) {
      await tester.enterText(slot(i), w);
      await tester.pump();
    }
    expect(reported, ['abandon', 'ability', 'able', 'about']);
  });
}
