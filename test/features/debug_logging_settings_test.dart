import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signet/core/logging/crashlog_cipher.dart';
import 'package:signet/core/logging/debug_log.dart';
import 'package:signet/core/logging/debug_session.dart';
import 'package:signet/core/prefs/app_prefs.dart';
import 'package:signet/core/prefs/settings_controller.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/features/home/home_screen.dart';
import 'package:signet/features/settings/debug_logging_controller.dart';
import 'package:signet/features/settings/settings_screen.dart';

import '../support/fake_secure_store.dart';
import '../support/in_memory_secure_storage.dart';

DebugLog _wiredDebugLog(Directory dir) {
  final cipher = CrashlogCipher(
    storage: InMemoryFlutterSecureStorage() as FlutterSecureStorage,
    random: Random(1),
    keyStorageKey: 'debuglog.aead_key.v1',
  );
  return DebugLog(session: DebugSession(cipher: cipher, debugDir: dir));
}

void main() {
  group('DebugLoggingController', () {
    test('reports unavailable when no session is wired', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(debugLoggingProvider.notifier).available, isFalse);
      expect(container.read(debugLoggingProvider).active, isFalse);
    });

    test('enable then stop toggles active state', () async {
      final dir = Directory.systemTemp.createTempSync('signet_dlc_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final container = ProviderContainer(
        overrides: [debugLogProvider.overrideWithValue(_wiredDebugLog(dir))],
      );
      addTearDown(container.dispose);

      final ctl = container.read(debugLoggingProvider.notifier);
      expect(ctl.available, isTrue);
      expect(container.read(debugLoggingProvider).active, isFalse);

      await ctl.enable();
      expect(container.read(debugLoggingProvider).active, isTrue);
      expect(container.read(debugLoggingProvider).expiresAt, isNotNull);

      await ctl.stop();
      expect(container.read(debugLoggingProvider).active, isFalse);
    });
  });

  group('Settings DEBUG LOGGING section', () {
    testWidgets('hidden when no session is wired (default provider)',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'signet.onboarding_completed': true,
      });
      final prefs = await AppPrefs.load();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPrefsProvider.overrideWithValue(prefs),
            secureStoreProvider.overrideWithValue(FakeSecureStore()),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('DEBUG LOGGING'), findsNothing);
    });

    testWidgets('wired + inactive shows the OFF state (ENABLE only)',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'signet.onboarding_completed': true,
      });
      final prefs = await AppPrefs.load();
      final dir = Directory.systemTemp.createTempSync('signet_dls_off_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPrefsProvider.overrideWithValue(prefs),
            secureStoreProvider.overrideWithValue(FakeSecureStore()),
            debugLogProvider.overrideWithValue(_wiredDebugLog(dir)),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DEBUG LOGGING'), findsOneWidget);
      expect(find.text('ENABLE DEBUG LOGGING'), findsOneWidget);
      expect(find.text('STOP & WIPE'), findsNothing);
      expect(find.text('EXPORT DEBUG LOGS'), findsNothing);
    });

    testWidgets('a recording session shows the ACTIVE controls', (tester) async {
      // start() does real file I/O, which a testWidgets fake-async zone can't
      // drive — so pre-start the session via runAsync, then render.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'signet.onboarding_completed': true,
      });
      final prefs = await AppPrefs.load();
      final dir = Directory.systemTemp.createTempSync('signet_dls_on_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final debugLog = _wiredDebugLog(dir);
      await tester.runAsync(() => debugLog.session!.start());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPrefsProvider.overrideWithValue(prefs),
            secureStoreProvider.overrideWithValue(FakeSecureStore()),
            debugLogProvider.overrideWithValue(debugLog),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DEBUG LOGGING'), findsOneWidget);
      expect(find.text('EXPORT DEBUG LOGS'), findsOneWidget);
      expect(find.text('STOP & WIPE'), findsOneWidget);
      expect(find.text('ENABLE DEBUG LOGGING'), findsNothing);
    });
  });

  group('Home recording indicator', () {
    testWidgets('banner hidden when not recording', (tester) async {
      final dir = Directory.systemTemp.createTempSync('signet_home_off_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStoreProvider.overrideWithValue(FakeSecureStore()),
            debugLogProvider.overrideWithValue(_wiredDebugLog(dir)),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('DEBUG LOGGING ON'), findsNothing);
    });

    testWidgets('banner shown while a session is recording', (tester) async {
      final dir = Directory.systemTemp.createTempSync('signet_home_on_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final debugLog = _wiredDebugLog(dir);
      await tester.runAsync(() => debugLog.session!.start());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStoreProvider.overrideWithValue(FakeSecureStore()),
            debugLogProvider.overrideWithValue(debugLog),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('DEBUG LOGGING ON'), findsOneWidget);
    });
  });
}
