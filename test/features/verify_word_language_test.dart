// Verify and word languages (v0.5.0 plan Task 1.6, word-language spike §4):
// only the contact's list can pass; another list's words are accepted as
// input so that, under a NOT VERIFIED, a note can say the words would be
// right in that language. The note needs the secret: wrong or reflected
// words get a plain NOT VERIFIED.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/totp_words.dart';
import 'package:signet/core/crypto/wordlists.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/prefs/settings_controller.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/core/storage/secure_store.dart';
import 'package:signet/features/pairing/in_person_pairing_controller.dart';
import 'package:signet/features/pairing/pair_confirm_screen.dart';
import 'package:signet/features/verify/verify_screen.dart';
import 'package:signet/features/verify/word_input.dart';
import 'package:signet/l10n/app_localizations.dart';

import '../support/fake_secure_store.dart';
import '../support/in_person_pairing.dart';
import '../support/test_prefs.dart';

const _t = 1735776000;
final _secret = List<int>.generate(32, (i) => i * 7 + 2);
Relationship _contact(String language) => Relationship(
      id: 'abc',
      label: 'Mom',
      pairedAt: DateTime.utc(2026, 4, 16),
      role: PairRole.a,
      wordLanguage: language,
    );

const _fail = 'NOT VERIFIED — BE SUSPICIOUS';
const _note = 'only when read in';

Future<FakeSecureStore> _open(WidgetTester tester, Relationship r) async {
  final store = FakeSecureStore(seeded: r, secret: _secret);
  store.now = () => DateTime.fromMillisecondsSinceEpoch(_t * 1000, isUtc: true);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(store),
      appPrefsProvider.overrideWithValue(await testPrefs()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: VerifyScreen(
          relationshipId: r.id, unixTimeSecondsProvider: () => _t),
    ),
  ));
  await tester.pumpAndSettle();
  return store;
}

/// Types each word and confirms it with a space, as a person would for a
/// word that does not auto-advance.
Future<void> _type(WidgetTester tester, List<String> words) async {
  for (var i = 0; i < words.length; i++) {
    await tester.enterText(find.byType(TextField).at(i), '${words[i]} ');
    await tester.pumpAndSettle();
  }
}

Future<List<String>> _words(WordList list, {PairRole? role, List<int>? secret}) =>
    TotpWords.generate(
      secret: secret ?? _secret,
      unixTimeSeconds: _t,
      senderRole: role ?? PairRole.b, // the counterparty of role a
      list: list,
    );

