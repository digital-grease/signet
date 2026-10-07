import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Wraps [child] in a widget that asks the platform to block screenshots
/// and screen recording while the subtree is mounted.
///
/// Android: invokes `dev.digitalgrease.signet/window#secureOn` on mount
/// (adds `WindowManager.LayoutParams.FLAG_SECURE`), `secureOff` on dismount
/// (clears the flag). The platform implementation lives in
/// `android/app/src/main/kotlin/dev/digitalgrease/signet/MainActivity.kt`.
///
/// iOS: same method channel; native handler in
/// `ios/Runner/AppDelegate.swift` swaps the UI for a blurred overlay on
/// `applicationWillResignActive`, restores on `didBecomeActive`.
///
/// Web / desktop: no-op. The method channel returns `MissingPluginException`
/// and we swallow it silently.
///
/// Nested and stacked usage is reference-counted: every mount calls
/// `secureOn` (idempotent on the platform side, and a retry if an earlier
/// call failed), but `secureOff` is sent only when the last mounted
/// `SecureScreen` is disposed. Without the count, popping one secure route
/// back to another (for example bulk import back to the import screen
/// still showing PAKE words) cleared the flag while secrets were visible.
/// Route replacement is safe too: the new route's `initState` runs before
/// the old route's `dispose`, so the count never touches zero in between.
class SecureScreen extends StatefulWidget {
  const SecureScreen({super.key, required this.child});
  final Widget child;

  static const MethodChannel channel =
      MethodChannel('dev.digitalgrease.signet/window');

  // Process-wide. A hot restart resets it to 0 while the platform flag
  // stays on until the next secure screen closes; that fails safe and only
  // affects debug builds.
  static int _mountCount = 0;

  /// Number of currently mounted [SecureScreen]s.
  @visibleForTesting
  static int get debugMountCount => _mountCount;

  /// Resets the mount count between widget tests, which can leave states
  /// undisposed when a test fails mid-way.
  @visibleForTesting
  static void debugResetMountCount() => _mountCount = 0;

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  @override
  void initState() {
    super.initState();
    SecureScreen._mountCount++;
    _invoke('secureOn');
  }

  @override
  void dispose() {
    SecureScreen._mountCount--;
    if (SecureScreen._mountCount <= 0) {
      SecureScreen._mountCount = 0;
      _invoke('secureOff');
    }
    super.dispose();
  }

  Future<void> _invoke(String method) async {
    try {
      await SecureScreen.channel.invokeMethod<void>(method);
    } on PlatformException {
      // Platform implemented the channel but refused — swallow. The next
      // call will try again.
    } on MissingPluginException {
      // No implementation: test env, iOS, web, desktop. Intended no-op.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
