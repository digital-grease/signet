import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signet/core/logging/breadcrumb.dart';
import 'package:signet/core/logging/crashlog_cipher.dart';
import 'package:signet/core/logging/debug_log.dart';
import 'package:signet/core/logging/debug_session.dart';
import 'package:signet/core/prefs/app_prefs.dart';
import 'package:signet/core/prefs/settings_controller.dart';
import 'package:signet/core/providers.dart';
import 'package:signet/features/home/home_screen.dart';
import 'package:signet/features/settings/debug_logging_controller.dart';
import 'package:signet/features/settings/settings_screen.dart';
import 'package:signet/l10n/app_localizations.dart';

import '../support/fake_secure_store.dart';
import '../support/test_prefs.dart';
import '../support/in_memory_secure_storage.dart';

DebugLog _wiredDebugLog(Directory dir, {DateTime Function()? now}) {
  final cipher = CrashlogCipher(
    storage: InMemoryFlutterSecureStorage() as FlutterSecureStorage,
    random: Random(1),
    keyStorageKey: 'debuglog.aead_key.v1',
  );
  return DebugLog(
      session: DebugSession(cipher: cipher, debugDir: dir, now: now));
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

  group('24-hour expiry while the app is open (plan Task 5.3)', () {
    Directory tempDir() {
      final dir = Directory.systemTemp.createTempSync('signet_dlx_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      return dir;
    }

    test('the state clears when the 24 hours run out', () async {
      // Start "23:59:59.7 ago", then let the clock run normally: the
      // session expires about 0.3 s later.
      var offset = const Duration(hours: -24) + const Duration(milliseconds: 300);
      final container = ProviderContainer(overrides: [
        debugLogProvider.overrideWithValue(_wiredDebugLog(tempDir(),
            now: () => DateTime.now().toUtc().add(offset))),
      ]);
      addTearDown(container.dispose);
      await container.read(debugLoggingProvider.notifier).enable();
      offset = Duration.zero;
      expect(container.read(debugLoggingProvider).active, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      expect(container.read(debugLoggingProvider).active, isFalse);
    });

    test('a breadcrumb written after the expiry, which wipes the session '
        'itself, still clears the state (Phase 5 review)', () async {
      var offset = Duration.zero;
      final log = _wiredDebugLog(tempDir(),
          now: () => DateTime.now().toUtc().add(offset));
      final container = ProviderContainer(
          overrides: [debugLogProvider.overrideWithValue(log)]);
      addTearDown(container.dispose);
      await container.read(debugLoggingProvider.notifier).enable();
      offset = const Duration(hours: 25);
      log.log(BreadcrumbEvent.appStart); // wipes the expired session
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(log.session!.isActive, isFalse);
      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(container.read(debugLoggingProvider).active, isFalse);
    });

    test('coming back to the app after the 24 hours clears it', () async {
      var offset = Duration.zero;
      final container = ProviderContainer(overrides: [
        debugLogProvider.overrideWithValue(_wiredDebugLog(tempDir(),
            now: () => DateTime.now().toUtc().add(offset))),
      ]);
      addTearDown(container.dispose);
      await container.read(debugLoggingProvider.notifier).enable();
      expect(container.read(debugLoggingProvider).active, isTrue);

      // A day passes with the app in the background (no timer ran).
      offset = const Duration(hours: 25);
      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 200));
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
          child: const MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, home: SettingsScreen()),
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
          child: const MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, home: SettingsScreen()),
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
          child: const MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, home: SettingsScreen()),
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
            appPrefsProvider.overrideWithValue(await testPrefs()),
          ],
          child: const MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, home: HomeScreen()),
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
            appPrefsProvider.overrideWithValue(await testPrefs()),
          ],
          child: const MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, home: HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('DEBUG LOGGING ON'), findsOneWidget);
    });
  });
}
