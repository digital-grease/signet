import 'dart:async';
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
    this._maxAge = const Duration(hours: 24),
    this._maxBytes = 2 * 1024 * 1024,
    this._ioTimeout = defaultIoTimeout,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  final CrashlogCipher cipher;

  /// Directory holding the encrypted session file. The 8.3 wiring sets this to
  /// `<getApplicationSupportDirectory()>/debug`.
  final Directory debugDir;

  final DateTime Function() _now;
  final Duration _maxAge;
  final int _maxBytes;
  final Duration _ioTimeout;

  static const String sessionFileName = 'session.bin';

  /// Upper bound for one encrypt (a Keystore/Keychain platform hop) and for
  /// [stop] waiting on in-flight writes, so a hung platform call can never
  /// block "Stop & wipe" or every later write.
  static const Duration defaultIoTimeout = Duration(seconds: 5);

  DateTime? _startedAt;
  final List<String> _lines = <String>[];

  /// Serializes every disk write. `DebugLog.log` calls [record] without
  /// awaiting, so persists used to overlap and race on one temp file; the
  /// losing rename threw into the zone handler and was recorded as a crash.
  Future<void> _writeQueue = Future<void>.value();

  /// Bumped by [start] and [stop]. A persist queued under an older
  /// generation is dropped, so an in-flight write can never resurrect a
  /// session the user just stopped.
  int _generation = 0;

  bool get isActive => _startedAt != null;
  DateTime? get startedAt => _startedAt;
  int get eventCount => _lines.length;

  /// When the active session will auto-expire, or null if inactive.
  DateTime? get expiresAt => _startedAt?.add(_maxAge);

  File _file() => File('${debugDir.path}/$sessionFileName');

  /// Begin a fresh session, replacing any existing one.
  Future<void> start() async {
    final generation = ++_generation;
    _startedAt = _now();
    _lines.clear();
    try {
      await _enqueuePersist();
    } on Object {
      // Roll back so the session is never active in memory while the
      // caller (and the Settings UI) believes enabling failed.
      if (_generation == generation) await stop();
      rethrow;
    }
  }

  /// Restore an in-flight session after an app relaunch. Returns true iff an
  /// unexpired session was loaded; expired or corrupt files are wiped.
  Future<bool> restore() async {
    // A kill mid-write can leave ciphertext in the temp file; never keep it.
    await _deleteQuietly(_tempFile());
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
  /// session is wiped as a side effect). Never throws: debug logging is a
  /// diagnostic aid and must not be able to crash the app or feed the crash
  /// recorder with its own I/O failures.
  Future<void> record(Breadcrumb crumb) async {
    try {
      final generation = _generation;
      if (!await _ensureActive()) return;
      // A stop (or stop + start) during the await above must not let this
      // crumb land in the stopped session's memory or in a new session.
      if (generation != _generation) return;
      _lines.add(crumb.format());
      _trimToCap();
      await _enqueuePersist();
    } on Object {
      // Swallowed by design; see doc comment.
    }
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
    final stopGeneration = ++_generation;
    _startedAt = null;
    _lines.clear();
    // Wipe immediately: the generation bump already stops any in-flight
    // write from renaming over the deleted file, so the user's "Stop &
    // wipe" never depends on the platform cipher finishing.
    await _wipeFiles();
    // Then let queued writes drain (bounded, in case the cipher hangs) and
    // wipe again for anything that slipped in, unless a new session was
    // started meanwhile (its own persist owns the file now).
    try {
      await _writeQueue.timeout(_ioTimeout);
    } on TimeoutException {
      // A hung write can no longer rename (generation check); move on.
    }
    if (_generation != stopGeneration) return;
    await _wipeFiles();
  }

  Future<void> _wipeFiles() async {
    await _deleteQuietly(_file());
    await _deleteQuietly(_tempFile());
  }

  static Future<void> _deleteQuietly(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      // Already gone or unreachable; nothing left to wipe.
    }
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

  File _tempFile() => File('${_file().path}.tmp');

  /// Queue a persist behind any in-flight one. The returned future completes
  /// with the persist's own outcome (so [start] can surface a failure); the
  /// queue itself never stays errored.
  Future<void> _enqueuePersist() {
    final generation = _generation;
    final result = _writeQueue.then((_) => _persist(generation));
    _writeQueue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _persist(int generation) async {
    // Snapshot state at execution time: a later record's lines are included,
    // and a stop/start since this write was queued cancels it.
    final started = _startedAt;
    if (generation != _generation || started == null) return;
    await debugDir.create(recursive: true);
    final payload = utf8.encode(jsonEncode(<String, dynamic>{
      'startedAt': started.toUtc().toIso8601String(),
      'lines': List<String>.of(_lines),
    }));
    final ciphertext = await cipher.encrypt(payload).timeout(_ioTimeout);
    // Temp-write then rename: atomic on POSIX, so no half-written session
    // file. Writes are serialized by [_writeQueue], so the temp path is never
    // shared between two in-flight persists.
    final temp = _tempFile();
    await temp.writeAsBytes(ciphertext, flush: true);
    // Defense in depth: a hung encrypt already times out before stop()'s
    // bounded wait ends, but a stalled disk write could still outlive it;
    // never rename a stopped session back into place.
    if (generation != _generation) {
      await temp.delete();
      return;
    }
    await temp.rename(_file().path);
  }
}
