// Task 3.4 on-device harness. Run with:
//   flutter run -t lib/dev/secure_store_harness_main.dart -d <device>
//
// On launch this saves a known-plaintext sentinel Relationship + shared
// secret through SecureStore and keeps the app alive so that
// `adb shell run-as dev.digitalgrease.signet ...` can inspect /data/data to verify
// that the secret is not lying around as plaintext in SharedPreferences
// or anywhere else inside the app sandbox.
//
// Sentinel markers (all ASCII-printable for easy grep):
//   - label:  SIGNET_SENTINEL_LABEL_PLAINTEXT
//   - id:     deadbeefcafefeeddeadbeefcafefeed
//   - secret: SIGNET_SHARED_SECRET_SENTINEL_32 (32 raw bytes)
//             base64: U0lHTkVUX1NIQVJFRF9TRUNSRVRfU0VOVElORUxfMzI=

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/crypto/pair_role.dart';
import '../core/models/relationship.dart';
import '../core/storage/secure_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _HarnessApp());
}

class _HarnessApp extends StatefulWidget {
  const _HarnessApp();

  @override
  State<_HarnessApp> createState() => _HarnessAppState();
}

class _HarnessAppState extends State<_HarnessApp> {
  String _status = 'Writing sentinel...';
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      const sentinelLabel = 'SIGNET_SENTINEL_LABEL_PLAINTEXT';
      const sentinelId = 'deadbeefcafefeeddeadbeefcafefeed';
      final sentinelSecret = Uint8List.fromList(
        utf8.encode('SIGNET_SHARED_SECRET_SENTINEL_32'),
      );

      final store = SecureStore();
      await store.deleteRelationship();
      await store.saveRelationship(
        Relationship(
          id: sentinelId,
          label: sentinelLabel,
          pairedAt: DateTime.utc(2026, 4, 18, 5, 42),
          role: PairRole.a,
        ),
        sharedSecret: sentinelSecret,
      );

      final readBack = await store.getRelationship();
      final readSecret = await store.getSharedSecret();
      final match = readBack?.id == sentinelId &&
          readBack?.label == sentinelLabel &&
          readSecret != null &&
          readSecret.length == sentinelSecret.length &&
          _constTimeEq(readSecret, sentinelSecret);

      setState(() {
        _status = match
            ? 'SENTINEL WRITTEN AND ROUND-TRIPPED — inspect now'
            : 'SENTINEL WRITE ROUND-TRIP FAILED';
      });
    } catch (e, st) {
      setState(() {
        _status = 'ERROR';
        _error = '$e\n$st';
      });
    }
  }

  static bool _constTimeEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_status, textAlign: TextAlign.center),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  SelectableText(_error!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
