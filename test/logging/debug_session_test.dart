// DebugSession lifecycle: start / record / restore / export / stop, plus the
// 24h auto-expiry and the byte-cap prune. Uses a temp dir + in-memory cipher
// with an injected clock, mirroring the Phase-7 crash recorder tests.

import 'dart:io';
import 'dart:math';

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
}
