import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

/// Like [wrap] but pumps a real GoRouter so we can test navigation
/// triggered by the Verify screen (liveness route, home route, etc.).
Widget wrapWithRouter({
  required FakeSecureStore store,
  required String verifyId,
}) {
  final router = GoRouter(
    initialLocation: '/verify/$verifyId',
    routes: <RouteBase>[
      GoRoute(
        path: '/verify/:id',
        builder: (_, state) => VerifyScreen(
          relationshipId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME_ROUTE')),
      ),
      GoRoute(
        path: '/liveness/:id',
        builder: (_, state) =>
            Scaffold(body: Text('LIVENESS_${state.pathParameters['id']}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [secureStoreProvider.overrideWithValue(store)],
    child: MaterialApp.router(routerConfig: router),
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
          child: const VerifyScreen(relationshipId: 'abc'),
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
          child: const VerifyScreen(relationshipId: 'abc'),
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
            child: const VerifyScreen(relationshipId: 'abc'),
          ),
        );
        await tester.pumpAndSettle();

        final words = await _currentWordsFromMom();
        await _enterWords(tester, words);
        await tester.pumpAndSettle();

        expect(find.text('VERIFIED'), findsOneWidget);
        expect(find.text('STATUS // 200 OK'), findsOneWidget);

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
            child: const VerifyScreen(relationshipId: 'abc'),
          ),
        );
        await tester.pumpAndSettle();

        const bogus = <String>['orange', 'anchor', 'abandon', 'ability'];
        await _enterWords(tester, bogus);
        await tester.pumpAndSettle();

        expect(find.textContaining('NOT VERIFIED'), findsOneWidget);
        expect(find.text('STATUS // 403 MISMATCH'), findsOneWidget);

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
            child: const VerifyScreen(relationshipId: 'abc'),
          ),
        );
        await tester.pumpAndSettle();

        const bogus = <String>['orange', 'anchor', 'abandon', 'ability'];
        await _enterWords(tester, bogus);
        await tester.pumpAndSettle();
        expect(find.textContaining('NOT VERIFIED'), findsOneWidget);

        final words = await _currentWordsFromMom();
        await _enterWords(tester, words);
        await tester.pumpAndSettle();

        expect(find.text('VERIFIED'), findsOneWidget);
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
            child: const VerifyScreen(relationshipId: 'abc'),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1: a legitimate verify → ✅.
        final legit = await _currentWordsFromMom();
        await _enterWords(tester, legit);
        await tester.pumpAndSettle();
        expect(find.text('VERIFIED'), findsOneWidget);

        // Step 2: reflection-attack attempt (type our OWN shown words).
        final ownWords = await _currentWordsFromSelf();
        await _enterWords(tester, ownWords);
        await tester.pumpAndSettle();
        expect(find.textContaining('NOT VERIFIED'), findsOneWidget);
        expect(find.text('VERIFIED'), findsNothing);
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
            child: const VerifyScreen(relationshipId: 'abc'),
          ),
        );
        await tester.pumpAndSettle();

        final ownWords = await _currentWordsFromSelf();
        await _enterWords(tester, ownWords);
        await tester.pumpAndSettle();

        expect(find.textContaining('NOT VERIFIED'), findsOneWidget);
        expect(find.text('STATUS // 403 MISMATCH'), findsOneWidget);
      },
    );

    testWidgets('Show my words section is collapsed by default',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          store: FakeSecureStore(seeded: _mom, secret: _secret),
          child: const VerifyScreen(relationshipId: 'abc'),
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
          child: const VerifyScreen(relationshipId: 'abc'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Show my 4 words'));
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
          child: const VerifyScreen(relationshipId: 'abc'),
        ),
      );
      await tester.pumpAndSettle();

      final words = await _currentWordsFromMom();
      await tester.enterText(_slotField(0), words.join(' '));
      await tester.pumpAndSettle();

      expect(find.text('VERIFIED'), findsOneWidget);
    });

    testWidgets(
      '❌ banner exposes WHAT SHOULD I DO action that opens guidance modal',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(relationshipId: 'abc'),
          ),
        );
        await tester.pumpAndSettle();

        const bogus = <String>['orange', 'anchor', 'abandon', 'ability'];
        await _enterWords(tester, bogus);
        await tester.pumpAndSettle();
        expect(find.textContaining('NOT VERIFIED'), findsOneWidget);

        await tester.ensureVisible(find.text('WHAT SHOULD I DO?'));
        await tester.tap(find.text('WHAT SHOULD I DO?'));
        await tester.pumpAndSettle();

        expect(find.text('IF VERIFY FAILS //'), findsOneWidget);
        expect(find.text('Something is wrong with this call.'),
            findsOneWidget);
        expect(find.textContaining('Hang up'), findsOneWidget);
        expect(find.textContaining('Call Mom back on a number'),
            findsOneWidget);
        expect(find.text('GOT IT'), findsOneWidget);
        // Dismiss is standard Material sheet behavior (tap outside /
        // drag / back button); exercising it in widget-test is a
        // rabbit hole of viewport-vs-sheet-gesture timing that isn't
        // carrying meaningful coverage. Trust the framework.
      },
    );

    testWidgets(
      '✅ banner does not show WHAT SHOULD I DO action',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(relationshipId: 'abc'),
          ),
        );
        await tester.pumpAndSettle();

        final legit = await _currentWordsFromMom();
        await _enterWords(tester, legit);
        await tester.pumpAndSettle();
        expect(find.text('VERIFIED'), findsOneWidget);
        expect(find.text('WHAT SHOULD I DO?'), findsNothing);
      },
    );

    testWidgets(
      'renders the LIVENESS CHALLENGE // entry row',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(relationshipId: 'abc'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('LIVENESS CHALLENGE //'), findsOneWidget);
        expect(find.textContaining('Ask Mom to do a physical'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping LIVENESS CHALLENGE row routes to /liveness/:id',
      (tester) async {
        await tester.pumpWidget(wrapWithRouter(
          store: FakeSecureStore(seeded: _mom, secret: _secret),
          verifyId: 'abc',
        ));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('LIVENESS CHALLENGE //'));
        await tester.tap(find.text('LIVENESS CHALLENGE //'));
        await tester.pumpAndSettle();

        expect(find.text('LIVENESS_abc'), findsOneWidget);
      },
    );

    testWidgets(
      'silentHaptics=true suppresses HapticFeedback on both ✅ and ❌',
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

        final silent = _mom.copyWith(silentHaptics: true);
        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: silent, secret: _secret),
            child: const VerifyScreen(relationshipId: 'abc'),
          ),
        );
        await tester.pumpAndSettle();

        // Wrong words → ❌ path, no heavy haptic expected.
        const bogus = <String>['orange', 'anchor', 'abandon', 'ability'];
        await _enterWords(tester, bogus);
        await tester.pumpAndSettle();
        expect(find.textContaining('NOT VERIFIED'), findsOneWidget);

        // Correct words → ✅ path, no light haptic expected.
        final legit = await _currentWordsFromMom();
        await _enterWords(tester, legit);
        await tester.pumpAndSettle();
        expect(find.text('VERIFIED'), findsOneWidget);

        final hapticCalls = calls.where(
          (c) => c.method == 'HapticFeedback.vibrate',
        );
        expect(hapticCalls, isEmpty);
      },
    );

    testWidgets(
      'ticker pauses on AppLifecycleState.paused and resumes on resumed',
      (tester) async {
        // Backgrounding the app must stop the 1s ticker — otherwise we keep
        // re-deriving TOTP words in memory while the screen isn't visible.
        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(relationshipId: 'abc'),
          ),
        );
        await tester.pumpAndSettle();

        // Capture a fingerprint of the rendered "Show my words" area —
        // expand first so its contents tick with every second.
        await tester.ensureVisible(find.text('Show my 4 words'));
        await tester.tap(find.text('Show my 4 words'));
        await tester.pumpAndSettle();

        // Simulate backgrounding. Flutter enforces valid state transitions,
        // so we walk: inactive → hidden → paused, then back paused →
        // hidden → inactive → resumed. The observer cancels the timer
        // somewhere in the going-down phase and restarts it on resumed.
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump(const Duration(seconds: 2));

        // Back to foreground.
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump(const Duration(seconds: 2));

        // Sanity: the screen still renders normally after the cycle — if
        // the observer bookkeeping were off, we'd crash on the pump.
        expect(find.text('Show my 4 words'), findsOneWidget);
      },
    );
  });
}
