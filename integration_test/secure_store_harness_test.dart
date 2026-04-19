// Harness for Task 3.4: writes a known-plaintext sentinel through
// SecureStore so we can inspect /data/data/dev.digitalgrease.signet/ on-device
// and confirm no plaintext leaks into SharedPreferences or other app files.
//
// The sentinel values are deliberately ASCII-printable so they show up
// plainly in `cat`/`strings` output if the plugin ever falls back to
// unencrypted storage. Search targets:
//   - label:   "SIGNET_SENTINEL_LABEL_PLAINTEXT"
//   - secret:  bytes spelling "SIGNET_SHARED_SECRET_SENTINEL_32"
//              (32 ASCII bytes; base64 "U0lHTkVUX1NIQVJFRF9TRUNSRVRfU0VOVElORUxfMzI=")
//   - id:      "deadbeefcafefeeddeadbeefcafefeed"
//
// Run with:
//   flutter test integration_test/secure_store_harness_test.dart -d <device-id>
//
// After the test passes, inspect on-device with:
//   adb shell run-as dev.digitalgrease.signet sh -c 'ls -laR .'
//   adb shell run-as dev.digitalgrease.signet sh -c 'cat shared_prefs/*.xml'
// and grep for the sentinel strings above.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/storage/secure_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const sentinelLabel = 'SIGNET_SENTINEL_LABEL_PLAINTEXT';
  const sentinelId = 'deadbeefcafefeeddeadbeefcafefeed';
  final sentinelSecret = Uint8List.fromList(
    utf8.encode('SIGNET_SHARED_SECRET_SENTINEL_32'),
  );

  testWidgets('task 3.4 harness: save sentinel relationship', (tester) async {
    expect(sentinelSecret.length, 32,
        reason: 'sentinel must be exactly 32 bytes');

    final store = SecureStore();
    await store.deleteRelationship();

    final relationship = Relationship(
      id: sentinelId,
      label: sentinelLabel,
      pairedAt: DateTime.utc(2026, 4, 18, 5, 42),
      role: PairRole.a,
    );

    await store.saveRelationship(
      relationship,
      sharedSecret: sentinelSecret,
    );

    // Read back to confirm the write round-trips through the enclave.
    final readBack = await store.getRelationship();
    final readSecret = await store.getSharedSecret();

    expect(readBack, isNotNull);
    expect(readBack!.id, sentinelId);
    expect(readBack.label, sentinelLabel);
    expect(readSecret, isNotNull);
    expect(readSecret, equals(sentinelSecret));

    // Leave the sentinel on disk for the adb inspection step.
    // (Do NOT call deleteRelationship here.)
  });
}
