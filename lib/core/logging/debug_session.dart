import 'dart:convert';
import 'dart:io';

import 'breadcrumb.dart';
import 'crashlog_cipher.dart';

/// Opt-in debug-logging session (Phase 8). Off by default — a user who never
/// enables it leaves today's byte-for-byte on-disk footprint untouched.
///
/// While active, structured [Breadcrumb] events are appended to an encrypted
/// file at `<debugDir>/session.bin` so the log survives an app relaunch
/// mid-reproduction. Bounded by [maxAge] (auto-stops + wipes) and [maxBytes]
/// (oldest-first prune).
///
/// **At-rest model.** The session log is NOT run through `LogScrubber` at write
/// time — doing so would redact the 32-hex relationship ids that the export
/// scrubber needs to map to stable `<peer-N>` tokens. The at-rest defense is
/// (a) write-time discipline — only enumerated [BreadcrumbEvent]s and opaque
/// ids reach here, never a label or secret — and (b) AES-256-GCM encryption
/// under a key distinct from the crash sentinel's (`debuglog.aead_key.v1`).
/// The public-facing scrub (secrets → `[redacted]`, ids/labels → `<peer-N>`,
/// PII) runs at EXPORT time via `DebugLogExportScrubber`, not here.
///
/// This is a deviation from the spike's "write-time LogScrubber.scrub before
/// encryption" line, recorded in `.devloop/spikes/debug-log-export.md` /
/// `.devloop/plan.md` — it re-opened decision #3's framing during Phase-8.2.
class DebugSession {
  DebugSession({
    required this.cipher,
    required this.debugDir,
    DateTime Function()? now,
    Duration maxAge = const Duration(hours: 24),
    int maxBytes = 2 * 1024 * 1024,
  })  : _now = now ?? (() => DateTime.now().toUtc()),
        _maxAge = maxAge,
        _maxBytes = maxBytes;

  final CrashlogCipher cipher;

  /// Directory holding the encrypted session file. The 8.3 wiring sets this to
  /// `<getApplicationSupportDirectory()>/debug`.
  final Directory debugDir;

  final DateTime Function() _now;
  final Duration _maxAge;
  final int _maxBytes;

  static const String sessionFileName = 'session.bin';

  DateTime? _startedAt;
  final List<String> _lines = <String>[];

  bool get isActive => _startedAt != null;
  DateTime? get startedAt => _startedAt;
  int get eventCount => _lines.length;

  /// When the active session will auto-expire, or null if inactive.
  DateTime? get expiresAt => _startedAt?.add(_maxAge);

  File _file() => File('${debugDir.path}/$sessionFileName');

  /// Begin a fresh session, replacing any existing one.
  Future<void> start() async {
    _startedAt = _now();
    _lines.clear();
    await _persist();
  }

  /// Restore an in-flight session after an app relaunch. Returns true iff an
  /// unexpired session was loaded; expired or corrupt files are wiped.
  Future<bool> restore() async {
    final f = _file();
    if (!await f.exists()) return false;
    try {
      final plaintext = await cipher.decrypt(await f.readAsBytes());
      final map = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      final started = DateTime.parse(map['startedAt']! as String).toUtc();
      if (_now().difference(started) >= _maxAge) {
        await stop(); // expired
        return false;
      }
      _startedAt = started;
      _lines
        ..clear()
        ..addAll((map['lines']! as List<dynamic>).cast<String>());
      return true;
    } on Object {
      await stop(); // corrupt / undecryptable — wipe
      return false;
    }
  }

  /// Append one structured [crumb]. No-op when inactive or expired (an expired
  /// session is wiped as a side effect).
  Future<void> record(Breadcrumb crumb) async {
    if (!await _ensureActive()) return;
    _lines.add(crumb.format());
    _trimToCap();
    await _persist();
  }

  /// Decrypt + return the raw session log (structured, id-pseudonymous). The
  /// caller MUST run `DebugLogExportScrubber` over this with the relationship
  /// set before it leaves the device. Empty string when inactive/expired.
  Future<String> exportPlaintext() async {
    if (!await _ensureActive()) return '';
    return _composeLog();
  }

  /// End the session and delete the on-disk file.
  Future<void> stop() async {
    _startedAt = null;
    _lines.clear();
    final f = _file();
    if (await f.exists()) await f.delete();
  }

  // ===========================================================================
  // Internals
  // ===========================================================================

  /// True iff a session is active and within [maxAge]. An expired session is
  /// wiped here so callers don't have to special-case it.
  Future<bool> _ensureActive() async {
    final started = _startedAt;
    if (started == null) return false;
    if (_now().difference(started) >= _maxAge) {
      await stop();
      return false;
    }
    return true;
  }

  String _composeLog() => _lines.join('\n');

  void _trimToCap() {
    // Oldest-first prune until the composed log fits the byte cap. Keep at
    // least the most recent line even if a single line exceeds the cap.
    while (_lines.length > 1 &&
        utf8.encode(_composeLog()).length > _maxBytes) {
      _lines.removeAt(0);
    }
  }

  Future<void> _persist() async {
    await debugDir.create(recursive: true);
    final payload = utf8.encode(jsonEncode(<String, dynamic>{
      'startedAt': _startedAt!.toUtc().toIso8601String(),
      'lines': _lines,
    }));
    final ciphertext = await cipher.encrypt(payload);
    final f = _file();
    // Temp-write then rename — atomic on POSIX; no half-written session file.
    final temp = File('${f.path}.tmp');
    await temp.writeAsBytes(ciphertext, flush: true);
    await temp.rename(f.path);
  }
}
