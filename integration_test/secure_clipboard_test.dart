// On-device check for SecureClipboard (plan Task 2.4): the real native
// channel, a real clipboard, real time.
//
// Run with (takes about five minutes; the last test needs the adb steps
// below):
//   flutter test integration_test/secure_clipboard_test.dart -d <device-id>
//
// While the first test pauses after "SCREENSHOT_NOW", capture the screen
// (`adb exec-out screencap -p > copy.png`): on Android 13+ the system copy
// preview must hide the content of a sensitive clip.
//
// The background test prints "GO_HOME": press Home within a few seconds
// (`adb shell input keyevent KEYCODE_HOME`), wait past the minute, then
// bring the app back (`adb shell monkey -p dev.digitalgrease.signet 1`).
//
// The test reads the clipboard itself to check the result; Signet never
// does that.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:signet/shared/secure_clipboard.dart';

const _secret = 'signet:tp1:ON_DEVICE_CLIPBOARD_SENTINEL';

Future<String?> _clipboardText() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

/// Real-time wait that keeps frames flowing.
Future<void> _wait(WidgetTester tester, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await tester.pump();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(SecureClipboard.resetForTesting);
  tearDown(SecureClipboard.resetForTesting);

  Future<void> app(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: Text('clipboard check'))),
    ));
    await tester.pump();
  }

  testWidgets('copied as plain text, cleared after a minute in the foreground',
      (tester) async {
    await app(tester);
    expect(await SecureClipboard.copy(_secret), SecureCopyResult.protected);
    // ignore: avoid_print
    print('SCREENSHOT_NOW');
    await _wait(tester, const Duration(seconds: 4));
    expect(await _clipboardText(), _secret,
        reason: 'other apps can paste it as plain text');

    await _wait(tester, const Duration(seconds: 50));
    expect(await _clipboardText(), _secret, reason: 'not cleared early');
    await _wait(tester, const Duration(seconds: 10));
    final after = await _clipboardText();
    expect(after == null || after.isEmpty, isTrue,
        reason: 'cleared after a minute, got "$after"');
  });

  testWidgets('a newer copy is left alone', (tester) async {
    await app(tester);
    expect(await SecureClipboard.copy(_secret), SecureCopyResult.protected);
    await _wait(tester, const Duration(seconds: 2));
    await Clipboard.setData(const ClipboardData(text: 'shopping list'));
    await _wait(tester, const Duration(seconds: 62));
    expect(await _clipboardText(), 'shopping list');
  });

  testWidgets(
      'a leftover is cleared at the next start (native record survives '
      'losing the Dart state, as after the process is killed)',
      (tester) async {
    await app(tester);
    expect(await SecureClipboard.copy(_secret), SecureCopyResult.protected);
    // Forget everything on the Dart side; only the native record remains.
    SecureClipboard.resetForTesting();
    await _wait(tester, const Duration(seconds: 62));
    expect(await _clipboardText(), _secret, reason: 'no Dart timer ran');
    await SecureClipboard.clearLeftovers();
    final after = await _clipboardText();
    expect(after == null || after.isEmpty, isTrue,
        reason: 'leftover cleared, got "$after"');
  });

  testWidgets('a clear due while in the background runs on return',
      (tester) async {
    await app(tester);
    expect(await SecureClipboard.copy(_secret), SecureCopyResult.protected);
    // ignore: avoid_print
    print('GO_HOME');
    // Signet is sent to the background now, and brought back after the
    // minute; meanwhile Android hides the clipboard, so the clear waits.
    await _wait(tester, const Duration(seconds: 75));
    final after = await _clipboardText();
    expect(after == null || after.isEmpty, isTrue,
        reason: 'cleared on return, got "$after"');
  });
}
