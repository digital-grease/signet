import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart' show CameraController, CameraException;
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import '../../l10n/app_localizations.dart';
import 'big_button.dart';
import 'secure_screen.dart';

/// Builds the camera reader. Production uses flutter_zxing's
/// [ReaderWidget]; widget tests pass a fake, since there is no camera.
typedef QrReaderBuilder = Widget Function({
  required void Function(String text) onText,
  required void Function(CameraController? controller, Exception? error)
      onControllerCreated,
});

Widget _zxingReader({
  required void Function(String text) onText,
  required void Function(CameraController? controller, Exception? error)
      onControllerCreated,
}) =>
    ReaderWidget(
      codeFormat: Format.qrCode,
      tryRotate: true,
      showScannerOverlay: false,
      showFlashlight: false,
      showToggleCamera: false,
      showGallery: false,
      lensDirection: CameraLensDirection.back,
      onScan: (code) {
        final text = code.text;
        if (text != null && text.isNotEmpty) onText(text);
      },
      onControllerCreated: onControllerCreated,
    );

/// Replaces the camera reader in every [QrScannerView], for widget tests
/// (there is no camera). Reset to null in tearDown.
@visibleForTesting
QrReaderBuilder? qrReaderOverride;

/// Full-area QR scanner shared by in-person pairing and backup restore
/// (plan Task 3.9).
///
/// [onCode] gets each decoded text. It returns null once the code is
/// accepted (scanning stops), or a message to show while scanning goes on.
///
/// The camera can fail in ways flutter_zxing reports with codes we do not
/// know, or never come up at all; either way the user gets a pane with
/// "Try again", "Paste instead" (when [onUsePaste] is set) and Back,
/// instead of an endless spinner. A refused camera permission keeps its
/// own pane, which explains where to allow it.
class QrScannerView extends StatefulWidget {
  const QrScannerView({
    super.key,
    required this.onCode,
    required this.onCancel,
    this.onUsePaste,
    this.startTimeout = const Duration(seconds: 12),
  });

  final Future<String?> Function(String text) onCode;
  final VoidCallback onCancel;
  final VoidCallback? onUsePaste;

  /// How long the camera may take to start before the error pane shows.
  final Duration startTimeout;

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

enum _ScannerState { starting, scanning, permissionDenied, failed }

class _QrScannerViewState extends State<QrScannerView>
    with WidgetsBindingObserver {
  _ScannerState _state = _ScannerState.starting;
  bool _handled = false;
  bool _busy = false;
  String? _message;
  Timer? _startWatchdog;

  /// Bumped by "Try again" so the reader (and its camera) is rebuilt.
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _armWatchdog();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _startWatchdog?.cancel();
    super.dispose();
  }

