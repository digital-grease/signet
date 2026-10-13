// In-person pairing screen, commit-then-reveal (plan Task 1.7f). A fake
// camera feeds the screen real codes from a simulated second phone, so the
// whole flow runs: role choice, three codes, then the confirm screen.

import 'dart:typed_data';

import 'package:camera/camera.dart' show CameraController;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:signet/features/pairing/in_person_pairing_controller.dart';
import 'package:signet/features/pairing/pair_exchange_screen.dart';
import 'package:signet/features/pairing/pairing_code_v2.dart';
import 'package:signet/l10n/app_localizations.dart';
import 'package:signet/shared/widgets/qr_scanner.dart';

import '../support/in_person_pairing.dart';

/// Stands in for the camera; [scan] delivers a code as if read.
class _FakeCamera {
  void Function(String text)? _onText;

  Widget build({
    required void Function(String text) onText,
    required void Function(CameraController? c, Exception? e)
        onControllerCreated,
  }) {
    _onText = onText;
    // Camera "came up": no error pane, no watchdog failure.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => onControllerCreated(null, null));
    return const ColoredBox(
      key: ValueKey<String>('camera'),
      color: Colors.black,
      child: SizedBox.expand(),
    );
  }

  void scan(String text) => _onText!(text);
}

void main() {
  late _FakeCamera camera;
  late ProviderContainer phone; // the phone on screen
  late ProviderContainer peer; // the other phone, driven directly

  setUp(() {
    camera = _FakeCamera();
    qrReaderOverride = camera.build;
    phone = ProviderContainer(overrides: [testInPersonPhrase]);
    peer = ProviderContainer(overrides: [testInPersonPhrase]);
  });
  tearDown(() {
    qrReaderOverride = null;
    phone.dispose();
    peer.dispose();
  });

  InPersonPairingController ctrlOf(ProviderContainer c) =>
      c.read(inPersonPairingControllerProvider.notifier);
  InPersonPairingState stateOf(ProviderContainer c) =>
      c.read(inPersonPairingControllerProvider);

  Widget app({Locale locale = const Locale('en')}) => UncontrolledProviderScope(
        container: phone,
        child: MaterialApp.router(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: GoRouter(
            initialLocation: '/pair/exchange',
            routes: <RouteBase>[
              GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
              GoRoute(
                path: '/pair/exchange',
                builder: (_, _) => const PairExchangeScreen(),
              ),
              GoRoute(
                path: '/pair/confirm',
                builder: (_, _) => const Text('CONFIRM'),
              ),
            ],
          ),
        ),
      );

  /// Lets the screen's crypto (plain futures) and rebuilds run. Not
  /// pumpAndSettle: progress indicators never settle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Unmount so the screen's timers are cancelled before the test ends.
  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(PairExchangeScreen)));

  testWidgets('role choice keeps the safety rule and offers Start and Join',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.textContaining('never a photo or a video call'),
        findsOneWidget);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('JOIN'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('Start shows code 1 as a QR, and as text on request',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.text('START'));
    await settle(tester);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Tap when the other phone shows its own code.'),
        findsOneWidget);
    await tester.tap(find.text('Show the code as text'));
    await settle(tester);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('signet:p2:C:'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('Join: the full three-code flow reaches the same words, and '
      'the confirm step survives the page change', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await ctrlOf(peer).begin(InPersonRole.start);

    await tester.tap(find.text('JOIN'));
    await settle(tester);
    expect(find.textContaining('Scan the other phone.'), findsOneWidget);
    camera.scan(stateOf(peer).qrPayload!); // code 1
    await settle(tester);

    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    ctrlOf(peer).startNext();
    await ctrlOf(peer).onScan(stateOf(phone).qrPayload!); // peer scans code 2
    await tester.tap(find.text('NEXT'));
    await settle(tester);

    expect(find.textContaining('Scan the other phone once more.'), findsOneWidget);
    camera.scan(stateOf(peer).qrPayload!); // code 3
    await settle(tester);
    await ctrlOf(peer).startFinish();

    expect(find.text('CONFIRM'), findsOneWidget);
    expect(stateOf(phone).phrase, stateOf(peer).phrase);
    // Once the exchange screen is gone, its dispose must not have dropped
    // the result the confirm screen reads.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.byType(PairExchangeScreen), findsNothing);
    expect(stateOf(phone).step, InPersonStep.confirm);
    expect(stateOf(phone).phrase, isNotNull);
    await leave(tester);
  });

  testWidgets('a pasted code works like a scanned one', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await ctrlOf(peer).begin(InPersonRole.start);
    await tester.tap(find.text('JOIN'));
    await settle(tester);
    await tester.tap(find.text('Paste a code instead'));
    await settle(tester);
    // A messaging app's line break inside the code is ignored.
    final code = stateOf(peer).qrPayload!;
    await tester.enterText(find.byType(TextField),
        '${code.substring(0, 20)}\n${code.substring(20)}');
    await tester.tap(find.text('USE THIS CODE'));
    await settle(tester);
    expect(find.text('Step 2 of 3'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a damaged pasted code shows a notice and the attempt goes on',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.text('JOIN'));
    await settle(tester);
    await tester.tap(find.text('Paste a code instead'));
    await settle(tester);
    expect(find.text(l10nOf(tester).pairCodeMalformedNotice), findsNothing);
    await tester.enterText(find.byType(TextField), 'signet:p2:C:AAAA');
    await tester.tap(find.text('USE THIS CODE'));
    await settle(tester);
    expect(find.text(l10nOf(tester).pairCodeMalformedNotice), findsOneWidget);
    expect(stateOf(phone).step, InPersonStep.joinScanCommit);
    await leave(tester);
  });

  testWidgets('a damaged scanned code shows a notice on the camera',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.text('JOIN'));
    await settle(tester);
    camera.scan('https://example.com');
    await settle(tester);
    expect(find.text(l10nOf(tester).pairCodeNotPairingNotice), findsOneWidget);
    expect(stateOf(phone).step, InPersonStep.joinScanCommit);
    await leave(tester);
  });

  // Plan Task 1.7j: a code from a later or earlier Signet says which
  // phone needs an update, never "not a pairing code".
  for (final (name, code, notice) in [
    (
      'a newer code',
      'signet:p3:C:AAAA',
      (AppLocalizations l) => l.pairCodeThisNeedsUpdateNotice,
    ),
    (
      'an older code',
      'signet:p1:AAAA',
      (AppLocalizations l) => l.pairCodePeerNeedsUpdateNotice,
    ),
  ]) {
    testWidgets('$name, scanned or pasted, says which phone to update',
        (tester) async {
      await tester.pumpWidget(app());
      await settle(tester);
      await tester.tap(find.text('JOIN'));
      await settle(tester);
      camera.scan(code);
      await settle(tester);
      final text = notice(l10nOf(tester));
      expect(find.text(text), findsOneWidget, reason: 'scanned');
      expect(text, contains('only from the app store'));
      expect(stateOf(phone).step, InPersonStep.joinScanCommit);

      await tester.tap(find.text('Paste a code instead'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), code);
      await tester.tap(find.text('USE THIS CODE'));
      await settle(tester);
      expect(find.text(text), findsOneWidget, reason: 'pasted');
      expect(stateOf(phone).step, InPersonStep.joinScanCommit);
      await leave(tester);
    });
  }

  testWidgets('a code already used says so and keeps the camera running',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await ctrlOf(peer).begin(InPersonRole.start);
    final commit = stateOf(peer).qrPayload!;
    await tester.tap(find.text('JOIN'));
    await settle(tester);
    camera.scan(commit);
    await settle(tester);
    final key = stateOf(phone).qrPayload!; // Join's code 2
    await tester.tap(find.text('NEXT')); // too early: Start still shows 1
    await settle(tester);
    camera.scan(commit);
    await settle(tester);
    expect(find.text(l10nOf(tester).pairCodeAlreadyScannedNotice),
        findsOneWidget);
    expect(stateOf(phone).step, InPersonStep.joinScanReveal);
    // ...and Join can go back to showing the same code.
    await tester.tap(find.text('Show my code again'));
    await settle(tester);
    expect(stateOf(phone).step, InPersonStep.joinShowKey);
    expect(stateOf(phone).qrPayload, key);
    await leave(tester);
  });

  for (final locale in const [Locale('en'), Locale('zh')]) {
    testWidgets('a low-order key shows the localized stop warning '
        '(${locale.languageCode})', (tester) async {
      await tester.pumpWidget(app(locale: locale));
      await settle(tester);
      await ctrlOf(phone).begin(InPersonRole.start);
      await settle(tester);
      ctrlOf(phone).startNext();
      await settle(tester);
      camera.scan(PairingCodeV2.encodeKey(Uint8List(32)));
      await settle(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.pairingWeakKeyInPersonError), findsOneWidget);
      // It already says to cancel on both phones: no second instruction.
      expect(find.text(l10n.pairInPersonStartOverBoth), findsNothing);
      await tester.tap(find.text(l10n.pairInPersonStartOverButton));
      await settle(tester);
      expect(stateOf(phone).step, InPersonStep.chooseRole);
      await leave(tester);
    });
  }

  testWidgets('other failures say to start over on both phones',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await ctrlOf(peer).begin(InPersonRole.start);
    await ctrlOf(phone).begin(InPersonRole.start);
    await settle(tester);
    ctrlOf(phone).startNext();
    await settle(tester);
    camera.scan(stateOf(peer).qrPayload!); // two Start phones
    await settle(tester);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.pairFailStartStart), findsOneWidget);
    expect(find.text(l10n.pairInPersonStartOverBoth), findsOneWidget);
    await leave(tester);
  });

  testWidgets('START OVER at the top ends an attempt; the X leaves pairing',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.text('START'));
    await settle(tester);
    expect(stateOf(phone).qrPayload, isNotNull);
    expect(find.byIcon(Icons.close), findsNothing);
    await tester.tap(find.text('START OVER'));
    await settle(tester);
    expect(stateOf(phone).step, InPersonStep.chooseRole);
    expect(stateOf(phone).qrPayload, isNull);
    await tester.tap(find.byIcon(Icons.close));
    await settle(tester);
    expect(find.text('HOME'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('system back mid-attempt ends the attempt, not the screen',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.text('START'));
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(PairExchangeScreen), findsOneWidget);
    expect(stateOf(phone).step, InPersonStep.chooseRole);
    expect(stateOf(phone).qrPayload, isNull);
    await leave(tester);
  });

  for (final role in InPersonRole.values) {
    testWidgets('${role.name} gets a hint after 20 s with nothing scanned, '
        'over the camera', (tester) async {
      await tester.pumpWidget(app());
      await settle(tester);
      await ctrlOf(phone).begin(role);
      await settle(tester);
      if (role == InPersonRole.start) {
        ctrlOf(phone).startNext();
        await settle(tester);
      }
      final l10n = l10nOf(tester);
      final hint = role == InPersonRole.join
          ? l10n.pairInPersonJoinIdleHint
          : l10n.pairInPersonStartIdleHint;
      expect(find.text(hint), findsNothing);
      final cameraBefore = tester.getSize(find.byKey(const ValueKey('camera')));
      await tester.pump(const Duration(seconds: 21));
      expect(find.text(hint), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('camera'))),
          cameraBefore, reason: 'the hint overlays the camera, never shrinks it');
      await leave(tester);
    });
  }

  testWidgets('an attempt that runs too long ends and says so',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.text('START'));
    await settle(tester);
    await tester.pump(const Duration(minutes: 5, seconds: 1));
    await settle(tester);
    expect(stateOf(phone).failure, InPersonFailure.timedOut);
    expect(find.text(l10nOf(tester).pairFailTimedOut), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a new attempt gets a fresh time limit', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.text('START'));
    await settle(tester);
    await tester.pump(const Duration(minutes: 3));
    await tester.tap(find.text('START OVER'));
    await settle(tester);
    await tester.tap(find.text('START'));
    await settle(tester);
    await tester.pump(const Duration(minutes: 4));
    await settle(tester);
    expect(stateOf(phone).failure, isNull,
        reason: 'the first attempt deadline must not carry over');
    await tester.pump(const Duration(minutes: 1, seconds: 1));
    await settle(tester);
    expect(stateOf(phone).failure, InPersonFailure.timedOut);
    await leave(tester);
  });

  testWidgets('leaving the screen mid-attempt drops the attempt',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);
    await tester.tap(find.text('START'));
    await settle(tester);
    expect(stateOf(phone).qrPayload, isNotNull);
    await leave(tester);
    expect(stateOf(phone).step, InPersonStep.chooseRole);
    expect(stateOf(phone).qrPayload, isNull);
  });
}
