// Smoke-level coverage of CrashRecorder + CrashDetector together — they
// share the sentinel file format, so testing them in pairs is easier than
// testing each in isolation.
//
// Uses a temp directory + in-memory CrashlogCipher with an injected
// FlutterSecureStorage stub.

import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/logging/crash_detector.dart';
import 'package:signet/core/logging/crash_recorder.dart';
import 'package:signet/core/logging/crashlog_cipher.dart';

void main() {
  late Directory tempDir;
  late CrashlogCipher cipher;
  late CrashRecorder recorder;
  late CrashDetector detector;

  const ctx = CrashContext(
    appVersion: '0.3.4 (30004)',
    osVersion: '14',
    device: 'Pixel 8',
    dartVersion: '3.5.0',
  );

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('signet_crash_test_');
    final storage = _InMemoryStorage();
    cipher = CrashlogCipher(
      storage: storage as FlutterSecureStorage,
      random: Random(42),
    );
    recorder = CrashRecorder(cipher: cipher, crashesDir: tempDir);
    detector = CrashDetector(cipher: cipher, crashesDir: tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('record then read round-trips the report', () async {
    await recorder.record(
      error: const FormatException('Unexpected character'),
      stack: StackTrace.fromString(
        '#0      VerifyScreen.build (package:signet/features/verify/verify_screen.dart:362:5)',
      ),
      context: ctx,
    );

    expect(await detector.hasPendingReport(), isTrue);
    final report = await detector.readPendingReport();
    expect(report, isNotNull);
    expect(report!.appVersion, equals('0.3.4 (30004)'));
    expect(report.osVersion, equals('14'));
    expect(report.device, equals('Pixel 8'));
    // Trace was scrubbed but its known-safe shape survives.
    expect(report.scrubbedTrace, contains('FormatException'));
    expect(report.scrubbedTrace,
        contains('package:signet/features/verify/verify_screen.dart'));
  });

  test('dismissPendingReport deletes the sentinel', () async {
    await recorder.record(
      error: 'boom',
      stack: StackTrace.current,
      context: ctx,
    );
    expect(await detector.hasPendingReport(), isTrue);
    await detector.dismissPendingReport();
    expect(await detector.hasPendingReport(), isFalse);
  });

  test('hasPendingReport is false on fresh directory', () async {
    expect(await detector.hasPendingReport(), isFalse);
    expect(await detector.readPendingReport(), isNull);
  });

  test('24h cooldown skips a second crash within the window', () async {
    var clock = DateTime.utc(2026, 5, 20, 12);
    final recorderWithClock = CrashRecorder(
      cipher: cipher,
      crashesDir: tempDir,
      now: () => clock,
    );

    await recorderWithClock.record(
      error: 'first',
      stack: null,
      context: ctx,
    );
    final firstReport = await detector.readPendingReport();
    expect(firstReport!.scrubbedTrace, contains('first'));

    // 1 hour later — under cooldown, should be a no-op.
    clock = clock.add(const Duration(hours: 1));
    // The sentinel needs to physically exist for the cooldown to fire; but
    // readPendingReport above doesn't delete (only dismiss does). Confirm.
    expect(await detector.hasPendingReport(), isTrue);

    await recorderWithClock.record(
      error: 'second',
      stack: null,
      context: ctx,
    );
    final secondReport = await detector.readPendingReport();
    // The original record is still there, second was suppressed.
    expect(secondReport!.scrubbedTrace, contains('first'));
    expect(secondReport.scrubbedTrace, isNot(contains('second')));
  });

  test('beyond 24h cooldown, second crash overwrites first', () async {
    var clock = DateTime.utc(2026, 5, 20, 12);
    final recorderWithClock = CrashRecorder(
      cipher: cipher,
      crashesDir: tempDir,
      now: () => clock,
    );

    await recorderWithClock.record(
      error: 'old crash',
      stack: null,
      context: ctx,
    );

    clock = clock.add(const Duration(hours: 25));
    await recorderWithClock.record(
      error: 'fresh crash',
      stack: null,
      context: ctx,
    );

    final report = await detector.readPendingReport();
    expect(report!.scrubbedTrace, contains('fresh crash'));
    expect(report.scrubbedTrace, isNot(contains('old crash')));
  });

  test('corrupted sentinel is cleaned up on read', () async {
    final corrupt = File('${tempDir.path}/${CrashRecorder.sentinelFileName}');
    await corrupt.writeAsBytes(<int>[0, 1, 2, 3]); // not a valid blob
    expect(await detector.hasPendingReport(), isTrue);
    expect(await detector.readPendingReport(), isNull);
    expect(await detector.hasPendingReport(), isFalse);
  });
}

class _InMemoryStorage implements FlutterSecureStorage {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '_InMemoryStorage stub does not implement ${invocation.memberName}',
      );
}
