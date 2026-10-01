import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart' show CameraException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/big_button.dart';
import '../../shared/widgets/secure_screen.dart';
import 'pairing_codec.dart';
import 'pairing_controller.dart';

/// Compile-time flag that exposes a "paste pairing string" developer pane
/// alongside the camera flow. Enable with:
///   flutter run --dart-define=SIGNET_DEBUG_PAIRING=true
/// Intended for two-emulator testing where pointing a physical camera at
/// another phone is impossible. Never ship a release build with this flag on.
const bool _debugPairing =
    bool.fromEnvironment('SIGNET_DEBUG_PAIRING');

/// Step 2 of the pair flow: symmetric QR exchange. Each device needs to
/// both display its public key and scan the other's. Either step can be
/// done first — tapping "Show my QR" opens a fullscreen display, tapping
/// "Scan their QR" opens the camera. When both are complete we auto-advance
/// to the confirmation screen.
class PairExchangeScreen extends ConsumerStatefulWidget {
  const PairExchangeScreen({super.key});

  @override
  ConsumerState<PairExchangeScreen> createState() =>
      _PairExchangeScreenState();
}

enum _ExchangeMode { overview, showing, scanning, pasting }

class _PairExchangeScreenState extends ConsumerState<PairExchangeScreen> {
  _ExchangeMode _mode = _ExchangeMode.overview;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Generate our ephemeral key pair once; keeps the shown QR stable
    // across rebuilds.
    Future<void>.microtask(
      () => ref.read(pairingControllerProvider.notifier).ensureOurKeyPair(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pair = ref.watch(pairingControllerProvider);

    // Auto-advance once the full exchange has produced a verification phrase.
    ref.listen(pairingControllerProvider, (previous, next) {
      if (!_navigated && next.confirmationReady) {
        _navigated = true;
        context.go('/pair/confirm');
      }
    });

    final l10n = AppLocalizations.of(context);
    final contact = pair.label ?? l10n.pairExchangeFallbackContact;
    return Scaffold(
      appBar: AppBar(
        title: Text(pair.isRekey
            ? l10n.pairExchangeTitleRekey(contact)
            : l10n.pairExchangeTitlePair(contact)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (_mode != _ExchangeMode.overview) {
              setState(() => _mode = _ExchangeMode.overview);
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: SafeArea(
        child: switch (_mode) {
          _ExchangeMode.overview => _OverviewPane(
              state: pair,
              onShow: () => setState(() => _mode = _ExchangeMode.showing),
              onScan: () => setState(() => _mode = _ExchangeMode.scanning),
              onPaste: _debugPairing
                  ? () => setState(() => _mode = _ExchangeMode.pasting)
                  : null,
            ),
          _ExchangeMode.showing => _ShowingPane(
              state: pair,
              onDone: () async {
                await ref
                    .read(pairingControllerProvider.notifier)
                    .markQrShown();
                if (!mounted) return;
                setState(() => _mode = _ExchangeMode.overview);
              },
            ),
          _ExchangeMode.scanning => _ScanningPane(
              onCancel: () => setState(() => _mode = _ExchangeMode.overview),
              onDetected: (payload) async {
                final notifier = ref.read(pairingControllerProvider.notifier);
                await notifier.recordTheirPublicKey(payload);
                if (!mounted) return;
                setState(() => _mode = _ExchangeMode.overview);
              },
            ),
          _ExchangeMode.pasting => _PastingPane(
              state: pair,
              onCancel: () => setState(() => _mode = _ExchangeMode.overview),
              onSubmit: (payload) async {
                final notifier = ref.read(pairingControllerProvider.notifier);
                final key = PairingCodec.decodePublicKey(payload);
                await notifier.recordTheirPublicKey(key);
                await notifier.markQrShown();
                if (!mounted) return;
                setState(() => _mode = _ExchangeMode.overview);
              },
            ),
        },
      ),
    );
  }
}

class _OverviewPane extends StatelessWidget {
  const _OverviewPane({
    required this.state,
    required this.onShow,
    required this.onScan,
    this.onPaste,
  });

  final PairingState state;
  final VoidCallback onShow;
  final VoidCallback onScan;
  final VoidCallback? onPaste;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.pairExchangeIntro,
            style: textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _StepCard(
            index: 1,
            title: l10n.pairExchangeStep1Title,
            subtitle: l10n.pairExchangeStep1Subtitle,
            done: state.didShowQr,
            onTap: state.ourKeyPair == null ? null : onShow,
          ),
          const SizedBox(height: 16),
          _StepCard(
            index: 2,
            title: l10n.pairExchangeStep2Title,
            subtitle: l10n.pairExchangeStep2Subtitle,
            done: state.hasScannedTheirKey,
            onTap: onScan,
          ),
          if (onPaste != null) ...<Widget>[
            const SizedBox(height: 16),
            _StepCard(
              index: 3,
              title: l10n.pairExchangeStep3Title,
              subtitle: l10n.pairExchangeStep3Subtitle,
              done: state.exchangeComplete,
              onTap: state.ourKeyPair == null ? null : onPaste,
            ),
          ],
          const Spacer(),
          if (state.error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                state.error!,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onErrorContainer,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              state.exchangeComplete
                  ? l10n.pairExchangeDerivingStatus
                  : l10n.pairExchangeWaitingStatus,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onTap,
  });

  final int index;
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: done ? colors.primaryContainer : colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: done ? colors.primary : colors.secondary,
                foregroundColor:
                    done ? colors.onPrimary : colors.onSecondary,
                child: done
                    ? const Icon(Icons.check)
                    : Text('$index', style: textTheme.titleMedium),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                done ? Icons.check_circle : Icons.chevron_right,
                color: done ? colors.primary : colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShowingPane extends StatelessWidget {
  const _ShowingPane({required this.state, required this.onDone});

  final PairingState state;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final ours = state.ourKeyPair;
    if (ours == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final payload = PairingCodec.encodePublicKey(ours.publicKey);
    final l10n = AppLocalizations.of(context);

    // FLAG_SECURE while the pair-time QR is on screen. The pubkey itself is
    // not secret, but blocking screen recording here is cheap defense-in-
    // depth: a recorded pair flow lets an attacker replay the whole
    // handshake attempt off-device.
    return SecureScreen(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: <Widget>[
            Text(
              l10n.pairExchangeShowHeading,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: payload,
                      version: QrVersions.auto,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(8),
                      gapless: true,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            BigButton(
              label: l10n.pairExchangeShowDoneButton,
              icon: Icons.check,
              onPressed: onDone,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onDone,
              child: Text(l10n.commonBack),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ScanningPane extends StatefulWidget {
  const _ScanningPane({required this.onCancel, required this.onDetected});

  final VoidCallback onCancel;
  final Future<void> Function(Uint8List publicKey) onDetected;

  @override
  State<_ScanningPane> createState() => _ScanningPaneState();
}

class _ScanningPaneState extends State<_ScanningPane> {
  bool _handled = false;
  bool _permissionDenied = false;
  String? _error;

  Future<void> _handleScan(Code code) async {
    if (_handled) return;
    final raw = code.text;
    if (raw == null || raw.isEmpty) return;
    try {
      final key = PairingCodec.decodePublicKey(raw);
      _handled = true;
      await widget.onDetected(key);
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  // CameraException codes for permission denial vary slightly between
  // platforms; both Android and iOS surface 'CameraAccessDenied' from
  // package:camera when the user has refused the runtime prompt or
  // toggled it off in OS settings.
  void _handleControllerCreated(
    CameraController? controller,
    Exception? error,
  ) {
    if (error is CameraException &&
        (error.code == 'CameraAccessDenied' ||
            error.code == 'CameraAccessDeniedWithoutPrompt' ||
            error.code == 'CameraAccessRestricted')) {
      if (!mounted) return;
      setState(() => _permissionDenied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return _PermissionDeniedPane(onCancel: widget.onCancel);
    }
    return Stack(
      children: <Widget>[
        ReaderWidget(
          codeFormat: Format.qrCode,
          tryRotate: true,
          showScannerOverlay: false,
          showFlashlight: false,
          showToggleCamera: false,
          showGallery: false,
          lensDirection: CameraLensDirection.back,
          onScan: (code) => unawaited(_handleScan(code)),
          onControllerCreated: _handleControllerCreated,
        ),
        Positioned.fill(
          child: CustomPaint(painter: _ViewfinderPainter()),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 32,
          child: Column(
            children: <Widget>[
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
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

class _PastingPane extends StatefulWidget {
  const _PastingPane({
    required this.state,
    required this.onCancel,
    required this.onSubmit,
  });

  final PairingState state;
  final VoidCallback onCancel;
  final Future<void> Function(String payload) onSubmit;

  @override
  State<_PastingPane> createState() => _PastingPaneState();
}

class _PastingPaneState extends State<_PastingPane> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_busy) return;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() =>
          _error = AppLocalizations.of(context).pairExchangePasteEmptyError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(text);
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ours = widget.state.ourKeyPair;
    if (ours == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final ourPayload = PairingCodec.encodePublicKey(ours.publicKey);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.pairExchangeDevHeading,
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.pairExchangeDevInstructions,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.pairExchangeDevYourString, style: textTheme.labelLarge),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              ourPayload,
              style: textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final copied = l10n.pairExchangeDevCopiedSnackbar;
                await Clipboard.setData(ClipboardData(text: ourPayload));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(copied),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: Text(l10n.pairExchangeDevCopyButton),
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.pairExchangeDevTheirString, style: textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _controller,
            enabled: !_busy,
            maxLines: 3,
            minLines: 2,
            style: textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'signet:p1:...',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 20),
          BigButton(
            label: _busy
                ? l10n.pairExchangeDevSubmittingButton
                : l10n.pairExchangeDevSubmitButton,
            icon: Icons.check,
            onPressed: _busy ? null : _handleSubmit,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : widget.onCancel,
            child: Text(l10n.commonBack),
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

