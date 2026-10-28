// zh-1 display (v0.5.0 plan Task 3.3): a script setting, a reading line
// under each word, both scripts on confirm screens, the glyph locale on
// word text, and 2x text.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show LocaleStringAttribute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signet/core/crypto/wordlists.dart';
import 'package:signet/core/crypto/zh_wordlist.dart';
import 'package:signet/core/prefs/app_prefs.dart';
import 'package:signet/core/prefs/settings_controller.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/features/pairing/in_person_pairing_controller.dart';
import 'package:signet/features/pairing/pair_confirm_screen.dart';
import 'package:signet/features/settings/settings_screen.dart';
import 'package:signet/l10n/app_localizations.dart';
import 'package:signet/shared/word_semantics.dart';

import '../support/fake_secure_store.dart';
import '../support/in_person_pairing.dart';
import '../support/test_prefs.dart';

final _apple = zhWordlist.indexWhere((w) => w.simplified == '苹果');
final _myna = zhWordlist.indexWhere((w) => w.simplified == '八哥');

void _traditional(bool on) {
  WordList.showTraditionalChinese = on;
  addTearDown(() => WordList.showTraditionalChinese = false);
}

Future<void> _word(WidgetTester tester, String word,
    {bool bothScripts = false}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: WordText(word,
          list: WordList.zh1,
          style: const TextStyle(fontSize: 30),
          bothScripts: bothScripts),
    ),
  ));
}

