import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/logging/breadcrumb.dart';
import 'core/logging/crash_detector.dart';
import 'core/logging/crash_recorder.dart';
import 'core/logging/crashlog_cipher.dart';
import 'core/logging/debug_log.dart';
import 'core/logging/debug_session.dart';
import 'core/prefs/app_prefs.dart';
import 'core/prefs/settings_controller.dart';
import 'core/providers.dart';
import 'core/storage/secure_store.dart';
import 'dev/mock_contacts.dart';

Future<void> main() async {
  // Wrap everything in runZonedGuarded so any uncaught error during boot —
  // including before Flutter takes over — funnels through CrashRecorder.
  // Nullable so the zone handler can no-op safely if the recorder hasn't
  // been initialised yet (extremely early-boot errors aren't recordable,
  // which is acceptable for v1).
  CrashRecorder? recorder;
  CrashContext? crashContext;

  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // cryptography_flutter auto-registers itself as Cryptography.instance at
    // plugin-init time and routes HMAC (and thus HKDF) through a platform
    // MethodChannel on Android. We've seen that channel dispatch stall for
    // minutes on Android-16 x86_64 emulators during pair-derivation, and the
    // "native acceleration" wins nothing for our workload (a handful of
    // 32-byte HMACs per pair + one per TOTP tick). Pin the pure-Dart impl.
    // This also matches the project's pinned crypto-is-pure-Dart convention.
    Cryptography.instance = DartCryptography.defaultInstance;

    // ---- Crash logging plumbing ----
    final cipher = CrashlogCipher();
    final supportDir = await getApplicationSupportDirectory();
    final crashesDir = Directory('${supportDir.path}/crashes');
    final detector = CrashDetector(cipher: cipher, crashesDir: crashesDir);

    // ---- Debug logging plumbing (Phase 8, opt-in) ----
    // Distinct AES key from the crash sentinel so resetting one never wipes
    // the other. restore() resumes an in-flight session across a relaunch.
    final debugCipher =
        CrashlogCipher(keyStorageKey: 'debuglog.aead_key.v1');
    final debugDir = Directory('${supportDir.path}/debug');
    final debugSession = DebugSession(cipher: debugCipher, debugDir: debugDir);
    await debugSession.restore();
    final debugLog = DebugLog(session: debugSession);

    recorder = CrashRecorder(
      cipher: cipher,
      crashesDir: crashesDir,
      breadcrumbDump: () => debugLog.breadcrumbDump(),
    );
    crashContext = await _buildCrashContext();
    debugLog.log(BreadcrumbEvent.appStart);

    // Two of the three error boundaries (the third is the surrounding
    // runZonedGuarded). All three funnel into recorder.record() so the
    // scrubber + cipher pipeline has a single audit point.
    final r = recorder;
    final c = crashContext;
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      if (r != null && c != null) {
        unawaited(
          r.record(
            error: details.exception,
            stack: details.stack,
            context: c,
          ),
        );
      }
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (r != null && c != null) {
        unawaited(r.record(error: error, stack: stack, context: c));
      }
      return true;
    };

    final pendingReport = await detector.readPendingReport();

    // ---- Pre-runApp app setup ----
    final prefs = await AppPrefs.load();
    if (mockContactsEnabled) {
      await seedMockContactsIfEnabled(SecureStore());
      await prefs.setOnboardingCompleted(true);
    }

    runApp(
      ProviderScope(
        overrides: [
          appPrefsProvider.overrideWithValue(prefs),
          debugLogProvider.overrideWithValue(debugLog),
        ],
        child: SignetApp(
          prefs: prefs,
          pendingCrash: pendingReport,
          crashDetector: detector,
        ),
      ),
    );
  }, (Object error, StackTrace stack) {
    // Last-resort zone error handler — covers anything that wasn't already
    // caught by FlutterError.onError / PlatformDispatcher.onError. If the
    // recorder isn't initialised yet (very-early-boot error), there's
    // nowhere to record; let the error propagate to OS-level crash handling.
    final r = recorder;
    final c = crashContext;
    if (r != null && c != null) {
      unawaited(r.record(error: error, stack: stack, context: c));
    }
  });
}

/// Gather platform/app context for [CrashRecorder]. Best-effort — if any
/// platform plugin throws (e.g., unsupported platform), the corresponding
/// field falls back to `"unknown"`. Phase 7.2's `CrashContext` is just a
/// data carrier; the recorder doesn't validate its content.
Future<CrashContext> _buildCrashContext() async {
  final packageInfo = await PackageInfo.fromPlatform();
  final appVersion =
      '${packageInfo.version} (${packageInfo.buildNumber})';
  var osVersion = 'unknown';
  var device = 'unknown';
  try {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;
      osVersion = android.version.release;
      device = '${android.manufacturer} ${android.model}';
    } else if (Platform.isIOS) {
      final ios = await deviceInfo.iosInfo;
      osVersion = ios.systemVersion;
      device = '${ios.utsname.machine} (${ios.model})';
    }
  } on Object {
    // Best-effort — leave defaults if platform info isn't readable.
  }
  return CrashContext(
    appVersion: appVersion,
    osVersion: osVersion,
    device: device,
    dartVersion: Platform.version,
  );
}
