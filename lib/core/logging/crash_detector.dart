import 'dart:convert';
import 'dart:io';

import 'crash_recorder.dart';
import 'crashlog_cipher.dart';

/// Next-launch probe for crash sentinel files written by [CrashRecorder].
///
/// Lifecycle (matches the spike's "On next launch" row):
///
///   1. [hasPendingReport] — called early in `main()`, before `runApp`.
///   2. If true, the root widget surfaces a `CrashReportDialog` once and
///      passes the [CrashReport] from [readPendingReport] into it.
///   3. User action (File issue / Copy log / Dismiss) → [dismissPendingReport]
///      deletes the sentinel so the dialog doesn't re-fire.
///
/// All three operations are file-system local, no network. Decryption uses
/// the same [CrashlogCipher] instance that the recorder used.
class CrashDetector {
  const CrashDetector({required this.cipher, required this.crashesDir});

  final CrashlogCipher cipher;
  final Directory crashesDir;

  /// Cheap existence check — used during `main()` before `runApp` to decide
  /// whether to wire the next-launch dialog into the root widget.
  Future<bool> hasPendingReport() async {
    final sentinel = _sentinelFile();
    if (!await sentinel.exists()) return false;
    // Sanity: zero-byte sentinel is corrupt; treat as no-report and clean up.
    try {
      final stat = await sentinel.stat();
      if (stat.size == 0) {
        await sentinel.delete();
        return false;
      }
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// Read and decrypt the pending sentinel. Returns `null` if there is no
  /// pending report or if decryption fails (corrupt sentinel, missing key,
  /// auth failure). A return of `null` means "no actionable report" — the
  /// caller should not surface a dialog.
  Future<CrashReport?> readPendingReport() async {
    final sentinel = _sentinelFile();
    if (!await sentinel.exists()) return null;
    try {
      final ciphertext = await sentinel.readAsBytes();
      final plaintext = await cipher.decrypt(ciphertext);
      final json = utf8.decode(plaintext);
      final map = jsonDecode(json) as Map<String, dynamic>;
      return CrashReport.fromJson(map);
    } on Object {
      // Any failure (decryption, JSON parse, key missing) → treat as no
      // report. Wipe the sentinel so subsequent launches don't retry forever.
      try {
        await sentinel.delete();
      } on FileSystemException {
        // Ignore — best-effort cleanup.
      }
      return null;
    }
  }

  /// Delete the sentinel. Called after the dialog has been actioned (File
  /// issue / Copy log / Dismiss) so the dialog doesn't re-fire on the next
  /// launch. Idempotent.
  Future<void> dismissPendingReport() async {
    final sentinel = _sentinelFile();
    if (!await sentinel.exists()) return;
    try {
      await sentinel.delete();
    } on FileSystemException {
      // Ignore — if the file's already gone or unwritable, nothing to do.
    }
  }

  File _sentinelFile() =>
      File('${crashesDir.path}/${CrashRecorder.sentinelFileName}');
}