void main() {
  group('the script is a display setting of zh-1', () {
    test('simplified by default', () {
      expect(WordList.zh1.wordAt(_apple), '苹果');
      expect(WordList.zh1.languageTag, 'zh-Hans-CN');
      expect(WordList.zh1.endonym, '中文（普通话）');
      expect(WordList.zh1.otherScriptWords![_apple], '蘋果');
    });

    test('traditional when set; lookup and indices unchanged', () {
      _traditional(true);
      expect(WordList.zh1.wordAt(_apple), '蘋果');
      expect(WordList.zh1.languageTag, 'zh-Hant-TW');
      expect(WordList.zh1.endonym, '中文（國語）');
      expect(WordList.zh1.otherScriptWords![_apple], '苹果');
      expect(WordList.zh1.indexOf('苹果'), _apple);
      expect(WordList.zh1.indexOf('蘋果'), _apple);
      expect(WordList.zh1.id, 'zh-1');
      // Latin lists have one script.
      expect(WordList.english.otherScriptWords, isNull);
      expect(WordList.french.wordAt(0), WordList.french.words.first);
    });
  });

  group('the default script follows the device', () {
    Future<AppPrefs> fresh([Map<String, Object> v = const {}]) async {
      SharedPreferences.setMockInitialValues(v);
      return AppPrefs.load();
    }

    test('traditional for zh-Hant, zh-TW, zh-HK; simplified otherwise',
        () async {
      final prefs = await fresh();
      const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
      expect(prefs.zhTraditional(const [hant]), isTrue);
      expect(prefs.zhTraditional(const [Locale('zh', 'TW')]), isTrue);
      expect(prefs.zhTraditional(const [Locale('zh', 'HK')]), isTrue);
      expect(prefs.zhTraditional(const [Locale('zh', 'CN')]), isFalse);
      expect(prefs.zhTraditional(const [Locale('en', 'US')]), isFalse);
      expect(prefs.zhTraditional(const [Locale('en'), Locale('zh', 'TW')]),
          isTrue);
    });

    test('a stored choice wins', () async {
      final prefs = await fresh({'signet.zh_script': 'hans'});
      expect(prefs.zhTraditional(const [Locale('zh', 'TW')]), isFalse);
    });

    test('the provider writes the choice and the list follows', () async {
      final prefs = await fresh();
      final container = ProviderContainer(
          overrides: [appPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(container.dispose);
      addTearDown(() => WordList.showTraditionalChinese = false);
      await container.read(zhTraditionalProvider.notifier).set(true);
      expect(WordList.zh1.wordAt(_apple), '蘋果');
      expect(prefs.zhTraditional(const []), isTrue);
    });
  });

  group('WordText', () {
    testWidgets('a reading line under the word: pinyin with simplified',
        (tester) async {
      await _word(tester, '苹果');
      expect(find.text('苹果'), findsOneWidget);
      expect(find.text(zhWordlist[_apple].pinyin), findsOneWidget);
    });

    testWidgets('Zhuyin with traditional', (tester) async {
      _traditional(true);
      await _word(tester, '蘋果');
      expect(find.text(zhWordlist[_apple].zhuyin), findsOneWidget);
    });

    testWidgets('screen readers hear the word, not the reading line',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _word(tester, '苹果');
      expect(find.bySemanticsLabel('苹果'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('píng')), findsNothing);
      handle.dispose();
    });

    testWidgets('the glyph locale is on the word', (tester) async {
      await _word(tester, '苹果');
      final text = tester.widget<Text>(find.text('苹果'));
      expect(text.style!.locale!.scriptCode, 'Hans');
    });

    testWidgets('both scripts for confirm screens, once when they match',
        (tester) async {
      await _word(tester, '苹果', bothScripts: true);
      expect(find.text('苹果 · 蘋果'), findsOneWidget);
      expect(find.text(zhWordlist[_apple].pinyin), findsOneWidget);
      await _word(tester, '八哥', bothScripts: true);
      expect(find.text(zhWordlist[_myna].simplified), findsOneWidget);
    });
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('a zh-1 pairing confirm shows both scripts, at ${scale}x',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = ProviderContainer(overrides: [
        testInPersonPhrase,
        secureStoreProvider.overrideWithValue(FakeSecureStore()),
        appPrefsProvider.overrideWithValue(await testPrefs()),
      ]);
      addTearDown(container.dispose);
      container
          .read(inPersonPairingControllerProvider.notifier)
          .setLabel('妈妈', wordList: WordList.zh1);
      await tester.runAsync(() => driveToConfirm(container));
      final phrase = container.read(inPersonPairingControllerProvider).phrase!;
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: GoRouter(
            initialLocation: '/c',
            routes: <RouteBase>[
              GoRoute(path: '/c', builder: (_, _) => const PairConfirmScreen()),
              GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final w in WordList.zh1.respell(phrase)) {
        final i = WordList.zh1.indexOf(w)!;
        final t = zhWordlist[i].traditional;
        final shown = w == t ? w : '$w · $t';
        expect(find.text(shown), findsOneWidget, reason: shown);
      }
      await tester.scrollUntilVisible(find.text('It matches'), 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('It matches').hitTestable(), findsOneWidget);
    });
  }

  testWidgets('Settings offers the script only when Chinese is built in',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appPrefsProvider.overrideWithValue(await testPrefs()),
        secureStoreProvider.overrideWithValue(FakeSecureStore()),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: SettingsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('CHINESE CHARACTERS', skipOffstage: false),
        WordList.chineseEnabled ? findsOneWidget : findsNothing);
  });

  group('screen readers (plan Task 3.4)', () {
    Future<List<String>> tags(WidgetTester tester, String word) async {
      await _word(tester, word);
      final label = tester
          .getSemantics(find.bySemanticsLabel(word))
          .getSemanticsData()
          .attributedLabel;
      return [
        for (final a in label.attributes)
          if (a is LocaleStringAttribute) a.locale.toLanguageTag(),
      ];
    }

    testWidgets('simplified words are read as zh-Hans-CN', (tester) async {
      final handle = tester.ensureSemantics();
      expect(await tags(tester, '苹果'), ['zh-Hans-CN']);
      handle.dispose();
    });

    testWidgets('traditional words are read as zh-Hant-TW', (tester) async {
      final handle = tester.ensureSemantics();
      _traditional(true);
      expect(await tags(tester, '蘋果'), ['zh-Hant-TW']);
      handle.dispose();
    });
  });
}
