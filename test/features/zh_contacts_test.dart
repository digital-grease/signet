// zh-1 contacts end to end (v0.5.0 plan Task 3.5). Tests marked
// [_needsZh] run when built with --dart-define=SIGNET_ZH=true (CI runs the
// suite both ways).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/backup_bundle.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/transport_package.dart';
import 'package:signet/core/crypto/wordlists.dart';
import 'package:signet/core/crypto/zh_wordlist.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/prefs/settings_controller.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/features/inspect/backup_export_screen.dart';
import 'package:signet/l10n/app_localizations.dart';
import 'package:signet/shared/widgets/word_language_options.dart';

import '../support/fake_secure_store.dart';
import '../support/test_prefs.dart';

const _needsZh = !WordList.chineseEnabled;

final _mama = Relationship(
  id: 'mama-id',
  label: '妈妈',
  pairedAt: DateTime.utc(2026, 1, 1),
  role: PairRole.a,
  wordLanguage: 'zh-1',
);
final _secret = List<int>.generate(32, (i) => i + 3);

void main() {
  test('zh-1 contacts get English PAKE words in v0.5.0 (D4)', () {
    expect(WordList.zh1.pakeWordList, same(WordList.english));
    expect(WordList.english.pakeWordList, same(WordList.english));
    expect(WordList.french.pakeWordList, same(WordList.french));
  });

  testWidgets('a zh-1 contact backup: English words, labelled, tag kept',
      (tester) async {
    final store = FakeSecureStore(seeded: _mama, secret: _secret);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        secureStoreProvider.overrideWithValue(store),
        appPrefsProvider.overrideWithValue(await testPrefs()),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: GoRouter(
          initialLocation: '/e',
          routes: <RouteBase>[
            GoRoute(
                path: '/e',
                builder: (_, _) => BackupExportScreen(relationshipId: _mama.id)),
            GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final wire = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .firstWhere((s) => (s.data ?? '').startsWith('signet:tp1:'))
        .data!;
    await tester.ensureVisible(find.text('I saved it another way'));
    await tester.tap(find.text('I saved it another way'));
    await tester.pumpAndSettle();
    expect(find.text('Words: English'), findsOneWidget);
    final words = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) =>
            t.style?.fontFamily == 'monospace' && t.style?.fontSize == 16)
        .take(8)
        .map((t) => t.data!)
        .toList();
    expect(words.every(WordList.english.contains), isTrue, reason: '$words');
    final decoded = await TransportPackage.decodeLpr(wire, pakeWords: words);
    expect(TransportPackage.wordListIdOf(decoded.extensions), 'zh-1');
  });

  // A v0.5.0 backup of a zh-1 contact, pinned. A build without Chinese
  // keeps the id and asks for an update; v0.4.0 drops the non-critical tag
  // and restores the contact as English.
  test('pinned v0.5.0 zh-1 backup', () async {
    const fixture = 'signet:tp1:AgIAAAAAahzLgGlxPBQuch-zFon8DR91K4_9tn_LWIBCkV'
        'Mb-eeCS_zXJ469SpuAE0nCAwa8K8Zq33i4cJTMThBcFIS440Ipdg7NfXj1zeQfAGYwcBC72'
        'saVyVHPgvZ3';
    final decoded = await TransportPackage.decodeLpr(fixture, pakeWords: const [
      'abandon', 'ability', 'able', 'about', //
      'above', 'absent', 'absorb', 'abstract',
    ]);
    expect(decoded.label, '妈妈');
    expect(TransportPackage.wordListIdOf(decoded.extensions), 'zh-1');
    final restored = _mama.copyWith(wordLanguage: 'zh-1');
    expect(restored.knownWordList,
        WordList.chineseEnabled ? same(WordList.zh1) : isNull);
  });

  group('the WORDS file reads 8 zh-1 words (read half)', () {
    final eight = [for (var i = 0; i < 8; i++) zhWordlist[i * 250]];
    final simplified = [for (final w in eight) w.simplified];

    test('glued, punctuated, traditional, numbered', () {
      for (final text in [
        simplified.join(),
        simplified.join('、'),
        '密码词：${[for (final w in eight) w.traditional].join('，')}',
        [for (var i = 0; i < 8; i++) '${i + 1}. ${simplified[i]}'].join('\n'),
      ]) {
        expect(BackupText.read(text).pakeWords,
            WordList.chineseEnabled ? simplified : isNull, reason: text);
      }
    });

    test('and they open a package', () async {
      final words = WordList.zh1.render([for (var i = 0; i < 8; i++) i * 250]);
      final english = WordList.english.render([for (var i = 0; i < 8; i++) i * 250]);
      final wire = await TransportPackage.encodeLpr(
        label: '妈妈',
        role: PairRole.a,
        pairedAt: DateTime.utc(2026, 1, 1),
        silentHaptics: false,
        sharedSecret: _secret,
        pakeWords: english,
      );
      final decoded = await TransportPackage.decodeLpr(wire, pakeWords: words);
      expect(decoded.label, '妈妈');
    }, skip: _needsZh);
  });

  testWidgets('the options offer 中文（普通话） and 中文（國語）; picking one sets '
      'the script', (tester) async {
    addTearDown(() => WordList.showTraditionalChinese = false);
    WordList? picked;
    await tester.pumpWidget(ProviderScope(
      overrides: [appPrefsProvider.overrideWithValue(await testPrefs())],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: WordLanguageOptions(
              selected: WordList.english,
              onChanged: (l) => picked = l,
            ),
          ),
        ),
      ),
    ));
    expect(find.text('中文（普通话）'), findsOneWidget);
    expect(find.text('中文（國語）'), findsOneWidget);
    await tester.tap(find.text('中文（國語）'));
    await tester.pumpAndSettle();
    expect(picked, same(WordList.zh1));
    expect(WordList.showTraditionalChinese, isTrue);
  }, skip: _needsZh);
}
