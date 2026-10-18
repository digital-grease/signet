// SecureStore on a real device: the real Android Keystore / iOS Keychain
// behind flutter_secure_storage, not the in-memory fakes the unit tests
// use. Runs in CI on an emulator (.github/workflows/instrumented-tests.yml).
//
// The leak check (plan Task 3.4) used to be a manual adb inspection. The
// test runs inside the app's own process, so it reads every file under
// the app's data directory itself and fails if a sentinel label or secret
// appears there in plaintext, raw or base64.
//
// Run with:
//   flutter test integration_test/secure_store_harness_test.dart -d <device-id>

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signet/core/crypto/pair_role.dart';
import 'package:signet/core/models/relationship.dart';
import 'package:signet/core/storage/secure_store.dart';

const _label = 'SIGNET_SENTINEL_LABEL_PLAINTEXT';
const _labelV1 = 'SIGNET_SENTINEL_V1_LABEL_PLAINTEXT';
const _id = 'deadbeefcafefeeddeadbeefcafefeed';
final _secret = Uint8List.fromList(
  utf8.encode('SIGNET_SHARED_SECRET_SENTINEL_32'),
);
final _secretV1 = Uint8List.fromList(
  utf8.encode('SIGNET_V1_SECRET_SENTINEL_32BYTE'),
);

/// The same storage SecureStore uses, to start each test empty.
Future<void> _wipe() => const FlutterSecureStorage(
      aOptions: AndroidOptions(
        resetOnError: false,
        preferencesKeyPrefix: 'signet_v1',
      ),
    ).deleteAll();

/// Every file under the app's data directory (the parent of the support
/// directory: files/, shared_prefs/, databases/, ...), skipping the
/// engine's code cache and the bundled app code (a debug build's
/// kernel_blob.bin holds this test's own sentinel constants).
Future<List<File>> _appFiles() async {
  final support = await getApplicationSupportDirectory();
  final root = Platform.isAndroid ? support.parent : support;
  return root
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) =>
          !f.path.contains('/code_cache/') &&
          !f.path.contains('/flutter_assets/'))
      .toList();
}

/// Files whose bytes contain [needle].
Future<List<String>> _filesContaining(List<int> needle) async {
  final hits = <String>[];
  for (final f in await _appFiles()) {
    final List<int> bytes;
    try {
      bytes = await f.readAsBytes();
    } on FileSystemException {
      continue;
    }
    if (_indexOf(bytes, needle) >= 0) hits.add(f.path);
  }
  return hits;
}

int _indexOf(List<int> hay, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= hay.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(_wipe);
  tearDown(_wipe);

  testWidgets('a relationship round-trips through the platform keystore',
      (tester) async {
    final store = SecureStore();
    final rel = Relationship(
      id: _id,
      label: _label,
      pairedAt: DateTime.utc(2026, 4, 18, 5, 42),
      role: PairRole.a,
      silentHaptics: true,
    );
    await store.saveRelationshipV2(rel, sharedSecret: _secret);

    // A fresh instance reads what the first one wrote.
    final again = SecureStore();
    final list = await again.listRelationships();
    expect(list.map((r) => r.id), [_id]);
    expect(list.single.label, _label);
    expect(list.single.role, PairRole.a);
    expect(list.single.silentHaptics, isTrue);
    expect(list.single.pairedAt, DateTime.utc(2026, 4, 18, 5, 42));
    expect(await again.getSharedSecretById(_id), _secret);

    await again.deleteRelationshipById(_id);
    expect(await SecureStore().listRelationships(), isEmpty);
    expect(await SecureStore().getSharedSecretById(_id), isNull);
  });

  testWidgets('a v1 single-slot record migrates to the keyed store',
      (tester) async {
    await SecureStore().saveRelationship(
      Relationship(
        id: _id,
        label: _labelV1,
        pairedAt: DateTime.utc(2025, 7, 4),
        role: PairRole.b,
      ),
      sharedSecret: _secretV1,
    );

    final store = SecureStore();
    final list = await store.listRelationships();
    expect(list.map((r) => r.label), [_labelV1]);
    expect(list.single.role, PairRole.b);
    expect(await store.getSharedSecretById(list.single.id), _secretV1);
  });

  testWidgets('no label or secret is stored in plaintext (plan Task 3.4)',
      (tester) async {
    final store = SecureStore();
    await store.saveRelationshipV2(
      Relationship(
        id: _id,
        label: _label,
        pairedAt: DateTime.utc(2026, 4, 18, 5, 42),
        role: PairRole.a,
      ),
      sharedSecret: _secret,
    );
    expect(await store.getSharedSecretById(_id), _secret);

    // The scan must reach the files the store wrote and find a planted
    // plaintext copy, or a clean result proves nothing.
    final files = (await _appFiles()).map((f) => f.path).toList();
    if (Platform.isAndroid) {
      expect(files.where((p) => p.contains('/shared_prefs/')), isNotEmpty,
          reason: 'storage prefs not reached: $files');
    }
    final planted = File(
        '${(await getApplicationSupportDirectory()).path}/planted.txt');
    await planted.writeAsString('x $_label x');
    expect(await _filesContaining(utf8.encode(_label)), [planted.path]);
    await planted.delete();

    for (final needle in <String, List<int>>{
      'label': utf8.encode(_label),
      'secret': _secret,
      'secret (base64)': utf8.encode(base64.encode(_secret)),
      'secret (base64url)': utf8.encode(base64Url.encode(_secret)),
    }.entries) {
      expect(await _filesContaining(needle.value), isEmpty,
          reason: '${needle.key} found in plaintext');
    }
  });
}
