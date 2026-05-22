// Shared test stub for the low-level FlutterSecureStorage plugin
// (Android Keystore / iOS Keychain wrapper). Backs the cipher and
// recorder/detector smoke tests in test/logging/.
//
// FakeSecureStore at test/support/fake_secure_store.dart is a DIFFERENT
// abstraction — it fakes Signet's higher-level SecureStore which holds
// Relationship + secret pairs. Don't conflate the two.
//
// Only the three methods our production logging code uses (read / write /
// delete) are implemented. Everything else falls through to noSuchMethod
// with an explicit UnimplementedError so unexpected coupling is loud, not
// silent.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// In-memory FlutterSecureStorage stub backed by a plain Map. Suitable for
/// any test that needs a key-value store with the FlutterSecureStorage
/// interface — does NOT model Keystore behavior (no biometric prompts, no
/// hardware-bound key wrapping, no `resetOnError`).
class InMemoryFlutterSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _store = <String, String>{};

  /// Direct read for test setup / assertions (bypasses the async API).
  Map<String, String> get snapshot => Map.unmodifiable(_store);

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
        'InMemoryFlutterSecureStorage does not implement '
        '${invocation.memberName} — add it to the shared stub if a test '
        'starts needing it (and update the production code path note).',
      );
}
