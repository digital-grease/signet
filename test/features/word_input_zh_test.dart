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

  test('seven words of one list and one typo: the typo slot is named', () {
    const english = ['abandon', 'ability', 'able', 'about', 'above', 'absent', 'absorb'];
    for (final odd in ['élève', 'zzzz']) {
      expect(
        () => TransportPackage.pakeCandidates([...english, odd]),
        throwsA(isA<InvalidPakeException>()
            .having((e) => e.reason, 'reason', InvalidPakeReason.unknownWord)
            .having((e) => e.slot, 'slot', 8)),
      );
    }
  });
}
