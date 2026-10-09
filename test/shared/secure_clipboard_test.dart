// SecureClipboard (plan Task 2.4, bugs S6 + R4): secrets go to the native
// sensitive-copy channel, are cleared after a minute only through
// "clearIfOurs" (never by reading the clipboard), and a clear that falls
// due in the background is retried on resume.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/shared/secure_clipboard.dart';

const _channel = MethodChannel('dev.digitalgrease.signet/clipboard');

void main() {
  late List<MethodCall> calls;
  late List<String> clearOutcomes;
  late List<String?> plainCopies;
  late String copyReply;

  TestDefaultBinaryMessenger messenger() =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void installNative() {
    messenger().setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      if (call.method == 'copySensitive') return copyReply;
      if (call.method == 'clearIfOurs') {
        return clearOutcomes.isEmpty ? 'cleared' : clearOutcomes.removeAt(0);
      }
      return null;
    });
  }

  setUp(() {
    calls = [];
    clearOutcomes = [];
    plainCopies = [];
    copyReply = 'tracked';
    SecureClipboard.resetForTesting();
    messenger().setMockMethodCallHandler(SystemChannels.platform,
        (call) async {
      if (call.method == 'Clipboard.setData') {
        plainCopies.add((call.arguments as Map)['text'] as String?);
      }
      return null;
    });
  });

  tearDown(() {
    SecureClipboard.resetForTesting();
    messenger().setMockMethodCallHandler(_channel, null);
    messenger().setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// Every test ends by cancelling the pending clear timer: the widget
  /// test binding fails a test that leaves a timer running.
  void clipTest(String description, Future<void> Function(WidgetTester) body) {
    testWidgets(description, (tester) async {
      await body(tester);
      SecureClipboard.resetForTesting();
    });
  }

  int clears() => calls.where((c) => c.method == 'clearIfOurs').length;

  Future<void> backgroundThenResume(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  }

  clipTest('copies through the sensitive channel, not the plain clipboard',
      (tester) async {
    installNative();
    expect(await SecureClipboard.copy('signet:tp1:SECRET'),
        SecureCopyResult.protected);
    expect(calls.single.method, 'copySensitive');
    expect(calls.single.arguments,
        <String, Object>{'text': 'signet:tp1:SECRET', 'expiresInMs': 60000});
    expect(plainCopies, isEmpty);
  });

  clipTest('clears after a minute, not before',
      (tester) async {
    installNative();
    await SecureClipboard.copy('signet:tp1:SECRET');
    await tester.pump(const Duration(seconds: 59));
    expect(clears(), 0);
    await tester.pump(const Duration(seconds: 1));
    expect(clears(), 1);
  });

  clipTest('a clear due in the background is retried on resume',
      (tester) async {
    installNative();
    clearOutcomes = ['unknown', 'cleared'];
    await SecureClipboard.copy('signet:tp1:SECRET');
    await tester.pump(const Duration(seconds: 60));
    expect(clears(), 1);
    await backgroundThenResume(tester);
    expect(clears(), 2, reason: 'retried once back in the foreground');
    await backgroundThenResume(tester);
    expect(clears(), 2, reason: 'done after "cleared"');
  });

  clipTest('something copied since is left alone and not retried',
      (tester) async {
    installNative();
    clearOutcomes = ['notOurs'];
    await SecureClipboard.copy('signet:tp1:SECRET');
    await tester.pump(const Duration(seconds: 60));
    await backgroundThenResume(tester);
    expect(clears(), 1);
  });

  clipTest('resuming before the minute is up does not clear early',
      (tester) async {
    installNative();
    await SecureClipboard.copy('signet:tp1:SECRET');
    await tester.pump(const Duration(seconds: 10));
    await backgroundThenResume(tester);
    expect(clears(), 0);
  });

  clipTest('a second copy restarts the minute', (tester) async {
    installNative();
    await SecureClipboard.copy('signet:tp1:FIRST');
    await tester.pump(const Duration(seconds: 50));
    await SecureClipboard.copy('signet:tp1:SECOND');
    await tester.pump(const Duration(seconds: 50));
    expect(clears(), 0);
    await tester.pump(const Duration(seconds: 10));
    expect(clears(), 1);
  });

  clipTest('without the native channel it falls back to a plain copy',
      (tester) async {
    messenger().setMockMethodCallHandler(_channel, (call) async {
      throw MissingPluginException();
    });
    expect(await SecureClipboard.copy('signet:tp1:SECRET'),
        SecureCopyResult.plain);
    expect(plainCopies, <String?>['signet:tp1:SECRET']);
    await tester.pump(const Duration(seconds: 60));
    expect(calls, isEmpty, reason: 'no clear promised, none attempted');
  });

  clipTest('a new copy drops a clear still pending for the old one',
      (tester) async {
    // The old clear must not run after the new copy: native would see the
    // new clip as "ours" and remove it at once.
    installNative();
    clearOutcomes = ['unknown'];
    await SecureClipboard.copy('signet:tp1:FIRST');
    await tester.pump(const Duration(seconds: 60));
    expect(clears(), 1, reason: 'due, but Signet lacked focus');
    await SecureClipboard.copy('signet:tp1:SECOND');
    await backgroundThenResume(tester);
    expect(clears(), 1, reason: 'the first clear was dropped');
    await tester.pump(const Duration(seconds: 60));
    expect(clears(), 2, reason: 'the second copy is cleared on time');
  });

  clipTest('a native failure reports "failed" and arms nothing',
      (tester) async {
    messenger().setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      if (call.method == 'copySensitive') {
        throw PlatformException(code: 'TransactionTooLarge');
      }
      return 'cleared';
    });
    expect(await SecureClipboard.copy('signet:tp1:SECRET'),
        SecureCopyResult.failed);
    await tester.pump(const Duration(seconds: 60));
    expect(clears(), 0);
  });

  clipTest('a clip Android would not identify is "plain", never cleared',
      (tester) async {
    installNative();
    copyReply = 'untracked';
    expect(await SecureClipboard.copy('signet:tp1:SECRET'),
        SecureCopyResult.plain);
    await tester.pump(const Duration(seconds: 60));
    expect(clears(), 0);
  });

  clipTest('a leftover from a killed run is cleared at start, retried once '
      'shortly after and then on resume', (tester) async {
    installNative();
    clearOutcomes = ['unknown', 'notYet', 'cleared'];
    await SecureClipboard.clearLeftovers();
    expect(clears(), 1);
    await tester.pump(const Duration(seconds: 3));
    expect(clears(), 2);
    await backgroundThenResume(tester);
    expect(clears(), 3);
    await backgroundThenResume(tester);
    expect(clears(), 3, reason: 'done after "cleared"');
  });
}
