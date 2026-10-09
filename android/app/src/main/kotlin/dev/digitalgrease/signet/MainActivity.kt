package dev.digitalgrease.signet

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.SharedPreferences
import android.os.PersistableBundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter engine and exposes two platform method channels:
 *
 * - `dev.digitalgrease.signet/window` lets sensitive screens toggle
 *   FLAG_SECURE, which blocks screenshots, screen recording, and the
 *   recent-apps thumbnail. Called from the Dart `SecureScreen` wrapper on
 *   mount/dismount.
 * - `dev.digitalgrease.signet/clipboard` copies secret-bearing text marked
 *   sensitive and later clears it if it is still ours. Called from the Dart
 *   `SecureClipboard`.
 */
class MainActivity : FlutterActivity() {
    private val windowChannel = "dev.digitalgrease.signet/window"
    private val clipboardChannel = "dev.digitalgrease.signet/clipboard"

    companion object {
        /**
         * Which clip is ours: its timestamp (as Android reports it in the
         * clip description) and when it may be cleared. Kept in app
         * preferences, not memory, so a clear still happens after the
         * process was killed while the user was in another app. Holds no
         * clipboard content.
         */
        private const val PREFS = "signet_clipboard"
        private const val KEY_TIMESTAMP = "our_clip_timestamp"
        private const val KEY_CLEAR_AT = "clear_at"

        /**
         * ClipDescription.EXTRA_IS_SENSITIVE (API 33). The same key is
         * honoured by keyboards and the system clipboard UI on older
         * versions, so it is set as a literal on every version.
         */
        private const val EXTRA_IS_SENSITIVE = "android.content.extra.IS_SENSITIVE"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, windowChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "secureOn" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "secureOff" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, clipboardChannel)
            .setMethodCallHandler { call, result ->
                val clipboard = getSystemService(ClipboardManager::class.java)
                when (call.method) {
                    "copySensitive" -> {
                        val text = call.argument<String>("text")
                        if (text == null) {
                            result.error("bad_args", "text is required", null)
                            return@setMethodCallHandler
                        }
                        val clip = ClipData.newPlainText("Signet", text)
                        clip.description.extras = PersistableBundle().apply {
                            putBoolean(EXTRA_IS_SENSITIVE, true)
                        }
                        clipboard.setPrimaryClip(clip)
                        // Read back only the description (never the content)
                        // to remember which clip is ours.
                        val timestamp = clipboard.primaryClipDescription?.timestamp
                        if (timestamp == null) {
                            forgetOurClip()
                            result.success("untracked")
                            return@setMethodCallHandler
                        }
                        val expiresInMs = call.argument<Int>("expiresInMs") ?: 60_000
                        prefs().edit()
                            .putLong(KEY_TIMESTAMP, timestamp)
                            .putLong(KEY_CLEAR_AT, System.currentTimeMillis() + expiresInMs)
                            .apply()
                        result.success("tracked")
                    }
                    "clearIfOurs" -> result.success(clearIfOurs(clipboard))
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Clears the clipboard if it still holds the clip we set and that clip
     * is due. Never reads the clip's content. Returns "cleared", "notOurs"
     * (nothing of ours pending, or the clipboard was replaced or emptied),
     * "notYet" (ours, but younger than its expiry), or "unknown" (Android
     * hides the clipboard while the app does not have focus; the caller
     * retries on resume).
     */
    private fun clearIfOurs(clipboard: ClipboardManager): String {
        val prefs = prefs()
        if (!prefs.contains(KEY_TIMESTAMP)) return "notOurs"
        val ours = prefs.getLong(KEY_TIMESTAMP, 0)
        if (System.currentTimeMillis() < prefs.getLong(KEY_CLEAR_AT, 0)) return "notYet"
        if (!hasWindowFocus()) return "unknown"
        val description = clipboard.primaryClipDescription
        if (description == null || description.timestamp != ours) {
            forgetOurClip()
            return "notOurs"
        }
        clipboard.clearPrimaryClip()
        forgetOurClip()
        return "cleared"
    }

    private fun prefs(): SharedPreferences =
        applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun forgetOurClip() {
        prefs().edit().remove(KEY_TIMESTAMP).remove(KEY_CLEAR_AT).apply()
    }
}
