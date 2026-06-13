import 'dart:convert';
import 'dart:io';

import 'crashlog_cipher.dart';
import 'log_scrubber.dart';

/// Platform + app context captured at crash time. Provided by the caller
/// rather than read from `package_info_plus` / `device_info_plus` inside
/// the recorder, so the recorder stays pure-Dart and easily testable.
///
/// Phase 7.3's `main.dart` wiring is responsible for gathering these via
/// the platform plugins and passing them in.
class CrashContext {
  const CrashContext({
    required this.appVersion,
    required this.osVersion,
    required this.device,
    required this.dartVersion,
  });

  /// `${version}+${versionCode}` from `pubspec.yaml`. Mirrors the
  /// `app_version` form field on `crash_report.yml`.
  final String appVersion;

  /// OS major version: `Build.VERSION.RELEASE` on Android, system version
  /// string on iOS. Mirrors the `os_version` form field.
  final String osVersion;

  /// `${Build.MANUFACTURER} ${Build.MODEL}` on Android, equivalent on iOS.
  /// Mirrors the `device` form field.
  final String device;

  /// `Platform.version` — Dart runtime version. Helpful when triaging a
  /// stack frame against a specific Dart SDK release.
  final String dartVersion;
}

/// A single recorded crash. Persisted as encrypted JSON on disk and read
/// back by [CrashDetector] on the next app launch.
class CrashReport {
  const CrashReport({
    required this.recordedAt,
    required this.scrubbedTrace,
    required this.appVersion,
    required this.osVersion,
    required this.device,
    required this.dartVersion,
  });

  /// When the crash was recorded (UTC).
  final DateTime recordedAt;

  /// Stack trace + exception summary, post-[LogScrubber].
  final String scrubbedTrace;

  final String appVersion;
  final String osVersion;
  final String device;
  final String dartVersion;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'scrubbedTrace': scrubbedTrace,
        'appVersion': appVersion,
        'osVersion': osVersion,
        'device': device,
        'dartVersion': dartVersion,
      };

  factory CrashReport.fromJson(Map<String, dynamic> map) => CrashReport(
        recordedAt: DateTime.parse(map['recordedAt']! as String).toUtc(),
        scrubbedTrace: map['scrubbedTrace']! as String,
        appVersion: map['appVersion']! as String,
        osVersion: map['osVersion']! as String,
        device: map['device']! as String,
        dartVersion: map['dartVersion']! as String,
      );
}

/// Single funnel for the three Flutter error boundaries (FlutterError.onError,
/// PlatformDispatcher.instance.onError, runZonedGuarded). All three call
/// [record] so the scrubber + encryptor have one audit point.
///
/// **Layer 1.5** of the four-layer defense in `.devloop/spikes/log-shipping.md`:
/// the recorder is the orchestrator that runs [LogScrubber] (layer 2) and
/// hands off to [CrashlogCipher] (layer 3). It is not itself a defense layer
/// but is the choke point that makes those layers reliable.
///
/// Crash-storm protection: if a pending crash file already exists and is
/// younger than [cooldown], [record] returns without overwriting. Protects
/// users from a crash-every-launch loop where the dialog fires repeatedly.
class CrashRecorder {
  CrashRecorder({
    required this.cipher,
    required this.crashesDir,
    DateTime Function()? now,
    Duration cooldown = const Duration(hours: 24),
    String Function()? breadcrumbDump,
  })  : _now = now ?? (() => DateTime.now().toUtc()),
        _cooldown = cooldown,
        _breadcrumbDump = breadcrumbDump;

  final CrashlogCipher cipher;

  /// Directory where the sentinel file lives. Phase 7.3 wiring sets this
  /// to `<getApplicationSupportDirectory()>/crashes`.
  final Directory crashesDir;

  final DateTime Function() _now;
  final Duration _cooldown;

  /// Optional source of the in-memory breadcrumb dump (Phase 8). When wired,
  /// the lead-up to the crash is appended beneath the trace, then the whole
  /// thing is scrubbed together — so breadcrumb ids/labels get the same
  /// `LogScrubber` treatment as the trace.
  final String Function()? _breadcrumbDump;

  /// Filename for the (single) pending-crash sentinel.
  static const String sentinelFileName = 'last.bin';

  /// Record [error] + [stack] for surfacing on the next launch. Idempotent
  /// under the cooldown: a second crash within [_cooldown] is a no-op.
  Future<void> record({
    required Object error,
    required StackTrace? stack,
    required CrashContext context,
  }) async {
    // Crash-storm cooldown — if an existing sentinel's recordedAt is
    // younger than [_cooldown], leave it in place.
    //
    // We decrypt the existing sentinel to read its recordedAt timestamp
    // rather than using file mtime, because the recorder's injected clock
    // (used in tests, and useful for time-zone-independent scheduling) lives
    // in a separate time-space from OS-managed file mtimes. The cost is one
    // extra decrypt per crash, which only fires once-per-crash anyway.
    final sentinel = _sentinelFile();
    if (await sentinel.exists()) {
      try {
        final existingCiphertext = await sentinel.readAsBytes();
        final existingPlaintext = await cipher.decrypt(existingCiphertext);
        final existing = CrashReport.fromJson(
          jsonDecode(utf8.decode(existingPlaintext)) as Map<String, dynamic>,
        );
        if (_now().difference(existing.recordedAt.toUtc()) < _cooldown) return;
      } on Object {
        // Corrupt sentinel (decrypt fail, JSON parse fail, etc.) — fall
        // through and overwrite. Better to surface the fresh crash than
        // to be stuck behind a corrupt sentinel that we'll never read.
      }
    }

    // Compose the raw trace string. Exception toString() first, then the
    // stack frames. The toString() path is exactly what gets surfaced to
    // the user via the OS-level "App stopped" dialog when we don't catch.
    final rawTrace = StringBuffer()
      ..writeln(error.toString())
      ..writeln(stack?.toString() ?? '<no stack>');
    final crumbs = _breadcrumbDump?.call();
    if (crumbs != null && crumbs.isNotEmpty) {
      rawTrace
        ..writeln()
        ..writeln('=== Breadcrumbs (most recent last) ===')
        ..writeln(crumbs);
    }
    // Scrub trace + breadcrumbs together: the crash path has no
    // pseudonymization step, so any breadcrumb ref id is redacted to
    // `[redacted:N]` by LogScrubber (acceptable — crash context doesn't need
    // peer correlation).
    final scrubbed = LogScrubber.scrub(rawTrace.toString());

    final report = CrashReport(
      recordedAt: _now(),
      scrubbedTrace: scrubbed,
      appVersion: context.appVersion,
      osVersion: context.osVersion,
      device: context.device,
      dartVersion: context.dartVersion,
    );

    final json = utf8.encode(jsonEncode(report.toJson()));
    final ciphertext = await cipher.encrypt(json);

    await crashesDir.create(recursive: true);
    // Write to a temp file then rename — atomic on POSIX, avoids the
    // half-written sentinel that would surface on next launch as "corrupt".
    final temp = File('${sentinel.path}.tmp');
    await temp.writeAsBytes(ciphertext, flush: true);
    await temp.rename(sentinel.path);
  }

  File _sentinelFile() => File('${crashesDir.path}/$sentinelFileName');
}
