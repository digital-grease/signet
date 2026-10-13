import 'dart:typed_data';

import 'package:camera/camera.dart' show CameraController;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/features/pairing/in_person_pairing_controller.dart';
import 'package:signet/features/pairing/pair_exchange_screen.dart';
import 'package:signet/features/pairing/pairing_code_v2.dart';
import 'package:signet/l10n/app_localizations.dart';
import 'package:signet/shared/widgets/qr_scanner.dart';

import '../support/in_person_pairing.dart';

// Every pane of the in-person pairing screen must fit, or scroll, at large
// text on a small phone (CLAUDE.md: large-text mode is first-class; plan
// Task 1.7f).
void main() {
  setUp(() {
    qrReaderOverride = ({
      required void Function(String text) onText,
      required void Function(CameraController? c, Exception? e)
          onControllerCreated,
    }) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => onControllerCreated(null, null));
      return const ColoredBox(
        key: ValueKey<String>('camera'),
        color: Colors.black,
        child: SizedBox.expand(),
      );
    };
  });
  tearDown(() => qrReaderOverride = null);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  for (final (size, scale) in const [
    (Size(360, 640), 1.3),
    (Size(360, 640), 2.0),
    (Size(412, 915), 2.0),
  ]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()} @${scale}x';
    testWidgets('every pane fits or scrolls, $tag', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [testInPersonPhrase]);
      addTearDown(container.dispose);
      final ctrl = container.read(inPersonPairingControllerProvider.notifier);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: PairExchangeScreen(),
          ),
        ),
      ));
      await settle(tester);

      Future<void> check(String pane) async {
        await settle(tester);
        expect(tester.takeException(), isNull, reason: pane);
      }

      await check('role choice');
      expect(find.textContaining('never a photo or a video call'),
          findsOneWidget);

      await ctrl.begin(InPersonRole.start);
      await check('show QR');
      expect(find.text('NEXT'), findsOneWidget);
      await tester.ensureVisible(find.text('Show the code as text'));
      await tester.tap(find.text('Show the code as text'));
      await check('show as text');

      ctrl.startNext();
      await check('scan');
      // The idle hint must leave the camera usable (it overlays it).
      await tester.pump(const Duration(seconds: 21));
      await check('scan with idle hint');
      final cam = tester.getSize(find.byKey(const ValueKey('camera')));
      expect(cam.height, greaterThan(120), reason: 'camera visible: $cam');
      await tester.tap(find.text('Paste a code instead'));
      await check('paste');

      await ctrl.onScan(PairingCodeV2.encodeKey(Uint8List(32)));
      await check('failed');
      expect(find.text('START OVER'), findsOneWidget);

      await tester.pumpWidget(const SizedBox()); // cancel the screen's timers
      await settle(tester);
    });
  }
}
