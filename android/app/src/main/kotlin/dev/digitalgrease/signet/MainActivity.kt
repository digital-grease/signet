package dev.digitalgrease.signet

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter engine and exposes a platform method channel that
 * lets sensitive screens toggle FLAG_SECURE — blocks screenshots, screen
 * recording, and the recent-apps thumbnail. Called from the Dart
 * `SecureScreen` wrapper on mount/dismount.
 */
class MainActivity : FlutterActivity() {
    private val channel = "dev.digitalgrease.signet/window"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
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
    }
}
