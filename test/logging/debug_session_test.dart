// DebugSession lifecycle: start / record / restore / export / stop, plus the
// 24h auto-expiry and the byte-cap prune. Uses a temp dir + in-memory cipher
// with an injected clock, mirroring the Phase-7 crash recorder tests.

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/logging/breadcrumb.dart';
import 'package:signet/core/logging/crashlog_cipher.dart';
import 'package:signet/core/logging/debug_session.dart';
import 'package:signet/core/models/relationship.dart';

import '../support/in_memory_secure_storage.dart';

void main() {
  late Directory tempDir;
  late CrashlogCipher cipher;

  Relationship rel(String id, String label) => Relationship(
        id: id,
        label: label,
        pairedAt: DateTime.utc(2026, 1, 1),
        role: PairRole.a,
      );

  Breadcrumb crumb(int atMs, BreadcrumbEvent event, {Relationship? r, int? n}) =>
      Breadcrumb.of(atMs: atMs, event: event, relationship: r, n: n);

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('signet_debug_session_');
    final storage = InMemoryFlutterSecureStorage();
    cipher = CrashlogCipher(
      storage: storage as FlutterSecureStorage,
      random: Random(7),
      keyStorageKey: 'debuglog.aead_key.v1',
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  DebugSession session({DateTime Function()? now, int? maxBytes}) => DebugSession(
        cipher: cipher,
        debugDir: tempDir,
        now: now,
        maxBytes: maxBytes ?? 2 * 1024 * 1024,
      );

  test('start writes an encrypted file; plaintext is not on disk', () async {
    final s = session();
    await s.start();
    expect(s.isActive, isTrue);

    final f = File('${tempDir.path}/${DebugSession.sessionFileName}');
    expect(await f.exists(), isTrue);
    final bytes = await f.readAsBytes();
    // Ciphertext must not contain the recognizable event wire in the clear.
    await s.record(crumb(5, BreadcrumbEvent.verifyStart));
    final after = await f.readAsBytes();
    expect(String.fromCharCodes(after), isNot(contains('verify.start')));
    expect(bytes, isNotEmpty);
  });

  test('record appends events and exportPlaintext returns them', () async {
    final s = session();
    await s.start();
    await s.record(crumb(1, BreadcrumbEvent.verifyStart,
        r: rel('0a1b2c3d4e5f60718293a4b5c6d7e8f9', 'Mom')));
    await s.record(crumb(2, BreadcrumbEvent.verifyResultFail));
    expect(s.eventCount, 2);

    final log = await s.exportPlaintext();
    expect(log, contains('verify.start'));
    expect(log, contains('verify.result.fail'));
    // The export plaintext carries the opaque id (for later <peer-N> mapping),
    // never the label.
    expect(log, contains('ref=0a1b2c3d4e5f60718293a4b5c6d7e8f9'));
    expect(log, isNot(contains('Mom')));
  });

  test('stop deletes the file and clears state', () async {
    final s = session();
    await s.start();
    await s.record(crumb(1, BreadcrumbEvent.appStart));
    await s.stop();
    expect(s.isActive, isFalse);
    expect(s.eventCount, 0);
    final f = File('${tempDir.path}/${DebugSession.sessionFileName}');
    expect(await f.exists(), isFalse);
  });

  test('record is a no-op when inactive', () async {
    final s = session();
    await s.record(crumb(1, BreadcrumbEvent.appStart));
    expect(s.isActive, isFalse);
    expect(s.eventCount, 0);
  });

  test('survives a relaunch: a fresh instance restores the session', () async {
    final a = session();
    await a.start();
    await a.record(crumb(1, BreadcrumbEvent.pairingStart));
    await a.record(crumb(2, BreadcrumbEvent.pairingCommit));

    // New instance, same cipher (same Keystore key) + same dir = relaunch.
    final b = session();
    expect(b.isActive, isFalse);
    final restored = await b.restore();
    expect(restored, isTrue);
    expect(b.isActive, isTrue);
    expect(b.eventCount, 2);
    expect(await b.exportPlaintext(), contains('pairing.commit'));
  });

  test('24h auto-expiry: record past max age wipes the session', () async {
    var clock = DateTime.utc(2026, 6, 12, 9);
    final s = session(now: () => clock);
    await s.start();
    await s.record(crumb(1, BreadcrumbEvent.appStart));

    clock = clock.add(const Duration(hours: 25));
    await s.record(crumb(2, BreadcrumbEvent.navTo));
    expect(s.isActive, isFalse);
    final f = File('${tempDir.path}/${DebugSession.sessionFileName}');
    expect(await f.exists(), isFalse);
  });

  test('restore past max age returns false and wipes', () async {
    var clock = DateTime.utc(2026, 6, 12, 9);
    final a = session(now: () => clock);
    await a.start();
    await a.record(crumb(1, BreadcrumbEvent.appStart));

    clock = clock.add(const Duration(hours: 25));
    final b = session(now: () => clock);
    expect(await b.restore(), isFalse);
    final f = File('${tempDir.path}/${DebugSession.sessionFileName}');
    expect(await f.exists(), isFalse);
  });

  test('byte cap prunes oldest-first', () async {
    // Tiny cap so a handful of events overflow it.
    final s = session(maxBytes: 120);
    await s.start();
    for (var i = 0; i < 40; i++) {
      await s.record(crumb(i, BreadcrumbEvent.navTo, n: i));
    }
    // Pruned below the unbounded count; oldest gone, newest kept.
    expect(s.eventCount, lessThan(40));
    final log = await s.exportPlaintext();
    expect(log, isNot(contains('n=0')));
    expect(log, contains('n=39'));
  });

  test('corrupt session file is wiped on restore', () async {
    final f = File('${tempDir.path}/${DebugSession.sessionFileName}');
    await f.writeAsBytes(<int>[9, 9, 9, 9]);
    final s = session();
    expect(await s.restore(), isFalse);
    expect(await f.exists(), isFalse);
  });

  // L1 / L2: DebugLog fires record() without awaiting, so several persists
  // used to race on one session.bin.tmp. The losing rename threw
  // PathNotFoundException into the zone handler, which recorded a false
  // crash (and the 24h cooldown then hid real ones).
  group('concurrent writes', () {
    DebugSession slowSession() => DebugSession(
          cipher: _SlowCipher(cipher),
          debugDir: tempDir,
        );

    test('rapid unawaited records never throw and persist every event',
        () async {
      final s = slowSession();
      await s.start();
      final errors = <Object>[];
      final pending = <Future<void>>[];
      await runZonedGuarded(() async {
        for (var i = 0; i < 8; i++) {
          pending.add(s.record(crumb(i, BreadcrumbEvent.verifyStart)));
        }
        await Future.wait(pending);
      }, (e, _) => errors.add(e));
      expect(errors, isEmpty);
      expect(File('${tempDir.path}/${DebugSession.sessionFileName}.tmp')
          .existsSync(), isFalse);

      final reloaded = session();
      expect(await reloaded.restore(), isTrue);
      expect(reloaded.eventCount, 8);
    });

    test('stop while a write is in flight leaves no session behind',
        () async {
      final gated = _GatedCipher(cipher)..passThrough = true;
      final s = DebugSession(cipher: gated, debugDir: tempDir);
      await s.start();
      gated.passThrough = false;
      final inFlight = s.record(crumb(1, BreadcrumbEvent.verifyStart));
      await gated.waitForPending(1); // the persist is mid-encrypt
      final stopping = s.stop();
      gated.releaseAll();
      await Future.wait([inFlight, stopping]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(File('${tempDir.path}/${DebugSession.sessionFileName}')
          .existsSync(), isFalse,
          reason: 'a pending write must not resurrect a stopped session');
      expect(await session().restore(), isFalse);
    });

    test('a hung cipher cannot block Stop & wipe, and its late write is dropped',
        () async {
      final gated = _GatedCipher(cipher)..passThrough = true;
      final s = DebugSession(
        cipher: gated,
        debugDir: tempDir,
        ioTimeout: const Duration(milliseconds: 50),
      );
      await s.start();
      final file = File('${tempDir.path}/${DebugSession.sessionFileName}');
      expect(file.existsSync(), isTrue);
      gated.passThrough = false;
      unawaited(s.record(crumb(1, BreadcrumbEvent.verifyStart)));
      await gated.waitForPending(1);
      // The encrypt never returns on its own; stop must still finish and wipe.
      await s.stop();
      expect(file.existsSync(), isFalse);
      // The platform call finally returns, long after stop: it must not
      // write the stopped session back to disk.
      gated.releaseAll();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(file.existsSync(), isFalse);
    });

    test('a crumb recorded across stop + start does not leak into the new '
        'session', () async {
      final s = slowSession();
      await s.start();
      final old = s.record(crumb(1, BreadcrumbEvent.verifyStart));
      final stopping = s.stop();
      await s.start();
      await Future.wait([old, stopping]);
      expect(s.eventCount, 0);
    });

    test('a failed start rolls back and leaves logging off', () async {
      final flaky = _FlakyCipher(cipher)..fail = true;
      final s = DebugSession(cipher: flaky, debugDir: tempDir);
      await expectLater(s.start(), throwsA(isA<StateError>()));
      expect(s.isActive, isFalse);
      flaky.fail = false;
      await s.record(crumb(1, BreadcrumbEvent.verifyStart));
      expect(File('${tempDir.path}/${DebugSession.sessionFileName}')
          .existsSync(), isFalse);
    });

    test('restore removes an orphaned temp file from a killed write',
        () async {
      final temp =
          File('${tempDir.path}/${DebugSession.sessionFileName}.tmp')
            ..writeAsBytesSync(<int>[1, 2, 3]);
      expect(await session().restore(), isFalse);
      expect(temp.existsSync(), isFalse);
    });

    test('a slow earlier write never overwrites a newer snapshot', () async {
      // First persist after start is slow, the next is fast: without the
      // write queue the slow one renamed its older one-event snapshot over
      // the newer two-event file and the second event was lost.
      final gated = _GatedCipher(cipher);
      final s = DebugSession(cipher: gated, debugDir: tempDir);
      gated.passThrough = true;
      await s.start();
      gated.passThrough = false;
      final first = s.record(crumb(1, BreadcrumbEvent.verifyStart));
      await gated.waitForPending(1);
      gated.passThrough = true; // the second persist encrypts immediately
      final second = s.record(crumb(2, BreadcrumbEvent.verifyResultPass));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gated.releaseAll();
      await Future.wait([first, second]);

      final reloaded = session();
      expect(await reloaded.restore(), isTrue);
      expect(reloaded.eventCount, 2);
    });

    test('stop then start without awaiting keeps the new session', () async {
      final s = slowSession();
      await s.start();
      await s.record(crumb(1, BreadcrumbEvent.verifyStart));
      final stopping = s.stop();
      final starting = s.start();
      await Future.wait([stopping, starting]);
      await s.record(crumb(2, BreadcrumbEvent.verifyStart));
      final reloaded = session();
      expect(await reloaded.restore(), isTrue);
      expect(reloaded.eventCount, 1, reason: 'only the new session event');
    });

    test('record after stop is a silent no-op', () async {
      final s = slowSession();
      await s.start();
      await s.stop();
      await s.record(crumb(1, BreadcrumbEvent.verifyStart));
      expect(File('${tempDir.path}/${DebugSession.sessionFileName}')
          .existsSync(), isFalse);
    });

    test('an I/O failure inside record does not throw', () async {
      final s = slowSession();
      await s.start();
      // Make the debug dir unusable: replace it with a regular file.
      tempDir.deleteSync(recursive: true);
      File(tempDir.path).writeAsStringSync('not a directory');
      await expectLater(
          s.record(crumb(1, BreadcrumbEvent.verifyStart)), completes);
      File(tempDir.path).deleteSync();
      tempDir.createSync();
    });
  });
}

/// Wraps a real cipher and adds latency so persists overlap the way they do
/// on device, where encryption goes through a Keystore platform-channel hop.
class _SlowCipher implements CrashlogCipher {
  _SlowCipher(this._inner);

  final CrashlogCipher _inner;
  int _calls = 0;

  @override
  Future<Uint8List> encrypt(List<int> plaintext) async {
    // Alternate delays so later calls can finish before earlier ones.
    _calls++;
    await Future<void>.delayed(Duration(milliseconds: _calls.isOdd ? 20 : 2));
    return _inner.encrypt(plaintext);
  }

  @override
  Future<Uint8List> decrypt(List<int> blob) => _inner.decrypt(blob);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Holds encrypt calls until released, so a test can order persists exactly.
class _GatedCipher implements CrashlogCipher {
  _GatedCipher(this._inner);

  final CrashlogCipher _inner;
  bool passThrough = false;
  final List<Completer<void>> _gates = <Completer<void>>[];

  Future<void> waitForPending(int n) async {
    while (_gates.length < n) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  void releaseAll() {
    for (final g in _gates) {
      if (!g.isCompleted) g.complete();
    }
  }

  @override
  Future<Uint8List> encrypt(List<int> plaintext) async {
    if (!passThrough) {
      final gate = Completer<void>();
      _gates.add(gate);
      await gate.future;
    }
    return _inner.encrypt(plaintext);
  }

  @override
  Future<Uint8List> decrypt(List<int> blob) => _inner.decrypt(blob);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Throws from encrypt while [fail] is set, like an unavailable Keystore.
class _FlakyCipher implements CrashlogCipher {
  _FlakyCipher(this._inner);

  final CrashlogCipher _inner;
  bool fail = false;

  @override
  Future<Uint8List> encrypt(List<int> plaintext) async {
    if (fail) throw StateError('keystore unavailable');
    return _inner.encrypt(plaintext);
  }

  @override
  Future<Uint8List> decrypt(List<int> blob) => _inner.decrypt(blob);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
