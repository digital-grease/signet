import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/prefs/app_prefs.dart';
import 'core/prefs/settings_controller.dart';
import 'core/storage/secure_store.dart';
import 'dev/mock_contacts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // cryptography_flutter auto-registers itself as Cryptography.instance at
  // plugin-init time and routes HMAC (and thus HKDF) through a platform
  // MethodChannel on Android. We've seen that channel dispatch stall for
  // minutes on Android-16 x86_64 emulators during pair-derivation, and the
  // "native acceleration" wins nothing for our workload (a handful of
  // 32-byte HMACs per pair + one per TOTP tick). Pin the pure-Dart impl.
  // This also matches the project's pinned crypto-is-pure-Dart convention.
  Cryptography.instance = DartCryptography.defaultInstance;
  final prefs = await AppPrefs.load();
  // Also mark onboarding as completed when seeding mocks, so the home
  // screen renders directly instead of the first-run walkthrough.
  if (mockContactsEnabled) {
    await seedMockContactsIfEnabled(SecureStore());
    await prefs.setOnboardingCompleted(true);
  }
  runApp(
    ProviderScope(
      overrides: [
        appPrefsProvider.overrideWithValue(prefs),
      ],
      child: SignetApp(prefs: prefs),
    ),
  );
}
