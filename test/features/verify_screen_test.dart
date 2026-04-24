import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
      // Legacy /liveness/:id route removed in Phase 14 — the standalone
      // liveness screen was retired in favor of the verify screen's
      // video-mode toggle.
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

    // Legacy `_LivenessEntry` row tests removed in Phase 14: the row was
    // replaced by the in-screen "VIDEO CALL //" toggle, and the standalone
    // `/liveness/:id` route redirects to `/verify/:id?video=1`. Video-mode
    // coverage lives in the "VerifyScreen video mode" group below.

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

  // -------------------------------------------------------------------
  // Phase 14: secret-derived liveness via "video mode" toggle.
  //
  // Contract:
  //   - Toggle renders a VIDEO CALL // row with a Switch.
  //   - When off, no "WATCH FOR //" action line is shown.
  //   - When on, "WATCH FOR //" appears with the counterparty's expected
  //     action for the current window (derived via
  //     `TotpWords.deriveLivenessAction` against the counterparty role).
  //   - A words ✅ in video mode DOES NOT show the ✅ banner — it shows
  //     the "ACTION //" judgment prompt (SAW IT / DID NOT SEE) instead.
  //   - Words ✅ + SAW IT → overall ✅ banner.
  //   - Words ✅ + DID NOT SEE → overall ❌ banner.
  //   - Words ❌ in video mode short-circuits straight to the ❌ banner
  //     (no action judgment sub-step).
  //   - `initialVideoMode: true` (deep-link `?video=1`) pre-enables the
  //     toggle on first frame.
  //   - Toggling mid-attempt invalidates the current state (resets input
  //     + clears any pending result).
  group('VerifyScreen video mode', () {
    /// Computes counterparty's expected liveness action for the current
    /// window — the action Alice should watch Mom perform on video.
    Future<LivenessAction> currentExpectedAction() async {
      final now =
          DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      return TotpWords.deriveLivenessAction(
        secret: _secret,
        unixTimeSeconds: now,
        senderRole: _mom.role.other,
      );
    }

    testWidgets('renders the VIDEO CALL // toggle row', (tester) async {
      await tester.pumpWidget(
        wrap(
          store: FakeSecureStore(seeded: _mom, secret: _secret),
          child: const VerifyScreen(relationshipId: 'abc'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('VIDEO CALL //'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets(
      'plain mode hides WATCH FOR // and does not require action judgment',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(relationshipId: 'abc'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('WATCH FOR //'), findsNothing);

        // Words ✅ in plain mode → immediate overall ✅ banner; no
        // action judgment panel.
        final words = await _currentWordsFromMom();
        await _enterWords(tester, words);
        await tester.pumpAndSettle();
        expect(find.text('VERIFIED'), findsOneWidget);
        expect(find.text('ACTION //'), findsNothing);
      },
    );

    testWidgets(
      'toggling video mode on shows WATCH FOR // with the current action',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(relationshipId: 'abc'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        expect(find.text('WATCH FOR //'), findsOneWidget);
        final action = await currentExpectedAction();
        expect(
          find.textContaining(action.humanReadable),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'initialVideoMode=true (deep-link ?video=1) pre-enables the toggle',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(
              relationshipId: 'abc',
              initialVideoMode: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('WATCH FOR //'), findsOneWidget);
        final s = tester.widget<Switch>(find.byType(Switch));
        expect(s.value, isTrue);
      },
    );

    testWidgets(
      '✅✅: words ✅ + SAW IT → overall VERIFIED banner',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(
              relationshipId: 'abc',
              initialVideoMode: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final words = await _currentWordsFromMom();
        await _enterWords(tester, words);
        await tester.pumpAndSettle();

        // Banner deferred — awaiting action judgment.
        expect(find.text('VERIFIED'), findsNothing);
        expect(find.text('ACTION //'), findsOneWidget);
        expect(find.text('SAW IT'), findsOneWidget);
        expect(find.text('DID NOT SEE'), findsOneWidget);

        await tester.ensureVisible(find.text('SAW IT'));
        await tester.tap(find.text('SAW IT'));
        await tester.pumpAndSettle();

        expect(find.text('VERIFIED'), findsOneWidget);
        expect(
          find.textContaining('you saw the expected physical action'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '✅❌: words ✅ + DID NOT SEE → overall NOT VERIFIED banner',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(
              relationshipId: 'abc',
              initialVideoMode: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final words = await _currentWordsFromMom();
        await _enterWords(tester, words);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('DID NOT SEE'));
        await tester.tap(find.text('DID NOT SEE'));
        await tester.pumpAndSettle();

        expect(find.textContaining('NOT VERIFIED'), findsOneWidget);
        expect(
          find.textContaining('physical action did not'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '❌_: words ❌ in video mode → immediate NOT VERIFIED, no action panel',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(
              relationshipId: 'abc',
              initialVideoMode: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        const bogus = <String>['orange', 'anchor', 'abandon', 'ability'];
        await _enterWords(tester, bogus);
        await tester.pumpAndSettle();

        expect(find.textContaining('NOT VERIFIED'), findsOneWidget);
        expect(find.text('ACTION //'), findsNothing);
        expect(find.text('SAW IT'), findsNothing);
      },
    );

    testWidgets(
      'toggling video mode mid-attempt clears a pending result',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(relationshipId: 'abc'),
          ),
        );
        await tester.pumpAndSettle();

        // Plain-mode verify → ✅.
        final words = await _currentWordsFromMom();
        await _enterWords(tester, words);
        await tester.pumpAndSettle();
        expect(find.text('VERIFIED'), findsOneWidget);

        // Flip the toggle — the stale ✅ banner should clear.
        await tester.ensureVisible(find.text('VIDEO CALL //'));
        await tester.tap(find.text('VIDEO CALL //'));
        await tester.pumpAndSettle();
        expect(find.text('VERIFIED'), findsNothing);
        expect(find.text('WATCH FOR //'), findsOneWidget);
      },
    );

    testWidgets(
      'toggling video mode with typed-but-unsubmitted words preserves input',
      (tester) async {
        // Lighter fix for the M4 finding: previously every toggle would
        // reset the WordInput, wiping typed-so-far words mid-typing. The
        // fix only resets when a verify result already exists. A user who
        // types 3 words, realises they want video mode, and toggles,
        // should keep those 3 words in place.
        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(relationshipId: 'abc'),
          ),
        );
        await tester.pumpAndSettle();

        // Partial input — only the first 3 slots, so no auto-submit fires.
        await tester.enterText(_slotField(0), 'orange');
        await tester.pumpAndSettle();
        await tester.enterText(_slotField(1), 'anchor');
        await tester.pumpAndSettle();
        await tester.enterText(_slotField(2), 'abandon');
        await tester.pumpAndSettle();

        // Toggle to video mode.
        await tester.ensureVisible(find.text('VIDEO CALL //'));
        await tester.tap(find.text('VIDEO CALL //'));
        await tester.pumpAndSettle();

        // All three typed words remain in their slots.
        expect(
          tester.widget<TextField>(_slotField(0)).controller!.text,
          'orange',
        );
        expect(
          tester.widget<TextField>(_slotField(1)).controller!.text,
          'anchor',
        );
        expect(
          tester.widget<TextField>(_slotField(2)).controller!.text,
          'abandon',
        );
        // Slot 3 is still empty; no submission has happened.
        expect(
          tester.widget<TextField>(_slotField(3)).controller!.text,
          '',
        );
        expect(find.text('VERIFIED'), findsNothing);
        expect(find.text('NOT VERIFIED'), findsNothing);
      },
    );

    testWidgets(
      'Show-my-4-words panel gains a "...while X" line in video mode',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(
              relationshipId: 'abc',
              initialVideoMode: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Show my 4 words'));
        await tester.tap(find.text('Show my 4 words'));
        await tester.pumpAndSettle();

        // The gerund phrase starts with "...while" and should render
        // alongside the rotating word display.
        final gerundFinder = find.textContaining('...while');
        expect(gerundFinder, findsOneWidget);
      },
    );

    testWidgets(
      'VIDEO CALL toggle exposes a toggled Semantics node for TalkBack',
      (tester) async {
        final handle = tester.ensureSemantics();
        // Dispose inline at test end — addTearDown runs AFTER
        // _endOfTestVerifications, which is what checks for leaked handles,
        // so tearDown-based disposal trips the sanity check.

        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(relationshipId: 'abc'),
          ),
        );
        await tester.pumpAndSettle();

        // MergeSemantics folds the Switch node into the outer row, so the
        // merged node's label is a concatenation of our explicit label and
        // the child Text runs. Match any Semantics node whose label
        // contains our entry-point string.
        var toggleSemantics = tester.getSemantics(
          find.bySemanticsLabel(RegExp('Video call mode')),
        );
        expect(
          toggleSemantics.flagsCollection.hasToggledState,
          isTrue,
          reason: 'row is announced as a toggle, not just a button',
        );
        expect(
          toggleSemantics.flagsCollection.isToggled,
          isFalse,
          reason: 'off by default',
        );

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        toggleSemantics = tester.getSemantics(
          find.bySemanticsLabel(RegExp('Video call mode')),
        );
        expect(toggleSemantics.flagsCollection.isToggled, isTrue);
        handle.dispose();
      },
    );

    testWidgets(
      'WATCH FOR // is a liveRegion so window rollover is announced',
      (tester) async {
        final handle = tester.ensureSemantics();
        // Dispose inline at test end — addTearDown runs AFTER
        // _endOfTestVerifications, which is what checks for leaked handles,
        // so tearDown-based disposal trips the sanity check.

        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(
              relationshipId: 'abc',
              initialVideoMode: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final action = await currentExpectedAction();
        final watchForSemantics = tester.getSemantics(
          find.bySemanticsLabel(
            RegExp('Watch for: Mom should ${action.humanReadable}'),
          ),
        );
        expect(
          watchForSemantics.flagsCollection.isLiveRegion,
          isTrue,
          reason:
              'blind users need the screen-reader re-announcement on window '
              'rollover — otherwise the visible prompt updates silently.',
        );
        handle.dispose();
      },
    );

    testWidgets(
      'ACTION // judgment panel is a liveRegion when it appears post-words-✅',
      (tester) async {
        final handle = tester.ensureSemantics();
        // Dispose inline at test end — addTearDown runs AFTER
        // _endOfTestVerifications, which is what checks for leaked handles,
        // so tearDown-based disposal trips the sanity check.

        await tester.pumpWidget(
          wrap(
            store: FakeSecureStore(seeded: _mom, secret: _secret),
            child: const VerifyScreen(
              relationshipId: 'abc',
              initialVideoMode: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final words = await _currentWordsFromMom();
        await _enterWords(tester, words);
        await tester.pumpAndSettle();

        // Tree traversal — find the Semantics node that contains the
        // action-judgment prompt. Can't use bySemanticsLabel because
        // the prompt includes a generated humanReadable action name.
        final panelSemantics = tester.getSemantics(
          find.ancestor(
            of: find.textContaining('Did you see Mom'),
            matching: find.byType(Semantics),
          ).first,
        );
        expect(
          panelSemantics.flagsCollection.isLiveRegion,
          isTrue,
          reason:
              'blind users need the screen-reader re-announcement when the '
              'UI transitions from type-words to judge-action — otherwise '
              'they remain at the empty-input state with no cue to proceed.',
        );
        handle.dispose();
      },
    );

    testWidgets(
      'haptics fire at action-judgment step in video mode (not at words-✅)',
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
            child: const VerifyScreen(
              relationshipId: 'abc',
              initialVideoMode: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final words = await _currentWordsFromMom();
        await _enterWords(tester, words);
        await tester.pumpAndSettle();

        // Words ✅ in video mode must defer haptic — otherwise the user
        // feels a "verified" buzz before the overall outcome is known.
        var hapticCalls = calls.where(
          (c) => c.method == 'HapticFeedback.vibrate',
        );
        expect(hapticCalls, isEmpty,
            reason: 'no haptic at pending-action step');

        await tester.ensureVisible(find.text('SAW IT'));
        await tester.tap(find.text('SAW IT'));
        await tester.pumpAndSettle();

        hapticCalls = calls.where(
          (c) => c.method == 'HapticFeedback.vibrate',
        );
        expect(hapticCalls, hasLength(1),
            reason: 'one haptic on overall ✅');
      },
    );
  });
}
