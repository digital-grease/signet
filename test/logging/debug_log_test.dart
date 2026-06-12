import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/logging/breadcrumb.dart';
import 'package:signet/core/logging/crashlog_cipher.dart';
import 'package:signet/core/logging/debug_log.dart';
import 'package:signet/core/logging/debug_session.dart';
import 'package:signet/core/models/relationship.dart';

import '../support/in_memory_secure_storage.dart';

void main() {
  Relationship rel(String id, String label) => Relationship(
        id: id,
        label: label,
        pairedAt: DateTime.utc(2026, 1, 1),
        role: PairRole.a,
      );

  test('log always feeds the in-memory ring', () {
    final log = DebugLog();
    log.log(BreadcrumbEvent.appStart);
    log.log(BreadcrumbEvent.verifyResultFail);
    final dump = log.breadcrumbDump();
    expect(dump, contains('app.start'));
    expect(dump, contains('verify.result.fail'));
  });

  test('atMs is relative to construction epoch', () {
    var clock = DateTime.utc(2026, 6, 12, 9, 0, 0);
    final log = DebugLog(now: () => clock);
    clock = clock.add(const Duration(milliseconds: 250));
    log.log(BreadcrumbEvent.navTo);
    expect(log.breadcrumbDump(), contains('+250ms nav.to'));
  });

  test('relationship is logged by opaque id, never label', () {
    final log = DebugLog();
    log.log(
      BreadcrumbEvent.verifyStart,
      relationship: rel('0a1b2c3d4e5f60718293a4b5c6d7e8f9', 'Mom'),
    );
    final dump = log.breadcrumbDump();
    expect(dump, contains('ref=0a1b2c3d4e5f60718293a4b5c6d7e8f9'));
    expect(dump, isNot(contains('Mom')));
  });

  test('routes to the active session as well as the ring', () async {
    final tempDir =
        Directory.systemTemp.createTempSync('signet_debug_log_route_');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    final cipher = CrashlogCipher(
      storage: InMemoryFlutterSecureStorage() as FlutterSecureStorage,
      random: Random(3),
      keyStorageKey: 'debuglog.aead_key.v1',
    );
    final session = DebugSession(cipher: cipher, debugDir: tempDir);
    await session.start();

    final log = DebugLog(session: session);
    log.log(BreadcrumbEvent.pairingCommit);

    // record() is fire-and-forget async; let the microtask + file write settle.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(session.eventCount, 1);
    expect(await session.exportPlaintext(), contains('pairing.commit'));
  });

  test('does not route to an inactive session', () async {
    final tempDir =
        Directory.systemTemp.createTempSync('signet_debug_log_inactive_');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    final cipher = CrashlogCipher(
      storage: InMemoryFlutterSecureStorage() as FlutterSecureStorage,
      random: Random(3),
      keyStorageKey: 'debuglog.aead_key.v1',
    );
    final session = DebugSession(cipher: cipher, debugDir: tempDir);
    // not started → inactive
    final log = DebugLog(session: session);
    log.log(BreadcrumbEvent.appStart);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(session.eventCount, 0);
    // ring still captured it
    expect(log.breadcrumbDump(), contains('app.start'));
  });
}