  /// The first camera use shows the OS permission prompt, which takes the
  /// app out of the foreground. However long someone takes to read it, the
  /// countdown waits, and starts over once they are back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_state != _ScannerState.starting) return;
    if (state == AppLifecycleState.resumed) {
      _armWatchdog();
    } else {
      _startWatchdog?.cancel();
    }
  }

  void _armWatchdog() {
    _startWatchdog?.cancel();
    _startWatchdog = Timer(widget.startTimeout, () {
      if (mounted && _state == _ScannerState.starting) {
        setState(() => _state = _ScannerState.failed);
      }
    });
  }

  void _retry() {
    setState(() {
      _attempt++;
      _state = _ScannerState.starting;
      _message = null;
    });
    _armWatchdog();
  }

  // CameraException codes for permission denial vary slightly between
  // platforms; both Android and iOS surface 'CameraAccessDenied' from
  // package:camera when the user has refused the runtime prompt or
  // toggled it off in OS settings.
  static const Set<String> _permissionCodes = <String>{
    'CameraAccessDenied',
    'CameraAccessDeniedWithoutPrompt',
    'CameraAccessRestricted',
  };

  void _onControllerCreated(
    int attempt,
    CameraController? controller,
    Exception? error,
  ) {
    // A late report from a reader replaced by "Try again" is stale.
    if (!mounted || attempt != _attempt) return;
    _startWatchdog?.cancel();
    setState(() {
      if (error == null) {
        _state = _ScannerState.scanning;
      } else if (error is CameraException &&
          _permissionCodes.contains(error.code)) {
        _state = _ScannerState.permissionDenied;
      } else {
        // Any other failure, including codes this version does not know.
        _state = _ScannerState.failed;
      }
    });
  }

  Future<void> _onText(String text) async {
    if (_handled || _busy) return;
    _busy = true;
    try {
      final message = await widget.onCode(text);
      if (!mounted) return;
      if (message == null) {
        _handled = true;
      } else {
        setState(() => _message = message);
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final attemptNow = _attempt;
    switch (_state) {
      case _ScannerState.permissionDenied:
        return _PermissionDeniedPane(onCancel: widget.onCancel);
      case _ScannerState.failed:
        return _CameraFailedPane(
          onRetry: _retry,
          onUsePaste: widget.onUsePaste,
          onCancel: widget.onCancel,
        );
      case _ScannerState.starting:
      case _ScannerState.scanning:
        break;
    }
    return Stack(
      children: <Widget>[
        KeyedSubtree(
          key: ValueKey<int>(_attempt),
          child: (qrReaderOverride ?? _zxingReader)(
            onText: (text) => unawaited(_onText(text)),
            onControllerCreated: (controller, error) =>
                _onControllerCreated(attemptNow, controller, error),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _ViewfinderPainter()),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 32,
          child: Column(
            children: <Widget>[
              if (_message != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              FilledButton.tonal(
                onPressed: widget.onCancel,
                child: Text(AppLocalizations.of(context).commonCancel),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Opens a full-screen scanner and returns the first code [accept] takes
/// (it returns null to accept, or a message to keep scanning), or null if
/// the user backs out. Blocks screenshots: what it scans can be secret.
Future<String?> scanQrCode(
  BuildContext context, {
  required String? Function(String text) accept,
}) {
  // Pop exactly once. A second pop during the exit animation (Cancel
  // tapped as a code is accepted, or a code decoded as Cancel is tapped)
  // would close the screen underneath as well.
  var popped = false;
  void pop(BuildContext pageContext, [String? value]) {
    if (popped) return;
    popped = true;
    Navigator.of(pageContext).pop(value);
  }

  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      fullscreenDialog: true,
      builder: (pageContext) => SecureScreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(pageContext).scannerTitle),
          ),
          body: SafeArea(
            child: QrScannerView(
              onCode: (text) async {
                if (popped) return null;
                final message = accept(text);
                if (message == null) pop(pageContext, text);
                return message;
              },
              onCancel: () => pop(pageContext),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CameraFailedPane extends StatelessWidget {
  const _CameraFailedPane({
    required this.onRetry,
    required this.onCancel,
    this.onUsePaste,
  });

  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final VoidCallback? onUsePaste;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Icon(Icons.videocam_off_outlined, size: 64, color: colors.error),
            const SizedBox(height: 16),
            Text(
              l10n.scannerCameraErrorTitle,
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              onUsePaste == null
                  ? l10n.scannerCameraErrorBody
                  : l10n.scannerCameraErrorBodyPaste,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            BigButton(
              label: l10n.scannerRetry,
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
            if (onUsePaste != null) ...<Widget>[
              const SizedBox(height: 12),
              BigButton(
                label: l10n.scannerUsePaste,
                icon: Icons.content_paste,
                onPressed: onUsePaste,
              ),
            ],
            const SizedBox(height: 12),
            TextButton(onPressed: onCancel, child: Text(l10n.commonBack)),
          ],
        ),
      ),
    );
  }
}

class _PermissionDeniedPane extends StatelessWidget {
  const _PermissionDeniedPane({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    // The OS-native path to the per-app camera permission toggle.
    // Android wraps it under Apps → the-app → Permissions; iOS exposes
    // each app at the top level of Settings.
    final settingsPath = Platform.isIOS
        ? l10n.pairCameraSettingsPathIos
        : l10n.pairCameraSettingsPathAndroid;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.no_photography_outlined,
            size: 64,
            color: colors.error,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.pairExchangeCameraPermissionTitle,
            style: textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.pairExchangeCameraPermissionBody(settingsPath),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          BigButton(
            label: l10n.commonBack,
            icon: Icons.arrow_back,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.shortestSide * 0.7,
      height: size.shortestSide * 0.7,
    );
    final border = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
