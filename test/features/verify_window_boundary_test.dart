// Video-mode verify across a 30-second boundary (plan Task 3.1) and the
// words ticker while `inactive` (plan Task 3.2), and where focus goes after
// a result (plan Task 3.4).
//
// TotpWords.verify accepts the previous and next window, so the words a
// counterparty reads can belong to a different window than "now". The
// gesture the verifier is asked about must be the one for the window the
// words matched, must not change while the SAW IT panel is open, and the
// WATCH FOR row must not change under the verifier while they type.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/crypto/totp_words.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/features/verify/verify_screen.dart';
import 'package:signet/l10n/app_localizations.dart';
import 'package:signet/l10n/app_localizations_en.dart';

import '../support/fake_secure_store.dart';

final _mom = Relationship(
  id: 'abc',
  label: 'Mom',
  pairedAt: DateTime.utc(2026, 4, 16),
  role: PairRole.a,
);
final _secret = List<int>.generate(32, (i) => i + 1);
final _en = AppLocalizationsEn();

/// Mom's role: what Alice (this device) watches for and verifies against.
final _momRole = _mom.role.other;

Future<LivenessAction> _actionAt(int counter) =>
    TotpWords.deriveLivenessActionForCounter(
      secret: _secret,
      counter: counter,
      senderRole: _momRole,
    );

Future<List<String>> _momWordsAt(int unix) => TotpWords.generate(
      secret: _secret,
      unixTimeSeconds: unix,
      senderRole: _momRole,
    );

/// The start of a window whose gesture differs from both neighbours', so a
/// test cannot pass by coincidence.
Future<int> _distinctWindowStart() async {
  const base = 1735776000; // window start, 2025-01-02 00:00:00 UTC
  for (var k = 0; k < 200; k++) {
    final t = base + 30 * k;
    final c = TotpWords.counterFor(t);
    final prev = await _actionAt(c - 1);
    final now = await _actionAt(c);
    final next = await _actionAt(c + 1);
    if (prev != now && now != next && prev != next) return t;
  }
  throw StateError('no fixture window found');
}

String _text(LivenessAction a) => livenessActionText(a, _en);

Finder _watchFor(LivenessAction a) =>
    find.textContaining('Mom should: ${_text(a)}');
Finder _judging(LivenessAction a) =>
    find.textContaining('Did you see Mom: ${_text(a)}');

