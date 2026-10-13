import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// How a [SecureClipboard.copy] went, so the caller's message is honest.
enum SecureCopyResult {
  /// On the clipboard, and Signet will remove it (see [SecureClipboard]).
  protected,

  /// On the clipboard, but Signet cannot remove it later: no native
  /// support on this platform, or Android would not tell Signet which
  /// clip it was.
  plain,

  /// Not copied.
  failed,
}

/// Copies secret-bearing text (a backup or pairing package) to the
/// clipboard with as little exposure as the platform allows (bugs S6, R4):
///
/// - Android: the clip is marked sensitive, so most keyboards' clipboard
///   history and the system copy preview hide it. After [clearAfter] it is
///   removed, but only if it is still the newest clip, so something the
///   user copied since is left alone. Signet never reads the clipboard to
///   check (that would show Android's "pasted from your clipboard" toast);
///   the native side compares the clip's timestamp instead. Android only
///   reveals that while Signet has focus, so a clear that falls due while
///   the user is in another app runs when they come back, including after
///   the process was killed (the native side keeps its record of the clip
///   in app preferences, and [clearLeftovers] runs at app start).
/// - iOS: the copy stays on this device (no Universal Clipboard to a Mac or
///   iPad) and expires after [clearAfter].
/// - Elsewhere (tests, desktop): a plain copy.
///
/// Public keys and scrubbed logs are not secrets and keep using
/// [Clipboard.setData].
abstract final class SecureClipboard {
  static const MethodChannel _channel =
      MethodChannel('dev.digitalgrease.signet/clipboard');

  /// How long a copied secret stays on the clipboard.
  static const Duration clearAfter = Duration(seconds: 60);

  static Timer? _timer;
  static bool _clearDue = false;
  static AppLifecycleListener? _lifecycle;

  static Future<SecureCopyResult> copy(String text) async {
    // Drop any clear still pending for an earlier copy before this one is
    // made: run after it, that clear would remove the new clip.
    _timer?.cancel();
    _clearDue = false;
    final String? tracking;
    try {
      tracking = await _channel.invokeMethod<String>('copySensitive',
          <String, Object>{
            'text': text,
            'expiresInMs': clearAfter.inMilliseconds,
          });
    } on MissingPluginException {
      try {
        await Clipboard.setData(ClipboardData(text: text));
        return SecureCopyResult.plain;
      } catch (_) {
        return SecureCopyResult.failed;
      }
    } on PlatformException {
      return SecureCopyResult.failed;
    }
    // "untracked": copied (and marked sensitive) but Android did not
    // report the clip's timestamp, so it cannot be cleared safely.
    if (tracking == 'untracked') return SecureCopyResult.plain;
    _timer = Timer(clearAfter, () {
      _clearDue = true;
      unawaited(_tryClear());
    });
    _listenForResume();
    return SecureCopyResult.protected;
  }

  /// At app start: clear a secret left on the clipboard by a previous run
  /// that was killed before its clear ran. The native side only clears a
  /// clip that is still ours and at least [clearAfter] old.
  static Future<void> clearLeftovers() async {
    _clearDue = true;
    _listenForResume();
    await _tryClear();
    // Focus can arrive a moment after the first frame; one more try, and
    // after that the next resume.
    if (_clearDue) _timer = Timer(_leftoverRetry, () => unawaited(_tryClear()));
  }

  static const Duration _leftoverRetry = Duration(seconds: 3);

  static void _listenForResume() {
    _lifecycle ??= AppLifecycleListener(
      onResume: () => unawaited(_tryClear()),
    );
  }

  static Future<void> _tryClear() async {
    if (!_clearDue) return;
    String? outcome;
    try {
      outcome = await _channel.invokeMethod<String>('clearIfOurs');
    } catch (_) {
      // No native support, or it failed: nothing more to do here.
      outcome = 'notOurs';
    }
    // 'cleared': done. 'notOurs': nothing of ours is pending (the user
    // copied something else since, or the clipboard was emptied).
    // 'unknown': Signet does not have focus, where Android hides the
    // clipboard; 'notYet': a leftover younger than clearAfter. Both are
    // retried on resume.
    if (outcome == 'cleared' || outcome == 'notOurs') _clearDue = false;
  }

  @visibleForTesting
  static void resetForTesting() {
    _timer?.cancel();
    _timer = null;
    _clearDue = false;
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}
