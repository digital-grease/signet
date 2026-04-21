import Flutter
import UIKit

/// iOS counterpart to Android's FLAG_SECURE.
///
/// iOS does not expose a system-wide "block screen capture" flag, so
/// the standard mitigation is to overlay a blurred view on
/// `applicationWillResignActive` — that's the notification fired just
/// before iOS takes the app-switcher snapshot and also when screen
/// recording begins on most iOS versions. Removing the overlay on
/// `applicationDidBecomeActive` returns the UI cleanly.
///
/// The Dart-side `SecureScreen` widget (see
/// `lib/shared/widgets/secure_screen.dart`) calls into the
/// `dev.digitalgrease.signet/window` method channel with `secureOn`/`secureOff`.
/// On Android this wires to `WindowManager.FLAG_SECURE`
/// (MainActivity.kt); on iOS we arm the notification observers here
/// for the duration of the secure screen's lifetime.
///
/// This does NOT prevent:
/// - Physical photographs of the device screen by someone next to the user
/// - Specialized forensic tools run from a jailbroken device
/// - Mirroring via AirPlay / HDMI (iOS sends the blur to the app-switcher
///   snapshot path, not to active mirror sessions — that's an OS behavior
///   we can't override from a user-space app)
///
/// The blur is intentionally heavy (`.systemMaterialDark`) so the
/// content is unreadable, not just dimmed.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var secureChannel: FlutterMethodChannel?
  private var overlayView: UIVisualEffectView?
  private var isSecure = false
  private var willResignObserver: NSObjectProtocol?
  private var didBecomeActiveObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Flutter 3.41.x moved the binary messenger off the engine bridge and
    // onto the new `FlutterApplicationRegistrar`. Earlier iterations
    // exposed `engineBridge.binaryMessenger` directly; keeping that call
    // shape triggers a "has no member 'binaryMessenger'" compile error
    // against the current FlutterEngine.h protocol.
    registerSecureChannel(with: engineBridge.applicationRegistrar.messenger)
  }

  private func registerSecureChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "dev.digitalgrease.signet/window",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "secureOn":
        self.armSecureMode()
        result(nil)
      case "secureOff":
        self.disarmSecureMode()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.secureChannel = channel
  }

  private func armSecureMode() {
    guard !isSecure else { return }
    isSecure = true

    willResignObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.willResignActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.showOverlay()
    }

    didBecomeActiveObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.hideOverlay()
    }
  }

  private func disarmSecureMode() {
    guard isSecure else { return }
    isSecure = false

    if let observer = willResignObserver {
      NotificationCenter.default.removeObserver(observer)
      willResignObserver = nil
    }
    if let observer = didBecomeActiveObserver {
      NotificationCenter.default.removeObserver(observer)
      didBecomeActiveObserver = nil
    }
    hideOverlay()
  }

  private func showOverlay() {
    guard overlayView == nil else { return }
    guard let window = self.keyWindow() else { return }
    let effect = UIBlurEffect(style: .systemMaterialDark)
    let overlay = UIVisualEffectView(effect: effect)
    overlay.frame = window.bounds
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(overlay)
    overlayView = overlay
  }

  private func hideOverlay() {
    overlayView?.removeFromSuperview()
    overlayView = nil
  }

  private func keyWindow() -> UIWindow? {
    // `UIApplication.shared.keyWindow` is deprecated on iOS 13+; the
    // supported path is to walk connected scenes and pick the active
    // foreground window.
    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else { continue }
      if let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
        return window
      }
    }
    return UIApplication.shared.windows.first
  }
}
