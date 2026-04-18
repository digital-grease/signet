import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/totp_words.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/features/verify/verify_screen.dart';
import 'package:signet/features/verify/word_input.dart';
import 'package:signet/shared/widgets/words_display.dart';

import '../support/fake_secure_store.dart';

Widget wrap({required Widget child, required FakeSecureStore store}) {
  return ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(store),
    ],
    child: MaterialApp(home: child),
  );
}

// This test harness represents *our* device (Alice). `_mom.role` is thus
// Alice's role in the pair; Mom's counterparty role is `_mom.role.other`.
final _mom = Relationship(
  id: 'abc',
  label: 'Mom',
  pairedAt: DateTime.utc(2026, 4, 16),
  role: PairRole.a,
);
final _secret = List<int>.generate(32, (i) => i + 1);

/// Words *Mom* (the counterparty) would read aloud in the current window.
/// These are what Alice should hear and type into her verify input to get ✅.
Future<List<String>> _currentWordsFromMom() async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  return TotpWords.generate(
    secret: _secret,
    unixTimeSeconds: now,
    senderRole: _mom.role.other,
  );
}

/// Words *Alice* (this device) displays in "Show my 4 words". Typing these
/// into Alice's own verify input simulates the reflection attack and must
/// produce ❌.
Future<List<String>> _currentWordsFromSelf() async {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  return TotpWords.generate(
    secret: _secret,
    unixTimeSeconds: now,
    senderRole: _mom.role,
  );
}

Finder _slotField(int index) => find.byType(TextField).at(index);

Future<void> _enterWords(WidgetTester tester, List<String> words) async {
  for (var i = 0; i < words.length; i++) {
    await tester.enterText(_slotField(i), words[i]);
    await tester.pumpAndSettle();
  }
}

void main() {
  group('VerifyScreen', () {
    testWidgets('shows the relationship label and the 4-slot word input',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          store: FakeSecureStore(seeded: _mom, secret: _secret),
          child: const VerifyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ask Mom for their 4 words.'), findsOneWidget);
      expect(find.byType(WordInput), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(4));
    });

    testWidgets('shows an error state when no relationship is paired',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          store: FakeSecureStore(),
          child: const VerifyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not read your paired contact.'), findsOneWidget);
      expect(find.text('Back to home'), findsOneWidget);
    });

    testWidgets(
      'typing the correct current-window words shows the Verified banner',
      (tester) async {
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(),
          ),
        );
        await tester.pumpAndSettle();

        final words = await _currentWordsFromMom();
        await _enterWords(tester, words);
        await tester.pumpAndSettle();

        expect(find.text('Verified'), findsOneWidget);
        expect(find.byIcon(Icons.verified), findsOneWidget);

        final hapticCalls = calls.where(
          (c) =>
              c.method == 'HapticFeedback.vibrate' &&
              (c.arguments as String?)?.contains('light') == true,
        );
        expect(hapticCalls, hasLength(1));
      },
    );

    testWidgets(
      'typing wrong 4 words shows Not verified, clears input for retry',
      (tester) async {
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(),
          ),
        );
        await tester.pumpAndSettle();

        const bogus = <String>['orange', 'anchor', 'abandon', 'ability'];
        await _enterWords(tester, bogus);
        await tester.pumpAndSettle();

        expect(find.textContaining('Not verified'), findsOneWidget);
        expect(find.byIcon(Icons.gpp_bad), findsOneWidget);

        // Input cleared after ❌.
        expect(
          tester.widget<TextField>(_slotField(0)).controller!.text,
          '',
        );

        final heavyCalls = calls.where(
          (c) =>
              c.method == 'HapticFeedback.vibrate' &&
              (c.arguments as String?)?.contains('heavy') == true,
        );
        expect(heavyCalls, hasLength(1));
      },
    );

    testWidgets(
      'after ❌, user can retry with the correct words and see Verified',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(),
          ),
        );
        await tester.pumpAndSettle();

        const bogus = <String>['orange', 'anchor', 'abandon', 'ability'];
        await _enterWords(tester, bogus);
        await tester.pumpAndSettle();
        expect(find.textContaining('Not verified'), findsOneWidget);

        final words = await _currentWordsFromMom();
        await _enterWords(tester, words);
        await tester.pumpAndSettle();

        expect(find.text('Verified'), findsOneWidget);
      },
    );

    testWidgets(
      'REFLECTION ATTACK after a prior ✅: typing our own displayed words '
      'still triggers a fresh verify that rejects them',
      (tester) async {
        // Regression for the "stale banner" bug: a successful verify was
        // locking the submit gate, so the next reflection-attack attempt
        // did nothing and the ✅ banner persisted, making the attack
        // appear to succeed. This test proves the second submit now runs.
        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1: a legitimate verify → ✅.
        final legit = await _currentWordsFromMom();
        await _enterWords(tester, legit);
        await tester.pumpAndSettle();
        expect(find.text('Verified'), findsOneWidget);

        // Step 2: reflection-attack attempt (type our OWN shown words).
        final ownWords = await _currentWordsFromSelf();
        await _enterWords(tester, ownWords);
        await tester.pumpAndSettle();
        expect(find.textContaining('Not verified'), findsOneWidget);
        expect(find.text('Verified'), findsNothing);
      },
    );

    testWidgets(
      'REFLECTION ATTACK: typing our own displayed words is rejected',
      (tester) async {
        // Simulates: "grandma, read me your words first" — Alice reads her
        // own Show-my-words aloud, attacker repeats them back, Alice types
        // them in. The ✅ would be catastrophic. Must ❌.
        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(),
          ),
        );
        await tester.pumpAndSettle();

        final ownWords = await _currentWordsFromSelf();
        await _enterWords(tester, ownWords);
        await tester.pumpAndSettle();

        expect(find.textContaining('Not verified'), findsOneWidget);
        expect(find.byIcon(Icons.gpp_bad), findsOneWidget);
      },
    );

    testWidgets('Show my words section is collapsed by default',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          store: FakeSecureStore(seeded: _mom, secret: _secret),
          child: const VerifyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Show my 4 words'), findsOneWidget);
      expect(find.byType(WordsDisplay), findsNothing);
    });

    testWidgets('tapping Show my words reveals the rotating 4-word display',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          store: FakeSecureStore(seeded: _mom, secret: _secret),
          child: const VerifyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show my 4 words'));
      await tester.pumpAndSettle();

      expect(find.byType(WordsDisplay), findsOneWidget);
      // "Show my words" renders THIS device's role — the words Mom should
      // hear from Alice, not the words Alice expects to hear from Mom.
      final expected = await _currentWordsFromSelf();
      for (final w in expected) {
        expect(find.text(w), findsWidgets);
      }
    });

    testWidgets('pasting four correct words also verifies successfully',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          store: FakeSecureStore(seeded: _mom, secret: _secret),
          child: const VerifyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final words = await _currentWordsFromMom();
      await tester.enterText(_slotField(0), words.join(' '));
      await tester.pumpAndSettle();

      expect(find.text('Verified'), findsOneWidget);
    });
  });
}
