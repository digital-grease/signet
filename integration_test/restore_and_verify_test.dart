// The whole app on a real device: restore a bulk backup made by Signet
// 0.3.6 through the UI, then verify both contacts with words computed
// from the backup's known secrets. Real secure storage, real plugins.
// Runs in CI on an emulator (.github/workflows/instrumented-tests.yml).
//
// Run with:
//   flutter test integration_test/restore_and_verify_test.dart -d <device-id>

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signet/app.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/totp_words.dart';
import 'package:signet/core/prefs/app_prefs.dart';
import 'package:signet/core/prefs/settings_controller.dart';

// The v0.3.6 bulk backup fixture from test/crypto/transport_package_test.dart:
// Mom (role A, secret 0..31) and Jürgen (role B, secret 255-i).
const _wire =
    'signet:tp1:AQMAAAAAahzLgEc3Vn_XdLnoPuUca7An0tWpcsvZlMOCYlinzlGfEXA7fBQVTWNxGdsDI_9n-yQCAscmOvOH6Ub5j9mdBb-JArp4wtf7_oz_n4SU_HHitbbHTbVqh98gUNkhARdqNXj4r86qPK4zicITB8-lF65m6GIwSyu7qpl0jqMUfIrdJA';
const _pake = [
  'abandon', 'ability', 'able', 'about', //
  'above', 'absent', 'absorb', 'abstract',
];
final _momSecret = List<int>.generate(32, (i) => i);
final _jurgenSecret = List<int>.generate(32, (i) => 255 - i);

/// Pumps frames until [finder] matches, or fails after [timeout]. The
/// verify screen's countdown never settles, so pumpAndSettle cannot be used.
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  final shown = [
    for (final e in find.byType(EditableText).evaluate())
      (e.widget as EditableText).controller.text,
    for (final e in find.byType(RichText).evaluate())
      (e.widget as RichText).text.toPlainText(),
  ].where((t) => t.isNotEmpty).join(' | ');
  fail('timed out waiting for $finder; on screen: $shown');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Types [words] into the visible word slots, one per slot, each ended
/// with a space as a user ends a word: a word that is also the start of
/// longer ones ("can", "canal") waits for that confirmation.
Future<void> _typeWords(WidgetTester tester, List<String> words) async {
  for (var i = 0; i < words.length; i++) {
    final slot = find.bySemanticsLabel(
        RegExp('^Word ${i + 1} of ${words.length}'));
    await _waitFor(tester, slot);
    await tester.ensureVisible(slot.first);
    await tester.enterText(
        find.descendant(of: slot.first, matching: find.byType(EditableText))
            .first,
        '${words[i]} ');
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<List<String>> _peerWords(List<int> secret, PairRole peerRole) =>
    TotpWords.generate(
      secret: secret,
      unixTimeSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      senderRole: peerRole,
    );

Future<void> _verify(
  WidgetTester tester, {
  required String label,
  required List<String> words,
  required String expectBanner,
}) async {
  await _tap(tester, find.text(label));
  await _typeWords(tester, words);
  await _waitFor(tester, find.text(expectBanner));
  // System back, as a user would: the verify screen's PopScope sends it home.
  await tester.binding.handlePopRoute();
  await _waitFor(tester, find.text('RELATIONSHIPS //'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await const FlutterSecureStorage(
      aOptions: AndroidOptions(
        resetOnError: false,
        preferencesKeyPrefix: 'signet_v1',
      ),
    ).deleteAll();
    final sp = await SharedPreferences.getInstance();
    await sp.clear();
  });

  testWidgets('restore a 0.3.6 bulk backup, then verify both contacts',
      (tester) async {
    final semantics = tester.ensureSemantics();
    Cryptography.instance = DartCryptography.defaultInstance;
    final prefs = await AppPrefs.load();
    await prefs.setOnboardingCompleted(true);
    await tester.pumpWidget(ProviderScope(
      overrides: [appPrefsProvider.overrideWithValue(prefs)],
      child: SignetApp(prefs: prefs),
    ));

    // Restore through the UI.
    await _tap(tester, find.text('RESTORE FROM BACKUP'));
    await _waitFor(tester, find.text('RESTORE BACKUP'));
    await tester.enterText(find.byType(TextField).first, _wire);
    await tester.pump(const Duration(milliseconds: 300));
    await _typeWords(tester, _pake);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _tap(tester, find.text('UNLOCK BACKUP'));
    await _tap(tester, find.text('RESTORE 2'));
    await _waitFor(tester, find.text('RESTORED'));
    await _tap(tester, find.text('DONE'));

    await _waitFor(tester, find.text('RELATIONSHIPS //'));
    expect(find.text('Mom'), findsOneWidget);
    expect(find.text('Jürgen'), findsOneWidget);

    // This phone is Mom-relationship role A, so Mom's phone sends with B;
    // for Jürgen this phone is B and his phone sends with A.
    await _verify(tester,
        label: 'Mom',
        words: await _peerWords(_momSecret, PairRole.b),
        expectBanner: 'VERIFIED');
    await _verify(tester,
        label: 'Jürgen',
        words: await _peerWords(_jurgenSecret, PairRole.a),
        expectBanner: 'VERIFIED');
    // Jürgen's words are wrong for Mom.
    await _verify(tester,
        label: 'Mom',
        words: await _peerWords(_jurgenSecret, PairRole.a),
        expectBanner: 'NOT VERIFIED — BE SUSPICIOUS');
    semantics.dispose();
  });
}