void main() {
  testWidgets('right words in French for an English contact: NOT VERIFIED '
      'with the note', (tester) async {
    await _open(tester, _contact('en'));
    await _type(tester, await _words(WordList.french));
    expect(find.text(_fail), findsOneWidget);
    expect(find.text('VERIFIED'), findsNothing);
    expect(find.textContaining('$_note Français'), findsOneWidget);
    expect(find.textContaining("Mom's words on this phone are in English"),
        findsOneWidget);
  });

  testWidgets('right words in English for a French contact: the note names '
      'English', (tester) async {
    await _open(tester, _contact('fr'));
    await _type(tester, await _words(WordList.english));
    expect(find.text(_fail), findsOneWidget);
    expect(find.textContaining('$_note English'), findsOneWidget);
  });

  testWidgets('the right words in the contact\'s own language still pass',
      (tester) async {
    await _open(tester, _contact('fr'));
    await _type(tester, await _words(WordList.french));
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.textContaining(_note), findsNothing);
  });

  testWidgets('French words without the secret: plain NOT VERIFIED',
      (tester) async {
    await _open(tester, _contact('en'));
    await _type(tester,
        await _words(WordList.french, secret: List<int>.filled(32, 9)));
    expect(find.text(_fail), findsOneWidget);
    expect(find.textContaining(_note), findsNothing);
  });

  testWidgets('our own words reflected back in French: no note',
      (tester) async {
    await _open(tester, _contact('en'));
    await _type(tester, await _words(WordList.french, role: PairRole.a));
    expect(find.text(_fail), findsOneWidget);
    expect(find.textContaining(_note), findsNothing);
  });

  testWidgets('words mixing two languages are never checked',
      (tester) async {
    await _open(tester, _contact('en'));
    final fr = await _words(WordList.french);
    final en = await _words(WordList.english);
    await _type(tester, [en[0], fr[1], fr[2], fr[3]]);
    expect(find.text(_fail), findsNothing);
    expect(find.text('VERIFIED'), findsNothing);
  });

  testWidgets('a typo that is a French word shows a hint and is not checked',
      (tester) async {
    await _open(tester, _contact('en'));
    // "baron" (French) for "bacon": a genuine caller must not get a red
    // result for the verifier's typo.
    await _type(tester, ['zebra', 'zebra', 'zebra', 'baron']);
    expect(find.text(_fail), findsNothing);
    expect(find.text("A Français word. This contact's words are in English."),
        findsOneWidget);
    final check = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'CHECK THE WORDS'));
    expect(check.onPressed, isNull);
  });

  testWidgets('once a French word is in, an English word that starts a '
      'French one waits instead of cutting it in half', (tester) async {
    await _open(tester, _contact('en'));
    await tester.enterText(find.byType(TextField).first, 'élève ');
    await tester.pumpAndSettle();
    // "absurd" is English and starts French "absurde".
    await tester.enterText(find.byType(TextField).at(1), 'absurd');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).at(1))
        .focusNode!.hasFocus, isTrue);
    await tester.enterText(find.byType(TextField).at(1), 'absurde');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).at(1))
        .controller!.text, 'absurde');
  });

  testWidgets('no "not a valid word" flash while typing a French word',
      (tester) async {
    await _open(tester, _contact('en'));
    // "tréso" starts French "trésor" and no English word.
    await tester.enterText(find.byType(TextField).first, 'tréso');
    await tester.pumpAndSettle();
    expect(find.text('Not a valid word'), findsNothing);
  });

  testWidgets('another language\'s word does not auto-advance and is never a '
      'chip; the contact\'s words advance as before', (tester) async {
    await _open(tester, _contact('en'));
    // Typing a French word: no chip offers it, and focus stays put.
    await tester.enterText(find.byType(TextField).first, 'élè');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, 'élève'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'élève');
    await tester.pumpAndSettle();
    final first = tester.widget<TextField>(find.byType(TextField).first);
    expect(first.focusNode!.hasFocus, isTrue);
    // A space confirms it and moves on.
    await tester.enterText(find.byType(TextField).first, 'élève ');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).at(1))
        .focusNode!.hasFocus, isTrue);
    // An English word that is not a prefix still auto-advances.
    await tester.enterText(find.byType(TextField).at(1), 'zebra');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).at(2))
        .focusNode!.hasFocus, isTrue);
  });

  testWidgets('old-pairing words in the old pairing\'s language get the '
      'old-pairing note', (tester) async {
    final oldSecret = List<int>.generate(32, (i) => 200 - i);
    final store = await _open(tester, _contact('en'));
    store.previous['abc'] = PreviousPairing(
      secret: Uint8List.fromList(oldSecret),
      role: PairRole.b,
      savedAt: DateTime.utc(2025, 1, 1, 12),
      wordLanguage: 'fr',
    );
    await _type(
        tester,
        await _words(WordList.french,
            role: PairRole.a, secret: oldSecret));
    expect(find.text(_fail), findsOneWidget);
    expect(find.textContaining('before a rekey'), findsOneWidget);
  });

  testWidgets('old-pairing words in another language than recorded still '
      'get the note', (tester) async {
    final oldSecret = List<int>.generate(32, (i) => 100 + i);
    final store = await _open(tester, _contact('en'));
    store.previous['abc'] = PreviousPairing(
      secret: Uint8List.fromList(oldSecret),
      role: PairRole.b,
      savedAt: DateTime.utc(2025, 1, 1, 12),
      wordLanguage: 'zh-9',
    );
    await _type(
        tester,
        await _words(WordList.french, role: PairRole.a, secret: oldSecret));
    expect(find.text(_fail), findsOneWidget);
    expect(find.textContaining('before a rekey'), findsOneWidget);
  });

  testWidgets('WordInput without alsoAccept still refuses other lists',
      (tester) async {
    List<String>? got;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: WordInput(
          lists: [WordList.english],
          onWordsChanged: (w) => got = w,
        ),
      ),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.enterText(find.byType(TextField).at(i), 'élève ');
      await tester.pumpAndSettle();
    }
    expect(got, isNull);
  });

  testWidgets('the pairing mismatch dialog says to check the language first',
      (tester) async {
    final container = ProviderContainer(overrides: [
      testInPersonPhrase,
      secureStoreProvider.overrideWithValue(FakeSecureStore()),
      appPrefsProvider.overrideWithValue(await testPrefs()),
    ]);
    addTearDown(container.dispose);
    container.read(inPersonPairingControllerProvider.notifier).setLabel('Mom');
    await tester.runAsync(() => driveToConfirm(container));
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
    await tester.ensureVisible(find.text('No match — start over'));
    await tester.tap(find.text('No match — start over'));
    await tester.pumpAndSettle();
    expect(find.textContaining('same word language above the phrase'),
        findsOneWidget);
    // Still no way to accept the mismatch.
    expect(find.text('Cancel'), findsOneWidget);
  });
}
