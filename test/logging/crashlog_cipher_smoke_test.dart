// Smoke-level coverage of CrashlogCipher. Phase 7.4 will expand with
// adversarial cases (truncated blob, tampered tag, wrong key reuse).
//
// Uses a Mock FlutterSecureStorage backed by an in-memory map so tests
// run without the real platform plugin.

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signet/core/logging/crashlog_cipher.dart';

void main() {
  late _InMemoryStorage storage;
  late CrashlogCipher cipher;

  setUp(() {
    storage = _InMemoryStorage();
    // Seeded RNG for determinism. Production uses Random.secure().
    cipher = CrashlogCipher(storage: storage as FlutterSecureStorage, random: Random(42));
  });

  test('encrypt + decrypt round-trips a UTF-8 payload', () async {
    final plaintext = Uint8List.fromList(
      'hello signet crash log — line 2'.codeUnits,
    );
    final blob = await cipher.encrypt(plaintext);
    final recovered = await cipher.decrypt(blob);
    expect(recovered, equals(plaintext));
  });

  test('blob is shorter than the plaintext only for very short inputs', () async {
    // Overhead = 12-byte nonce + 16-byte tag = 28 bytes.
    final plaintext = Uint8List.fromList(List<int>.filled(1024, 0x41));
    final blob = await cipher.encrypt(plaintext);
    expect(blob.length, equals(plaintext.length + 28));
  });

  test('key persists across encrypt calls (same blob decrypts after re-instantiation)', () async {
    final pt = Uint8List.fromList('persist me'.codeUnits);
    final blob = await cipher.encrypt(pt);

    // New cipher instance sharing the same storage = same key.
    final cipher2 = CrashlogCipher(
      storage: storage as FlutterSecureStorage,
      random: Random(99),
    );
    final recovered = await cipher2.decrypt(blob);
    expect(recovered, equals(pt));
  });

  test('decrypt throws on truncated blob', () async {
    final tiny = Uint8List.fromList(<int>[1, 2, 3]);
    expect(() => cipher.decrypt(tiny), throwsException);
  });

  test('decrypt throws on tampered ciphertext byte', () async {
    final pt = Uint8List.fromList('keep me safe'.codeUnits);
    final blob = await cipher.encrypt(pt);
    // Flip a ciphertext byte (avoid nonce header + tag).
    final tampered = Uint8List.fromList(blob);
    tampered[20] ^= 0xFF;
    expect(() => cipher.decrypt(tampered), throwsException);
  });

  test('resetKey makes prior blobs undecryptable', () async {
    final pt = Uint8List.fromList('forget me'.codeUnits);
    final blob = await cipher.encrypt(pt);
    await cipher.resetKey();
    expect(() => cipher.decrypt(blob), throwsException);
  });
}

/// In-memory FlutterSecureStorage stub for tests. Implements only the
/// methods CrashlogCipher uses; everything else throws if accidentally
/// hit so we notice unexpected coupling.
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
  }) async => _store[key];

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