void main() {
  late int clock;

  Widget app({bool video = true}) => ProviderScope(
        overrides: [
          secureStoreProvider.overrideWithValue(
              FakeSecureStore(seeded: _mom, secret: _secret)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: VerifyScreen(
            relationshipId: 'abc',
            initialVideoMode: video,
            unixTimeSecondsProvider: () => clock,
          ),
        ),
      );

  Future<void> type(WidgetTester tester, List<String> words) async {
    for (var i = 0; i < words.length; i++) {
      await tester.enterText(find.byType(TextField).at(i), words[i]);
      await tester.pumpAndSettle();
    }
  }

  /// Let the 1 s ticker run [seconds] times against the current clock.
  Future<void> tick(WidgetTester tester, [int seconds = 2]) async {
    for (var i = 0; i < seconds; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
      'words from the previous window are judged against that window\'s '
      'gesture, and the panel says it differs from WATCH FOR',
      (tester) async {
    final t = await _distinctWindowStart();
    final c = TotpWords.counterFor(t);
    final prevAction = await _actionAt(c - 1);
    final nowAction = await _actionAt(c);
    clock = t + 5;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(_watchFor(nowAction), findsOneWidget);

    await type(tester, await _momWordsAt(t - 10));

    expect(_judging(prevAction), findsOneWidget);
    expect(_judging(nowAction), findsNothing);
    expect(find.textContaining('The gesture to watch for has changed'),
        findsOneWidget);
    expect(find.textContaining('exactly one gesture'), findsOneWidget);
  });

  testWidgets('the SAW IT panel does not change when the clock moves on',
      (tester) async {
    final t = await _distinctWindowStart();
    final c = TotpWords.counterFor(t);
    final prevAction = await _actionAt(c - 1);
    clock = t + 5;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await type(tester, await _momWordsAt(t - 10));
    expect(_judging(prevAction), findsOneWidget);

    clock = t + 35; // next window
    await tick(tester);
    expect(_judging(prevAction), findsOneWidget);
  });

  testWidgets('words from the current window: no "differs" note',
      (tester) async {
    final t = await _distinctWindowStart();
    final nowAction = await _actionAt(TotpWords.counterFor(t));
    clock = t + 5;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await type(tester, await _momWordsAt(t + 5));
    expect(_judging(nowAction), findsOneWidget);
    expect(find.textContaining('The gesture to watch for has changed'),
        findsNothing);
  });

  testWidgets(
      'WATCH FOR freezes at the first keystroke and thaws when the input '
      'is cleared', (tester) async {
    final t = await _distinctWindowStart();
    final c = TotpWords.counterFor(t);
    final nowAction = await _actionAt(c);
    final nextAction = await _actionAt(c + 1);
    clock = t + 28;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(_watchFor(nowAction), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'ab');
    await tester.pumpAndSettle();
    clock = t + 32; // next window
    await tick(tester);
    expect(_watchFor(nowAction), findsOneWidget,
        reason: 'frozen while typing');
    expect(_watchFor(nextAction), findsNothing);

    await tester.ensureVisible(find.text('Clear all'));
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    await tick(tester);
    expect(_watchFor(nextAction), findsOneWidget,
        reason: 'live again once the input is empty');
  });

  testWidgets('words from the next window, typed while WATCH FOR is frozen '
      'on this one, are judged against the next window', (tester) async {
    final t = await _distinctWindowStart();
    final c = TotpWords.counterFor(t);
    final nowAction = await _actionAt(c);
    final nextAction = await _actionAt(c + 1);
    clock = t + 28;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final words = await _momWordsAt(t + 31); // Mom's phone already rolled
    await tester.enterText(find.byType(TextField).at(0), words[0]);
    await tester.pumpAndSettle();
    clock = t + 29;
    await type(tester, words);
    expect(_judging(nextAction), findsOneWidget);
    expect(_watchFor(nextAction), findsOneWidget,
        reason: 'one gesture on screen: the one being asked about');
    expect(_watchFor(nowAction), findsNothing);
    expect(find.textContaining('The gesture to watch for has changed'),
        findsOneWidget);
  });

  testWidgets(
      'the own-words ticker keeps running while inactive (split-screen '
      'beside a video call)', (tester) async {
    const t = 1735776000;
    clock = t;
    await tester.pumpWidget(app(video: false));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Show my 4 words'));
    await tester.tap(find.text('Show my 4 words'));
    await tester.pumpAndSettle();
    final before = await TotpWords.generate(
        secret: _secret, unixTimeSeconds: t, senderRole: _mom.role);
    for (final w in before) {
      expect(find.text(w), findsWidgets);
    }

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    clock = t + 94;
    await tick(tester);
    final after = await TotpWords.generate(
        secret: _secret, unixTimeSeconds: t + 94, senderRole: _mom.role);
    expect(after, isNot(before));
    for (final w in after) {
      expect(find.text(w), findsWidgets);
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('the ticker still stops when paused', (tester) async {
    const t = 1735776000;
    clock = t;
    await tester.pumpWidget(app(video: false));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Show my 4 words'));
    await tester.tap(find.text('Show my 4 words'));
    await tester.pumpAndSettle();
    final before = await TotpWords.generate(
        secret: _secret, unixTimeSeconds: t, senderRole: _mom.role);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    clock = t + 94;
    await tick(tester);
    for (final w in before) {
      expect(find.text(w), findsWidgets, reason: 'not re-derived while paused');
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tick(tester);
  });

  group('the WATCH FOR freeze across attempts (review fixes)', () {
    testWidgets(
        'typing while the gesture question is open: the next attempt is '
        'still frozen after SAW IT', (tester) async {
      final t = await _distinctWindowStart();
      final c = TotpWords.counterFor(t);
      final nowAction = await _actionAt(c);
      final nextAction = await _actionAt(c + 1);
      clock = t + 5;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await type(tester, await _momWordsAt(t + 5));
      expect(find.text('SAW IT'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'ab');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('SAW IT'));
      await tester.tap(find.text('SAW IT'));
      await tester.pumpAndSettle();

      clock = t + 35;
      await tick(tester);
      expect(_watchFor(nowAction), findsOneWidget,
          reason: 'frozen for the attempt already being typed');
      expect(_watchFor(nextAction), findsNothing);
    });

    testWidgets('toggling video mode mid-typing keeps the freeze',
        (tester) async {
      final t = await _distinctWindowStart();
      final c = TotpWords.counterFor(t);
      final nowAction = await _actionAt(c);
      clock = t + 5;
      await tester.pumpWidget(app(video: false));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'ab');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      clock = t + 35;
      await tick(tester);
      expect(_watchFor(nowAction), findsOneWidget);
    });

    testWidgets('a freeze two windows old is renewed', (tester) async {
      final t = await _distinctWindowStart();
      final c = TotpWords.counterFor(t);
      final nowAction = await _actionAt(c);
      final laterAction = await _actionAt(c + 2);
      clock = t + 5;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'ab');
      await tester.pumpAndSettle();
      clock = t + 65; // window c + 2
      await tick(tester);
      expect(_watchFor(laterAction), findsOneWidget);
      if (laterAction != nowAction) {
        expect(_watchFor(nowAction), findsNothing);
      }
    });
  });

  group('focus after a result (plan Task 3.4)', () {

    bool anySlotFocused(WidgetTester tester) => tester
        .widgetList<TextField>(find.byType(TextField))
        .any((f) => f.focusNode?.hasFocus ?? false);

    testWidgets(
        'video mode, words pass: no keyboard, and the gesture question is '
        'on screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 1600);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      const t = 1735776000;
      clock = t;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await type(tester, await _momWordsAt(t));
      expect(find.text('SAW IT'), findsOneWidget);
      expect(anySlotFocused(tester), isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text('SAW IT').hitTestable(), findsOneWidget,
          reason: 'scrolled into view');
    });

    testWidgets('plain mode, words pass: no keyboard', (tester) async {
      const t = 1735776000;
      clock = t;
      await tester.pumpWidget(app(video: false));
      await tester.pumpAndSettle();
      await type(tester, await _momWordsAt(t));
      expect(anySlotFocused(tester), isFalse);
    });

    testWidgets('words fail: back in slot 1 to try again', (tester) async {
      const t = 1735776000;
      clock = t;
      await tester.pumpWidget(app(video: false));
      await tester.pumpAndSettle();
      await type(tester, const <String>['abandon', 'ability', 'able', 'about']);
      final first = tester.widget<TextField>(find.byType(TextField).first);
      expect(first.focusNode!.hasFocus, isTrue);
    });
  });
}
