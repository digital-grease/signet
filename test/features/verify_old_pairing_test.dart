// Words from the pairing a rekey replaced (plan Task 3.10, R3): always a
// NOT VERIFIED result, with a note that points at an unfinished rekey but
// never reassures (a thief holding the old phone produces the same words).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/totp_words.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/core/storage/secure_store.dart';
import 'package:signet/features/verify/verify_screen.dart';
import 'package:signet/l10n/app_localizations.dart';

import '../support/fake_secure_store.dart';

const _t = 1735776000;
final _mom = Relationship(
  id: 'abc',
  label: 'Mom',
  pairedAt: DateTime.utc(2026, 4, 16),
  role: PairRole.b, // role after the rekey
);
final _newSecret = List<int>.generate(32, (i) => i + 1);
final _oldSecret = List<int>.generate(32, (i) => 200 - i);
const _oldRole = PairRole.a; // our role before the rekey

void main() {
  late FakeSecureStore store;

  setUp(() {
    store = FakeSecureStore(seeded: _mom, secret: _newSecret);
    store.now = () => DateTime.fromMillisecondsSinceEpoch(_t * 1000,
        isUtc: true);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [secureStoreProvider.overrideWithValue(store)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: VerifyScreen(
          relationshipId: 'abc',
          unixTimeSecondsProvider: () => _t,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, List<String> words) async {
    for (var i = 0; i < words.length; i++) {
      await tester.enterText(find.byType(TextField).at(i), words[i]);
      await tester.pumpAndSettle();
    }
  }

  void seedOld({DateTime? savedAt}) {
    store.previous['abc'] = PreviousPairing(
      secret: Uint8List.fromList(_oldSecret),
      role: _oldRole,
      savedAt: savedAt ?? DateTime.utc(2025, 1, 1, 12),
    );
  }

  Future<List<String>> oldPairingWords() => TotpWords.generate(
        secret: _oldSecret,
        unixTimeSeconds: _t,
        senderRole: _oldRole.other,
      );

  testWidgets('words from the old pairing: NOT VERIFIED, with the note',
      (tester) async {
    seedOld();
    await open(tester);
    await type(tester, await oldPairingWords());
    expect(find.text('NOT VERIFIED — BE SUSPICIOUS'), findsOneWidget);
    expect(find.textContaining('before a rekey'), findsOneWidget);
    expect(find.textContaining('treat this call as a scam'), findsOneWidget);
    expect(find.text('VERIFIED'), findsNothing);
  });

  testWidgets('with no old pairing kept, the same words get no note',
      (tester) async {
    await open(tester);
    await type(tester, await oldPairingWords());
    expect(find.textContaining('before a rekey'), findsNothing);
  });

  testWidgets('an old pairing past 7 days is ignored', (tester) async {
    seedOld(savedAt: DateTime.utc(2024, 12, 20));
    await open(tester);
    await type(tester, await oldPairingWords());
    expect(find.textContaining('before a rekey'), findsNothing);
    expect(store.previous, isEmpty);
  });

  testWidgets('the first pass on the new secret forgets the old one',
      (tester) async {
    seedOld();
    await open(tester);
    await type(
        tester,
        await TotpWords.generate(
            secret: _newSecret, unixTimeSeconds: _t, senderRole: _mom.role.other));
    await tester.pumpAndSettle();
    expect(store.previous, isEmpty);
  });

  testWidgets('a stranger\'s words get no note', (tester) async {
    seedOld();
    await open(tester);
    await type(tester, const <String>['abandon', 'ability', 'able', 'about']);
    expect(find.textContaining('before a rekey'), findsNothing);
  });

  testWidgets(
      'a storage error in the old-pairing check still shows the red result',
      (tester) async {
    store.failPreviousPairing = true;
    await open(tester);
    await type(tester, await oldPairingWords());
    expect(find.text('NOT VERIFIED — BE SUSPICIOUS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'words from the old secret with OUR old role (reflected) get no note',
      (tester) async {
    seedOld();
    await open(tester);
    await type(
        tester,
        await TotpWords.generate(
            secret: _oldSecret, unixTimeSeconds: _t, senderRole: _oldRole));
    expect(find.text('NOT VERIFIED — BE SUSPICIOUS'), findsOneWidget);
    expect(find.textContaining('before a rekey'), findsNothing);
  });
}
