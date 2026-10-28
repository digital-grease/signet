// CJK text around pasted words (v0.5.0 plan Task 0.5): words separated by
// CJK or fullwidth punctuation, list numbers in any script, or Han labels
// are spread across the slots, and the backup WORDS text reads them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/backup_bundle.dart';
import 'package:signet/core/crypto/wordlists.dart';
import 'package:signet/features/verify/word_input.dart';
import 'package:signet/l10n/app_localizations.dart';

const _four = ['abandon', 'ability', 'able', 'about'];
const _eight = [
  'abandon', 'ability', 'able', 'about', //
  'above', 'absent', 'absorb', 'abstract',
];

void main() {
  group('WordList.splitWords', () {
    final cases = <String, List<String>>{
      'abandon、ability、able、about': _four,
      'abandon，ability，able，about': _four,
      'abandon；ability；able；about。': _four,
      '「abandon」『ability』《able》【about】': _four,
      '1. abandon 2. ability 3. able 4. about': _four,
      '一、abandon 二、ability 三、able 四、about': _four,
      '①abandon②ability③able④about': _four,
      '密码词：abandon ability able about': _four,
      '验证码abandon和ability还有able与about': _four,
      'aban​don ability able about': _four,
      'élève、cœur': ['élève', 'cœur'],
    };
    cases.forEach((text, words) {
      test(text, () => expect(WordList.splitWords(text), words));
    });
  });

  testWidgets('a CJK-punctuated paste fills all four slots', (tester) async {
    for (final paste in [
      'abandon、ability、able、about',
      'abandon, ability, able, about',
      '密码词：abandon ability able about',
    ]) {
      List<String>? got;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: WordInput(
            key: UniqueKey(),
            lists: [WordList.english],
            onWordsChanged: (w) => got = w,
          ),
        ),
      ));
      await tester.enterText(find.byType(TextField).first, paste);
      await tester.pumpAndSettle();
      expect(got, _four, reason: paste);
    }
  });

  group('backup WORDS text', () {
    test('one line with CJK separators and a Han label', () {
      expect(BackupText.read('密码词：${_eight.join('、')}').pakeWords, _eight);
      expect(BackupText.read(_eight.join('，')).pakeWords, _eight);
    });

    test('one per line with Han list numbers', () {
      const nums = ['一', '二', '三', '四', '五', '六', '七', '八'];
      final text = [
        for (var i = 0; i < 8; i++) '${nums[i]}、${_eight[i]}',
      ].join('\n');
      expect(BackupText.read(text).pakeWords, _eight);
    });

    test('a Chinese note line does not add words', () {
      final text = '这是我的备份\n${_eight.join(' ')}';
      expect(BackupText.read(text).pakeWords, _eight);
    });
  });
}
