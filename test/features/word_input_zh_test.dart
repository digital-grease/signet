// zh-1 in the word input (v0.5.0 plan Task 3.2; spike chinese-words.md §4,
// §6). The tests give the input the zh-1 list directly, so they run without
// the SIGNET_ZH build flag.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/crypto/wordlists.dart';
import 'package:signet/core/crypto/zh_input.dart';
import 'package:signet/core/crypto/zh_wordlist.dart';
import 'package:signet/features/verify/word_input.dart';
import 'package:signet/l10n/app_localizations.dart';
import 'package:signet/shared/word_semantics.dart';

int _index(String simplified) =>
    zhWordlist.indexWhere((w) => w.simplified == simplified);

Future<void> _pump(WidgetTester tester, List<WordList> lists,
    {int count = 4, void Function(List<String>?)? onWords}) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: SingleChildScrollView(
        child: WordInput(
          wordCount: count,
          lists: lists,
          onWordsChanged: onWords ?? (_) {},
        ),
      ),
    ),
  ));
}

TextField _slot(WidgetTester tester, int i) =>
    tester.widget<TextField>(find.byType(TextField).at(i));

void main() {
  final zh = WordList.zh1;

  group('ZhInput.prefixMatches', () {
    final z = ZhInput.zh1;
    test('one character, two letters, initials', () {
      expect(z.prefixMatches('苹'), contains(_index('苹果')));
      expect(z.prefixMatches('蘋'), contains(_index('苹果')));
      expect(z.prefixMatches('pingg'), contains(_index('苹果')));
      expect(z.prefixMatches('píngg'), contains(_index('苹果')));
      expect(z.prefixMatches('pg'), contains(_index('苹果')));
      expect(z.prefixMatches('p'), isEmpty);
      expect(z.prefixMatches('苹g'), isEmpty);
    });
  });

  group('ZhInput.segment', () {
    final z = ZhInput.zh1;
    final four = [_index('苹果'), _index('火车'), _index('电脑'), _index('八哥')];

    test('glued characters, either script, with CJK punctuation', () {
      expect(z.segment('苹果火车电脑八哥'), four);
      expect(z.segment('蘋果火車電腦八哥'), four);
      expect(z.segment('苹果、火车，电脑。八哥'), four);
    });

    test('pinyin, one token per word or one per syllable', () {
      expect(z.segment('pingguo huoche diannao bage'), four);
      expect(z.segment('ping guo huo che dian nao ba ge'), four);
      expect(z.segment('píng guǒ, huǒ chē'), [four[0], four[1]]);
    });

    test('random codes: the segmentation is right or there is none', () {
      var resolved = 0;
      for (var seed = 0; seed < 400; seed++) {
        final code = [for (var k = 0; k < 4; k++) (seed * 7919 + k * 104729) % 2048];
        final got = z.segment(code.map((i) => zhWordlist[i].simplified).join());
        if (got != null) {
          expect(got, code);
          resolved++;
        }
      }
      expect(resolved, greaterThan(300));
    });

    test('mixed scripts or leftovers are not a paste', () {
      expect(z.segment('苹果huoche'), isNull);
      expect(z.segment('苹果火'), isNull);
    });
  });

  testWidgets('characters and pinyin confirm and advance', (tester) async {
    List<String>? got;
    await _pump(tester, [zh], onWords: (w) => got = w);
    await tester.enterText(find.byType(TextField).at(0), '苹果');
    await tester.pumpAndSettle();
    expect(_slot(tester, 1).focusNode!.hasFocus, isTrue);
    await tester.enterText(find.byType(TextField).at(1), 'huoche');
    await tester.pumpAndSettle();
    expect(_slot(tester, 1).controller!.text, '火车');
    await tester.enterText(find.byType(TextField).at(2), 'dian4 nao3');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(3), '八哥');
    await tester.pumpAndSettle();
    expect(got, ['苹果', '火车', '电脑', '八哥']);
  });

  testWidgets('one or two syllables that start a longer word wait',
      (tester) async {
    await _pump(tester, [zh]);
    await tester.enterText(find.byType(TextField).at(0), 'bei ji');
    await tester.pumpAndSettle();
    // Not 飞机, and focus stays: 北极熊 may follow.
    expect(_slot(tester, 0).focusNode!.hasFocus, isTrue);
    expect(_slot(tester, 0).controller!.text, 'bei ji');
    await tester.enterText(find.byType(TextField).at(0), 'bei ji xiong');
    await tester.pumpAndSettle();
    expect(_slot(tester, 0).controller!.text, '北极熊');
  });

  testWidgets('chips after one character', (tester) async {
    await _pump(tester, [zh]);
    await tester.enterText(find.byType(TextField).at(0), '苹');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, '苹果'), findsOneWidget);
  });

  testWidgets('text still being composed by an input method is ignored',
      (tester) async {
    await _pump(tester, [zh]);
    final controller = _slot(tester, 0).controller!;
    await tester.showKeyboard(find.byType(TextField).first);
    // As a pinyin input method sends it: still composing.
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: 'pingguo',
      selection: TextSelection.collapsed(offset: 7),
      composing: TextRange(start: 0, end: 7),
    ));
    await tester.pumpAndSettle();
    // Nothing confirmed or rewritten while composing.
    expect(controller.text, 'pingguo');
    expect(_slot(tester, 1).focusNode!.hasFocus, isFalse);
    // Committed: now the word is read.
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: 'pingguo',
      selection: TextSelection.collapsed(offset: 7),
    ));
    await tester.pumpAndSettle();
    expect(controller.text, '苹果');
  });

  testWidgets('word fields never let the keyboard learn the words',
      (tester) async {
    await _pump(tester, [zh]);
    expect(_slot(tester, 0).enableIMEPersonalizedLearning, isFalse);
  });

  testWidgets('a glued paste fills every slot', (tester) async {
    List<String>? got;
    await _pump(tester, [zh], onWords: (w) => got = w);
    await tester.enterText(find.byType(TextField).at(0), '苹果火车电脑八哥');
    await tester.pumpAndSettle();
    expect(got, ['苹果', '火车', '电脑', '八哥']);
  });

  testWidgets('English is never a zh-1 word on a zh-1 contact', (tester) async {
    List<String>? got;
    await _pump(tester, [zh], onWords: (w) => got = w);
    for (var i = 0; i < 4; i++) {
      await tester.enterText(find.byType(TextField).at(i), 'abandon ');
      await tester.pumpAndSettle();
    }
    expect(got, isNull);
  });

  testWidgets('8 words: after an English word, pinyin is no longer a word',
      (tester) async {
    await _pump(tester, [WordList.english, WordList.french, zh], count: 8);
    await tester.enterText(find.byType(TextField).at(0), 'abandon');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'bosi');
    await tester.pumpAndSettle();
    expect(_slot(tester, 1).controller!.text, 'bosi'); // not 博士
    expect(find.text('Not a valid word'), findsOneWidget);
  });

  testWidgets('8 words: English words still auto-advance with zh-1 offered',
      (tester) async {
    await _pump(tester, [WordList.english, WordList.french, zh], count: 8);
    await tester.enterText(find.byType(TextField).at(0), 'zebra');
    await tester.pumpAndSettle();
    expect(_slot(tester, 1).focusNode!.hasFocus, isTrue);
    expect(find.byType(WordText), findsNothing);
  });

  group('seven words of one list and one odd word', () {
    const english = ['abandon', 'ability', 'able', 'about', 'above', 'absent', 'absorb'];
    Matcher refused(InvalidPakeReason reason, int? slot) =>
        throwsA(isA<InvalidPakeException>()
            .having((e) => e.reason, 'reason', reason)
            .having((e) => e.slot, 'slot', slot));

    test('a typo is named as not a word', () {
      for (final odd in ['zzzz', 'bage']) {
        // "bage" ("badge" mistyped) only reads as pinyin for 八哥.
        expect(() => TransportPackage.pakeCandidates([...english, odd]),
            refused(InvalidPakeReason.unknownWord, 8));
      }
    });

    test('a word of another list is named as another language', () {
      for (final odd in ['élève', '八哥']) {
        expect(() => TransportPackage.pakeCandidates([...english, odd]),
            refused(InvalidPakeReason.otherLanguageWord, 8));
      }
    });

    test('no slot is named when each list leaves out a different one', () {
      // Six words both lists spell alike, one English-only, one
      // French-only: either could be the odd one out.
      final shared = [
        for (final w in WordList.english.words)
          if (WordList.french.contains(w)) w,
      ].take(6).toList();
      expect(shared, hasLength(6));
      expect(
          () => TransportPackage.pakeCandidates(
              [shared[0], 'zebra', ...shared.skip(1), 'élève']),
          refused(InvalidPakeReason.mixedLanguages, null));
    });
  });

  group('Latin letters are zh-1 only once the input is Chinese '
      '(Task 3.2 review)', () {
    final all = [WordList.english, WordList.french, zh];

    testWidgets('8 words: an English typo that reads as pinyin is a typo',
        (tester) async {
      await _pump(tester, all, count: 8);
      await tester.enterText(find.byType(TextField).at(0), 'bage');
      await tester.pumpAndSettle();
      expect(_slot(tester, 0).controller!.text, 'bage'); // not 八哥
      expect(_slot(tester, 0).focusNode!.hasFocus, isTrue);
      expect(find.text('Not a valid word'), findsOneWidget);
      // Nothing locked: the next English words are fine.
      await tester.enterText(find.byType(TextField).at(0), 'badge');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'abandon');
      await tester.pumpAndSettle();
      expect(find.text('Not a valid word'), findsNothing);
    });

    testWidgets('8 words: English letters get English chips only',
        (tester) async {
      await _pump(tester, all, count: 8);
      await tester.enterText(find.byType(TextField).at(0), 'ba');
      await tester.pumpAndSettle();
      final chips = tester.widgetList<ActionChip>(find.byType(ActionChip));
      expect(chips, isNotEmpty);
      expect(chips.length, lessThanOrEqualTo(6));
      expect(
          find.descendant(
              of: find.byType(ActionChip),
              matching: find.textContaining(RegExp(r'\p{Script=Han}',
                  unicode: true))),
          findsNothing);
    });

    testWidgets('8 words: a word in characters makes pinyin count',
        (tester) async {
      await _pump(tester, all, count: 8);
      await tester.enterText(find.byType(TextField).at(0), '苹果');
      await tester.pumpAndSettle();
      expect(_slot(tester, 1).focusNode!.hasFocus, isTrue);
      await tester.enterText(find.byType(TextField).at(1), 'huoche');
      await tester.pumpAndSettle();
      expect(_slot(tester, 1).controller!.text, '火车');
    });

    testWidgets('an English contact: pinyin is not taken for a Chinese word, '
        'characters are', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: WordInput(
            lists: [WordList.english],
            alsoAccept: [WordList.french, zh],
          ),
        ),
      ));
      await tester.enterText(find.byType(TextField).at(0), 'bage ');
      await tester.pumpAndSettle();
      expect(_slot(tester, 0).controller!.text, isNot('八哥'));
      expect(find.textContaining('中文'), findsNothing);
      await tester.enterText(find.byType(TextField).at(0), '八哥 ');
      await tester.pumpAndSettle();
      expect(_slot(tester, 0).controller!.text, '八哥');
    });
  });

  group('input methods', () {
    testWidgets('a composed word confirmed by tapping another slot keeps '
        'focus where the user tapped', (tester) async {
      await _pump(tester, [WordList.english]);
      final controller = _slot(tester, 0).controller!;
      await tester.showKeyboard(find.byType(TextField).at(0));
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'zebra',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 5),
      ));
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byType(TextField).at(2));
      // Losing focus ends the composition.
      controller.value = const TextEditingValue(
        text: 'zebra',
        selection: TextSelection.collapsed(offset: 5),
      );
      await tester.pumpAndSettle();
      expect(_slot(tester, 2).focusNode!.hasFocus, isTrue);
      expect(_slot(tester, 1).focusNode!.hasFocus, isFalse);
    });

    testWidgets('chips and errors show while a keyboard composes',
        (tester) async {
      await _pump(tester, [WordList.english]);
      await tester.showKeyboard(find.byType(TextField).at(0));
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'zeb',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 0, end: 3),
      ));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ActionChip, 'zebra'), findsOneWidget);
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'zebrx',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 5),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Not a valid word'), findsOneWidget);
    });

    testWidgets('a word typed in characters never waits, even one that '
        'sounds like the start of another', (tester) async {
      await _pump(tester, [zh]);
      // 飞机 sounds like the start of 北极熊.
      await tester.enterText(find.byType(TextField).at(0), '飞机');
      await tester.pumpAndSettle();
      expect(_slot(tester, 1).focusNode!.hasFocus, isTrue);
    });

    testWidgets('a fullwidth space confirms a word', (tester) async {
      await _pump(tester, [WordList.english]);
      // "act" starts "action", so only a confirm moves on.
      await tester.enterText(find.byType(TextField).at(0), 'act\u3000');
      await tester.pumpAndSettle();
      expect(_slot(tester, 0).controller!.text, 'act');
      expect(_slot(tester, 1).focusNode!.hasFocus, isTrue);
    });

    testWidgets('Zhuyin left in a slot is not called a typo', (tester) async {
      await _pump(tester, [zh]);
      await tester.enterText(find.byType(TextField).at(0), 'ㄅㄚ');
      await tester.pumpAndSettle();
      expect(find.text('Not a valid word'), findsNothing);
      // Without zh-1 it is just not a word.
      await _pump(tester, [WordList.english]);
      await tester.enterText(find.byType(TextField).at(0), 'ㄅㄚ');
      await tester.pumpAndSettle();
      expect(find.text('Not a valid word'), findsOneWidget);
    });

    testWidgets('one character offers words that contain it anywhere',
        (tester) async {
      await _pump(tester, [zh]);
      await tester.enterText(find.byType(TextField).at(0), '哥');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ActionChip, '八哥'), findsOneWidget);
      expect(tester.widgetList(find.byType(ActionChip)).length,
          lessThanOrEqualTo(6));
    });
  });

  testWidgets('typing spaced pinyin key by key reaches a longer word',
      (tester) async {
    await _pump(tester, [zh]);
    const target = 'bei ji xiong';
    for (var n = 1; n <= target.length; n++) {
      await tester.enterText(find.byType(TextField).at(0), target.substring(0, n));
      await tester.pumpAndSettle();
    }
    expect(_slot(tester, 0).controller!.text, '北极熊');
  });

  test('huge pastes are refused quickly', () {
    final sw = Stopwatch()..start();
    expect(ZhInput.zh1.segment('苹果' * 50000), isNull);
    expect(ZhInput.zh1.segment('ping guo ' * 50000), isNull);
    expect(sw.elapsedMilliseconds, lessThan(1000));
  });
}
