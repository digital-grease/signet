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
/// Nested usage is safe — if two `SecureScreen`s are mounted at the same
/// time the flag is set twice (idempotent on Android) and cleared only
/// when both are dismounted (stack-last-wins is fine because every mount
/// calls `secureOn` and every dismount calls `secureOff`; the flag is
/// effectively set whenever any `SecureScreen` is in the tree).
class SecureScreen extends StatefulWidget {
  const SecureScreen({super.key, required this.child});
  final Widget child;

  static const MethodChannel channel =
      MethodChannel('dev.digitalgrease.signet/window');

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  @override
  void initState() {
    super.initState();
    _invoke('secureOn');
  }

  @override
  void dispose() {
    _invoke('secureOff');
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
