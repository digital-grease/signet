import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../shared/widgets/big_button.dart';
import 'pairing_codec.dart';
import 'pairing_controller.dart';

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

enum _ExchangeMode { overview, showing, scanning }

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

    return Scaffold(
      appBar: AppBar(
        title: Text('Pair with ${pair.label ?? 'contact'}'),
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
            ),
          _ExchangeMode.showing => _ShowingPane(
              state: pair,
              onDone: () {
                ref.read(pairingControllerProvider.notifier).markQrShown();
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
  });

  final PairingState state;
  final VoidCallback onShow;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Hold your phones together. '
            'Each of you needs to do both of these.',
            style: textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _StepCard(
            index: 1,
            title: 'Show my QR',
            subtitle: 'Let the other person scan your code.',
            done: state.didShowQr,
            onTap: state.ourKeyPair == null ? null : onShow,
          ),
          const SizedBox(height: 16),
          _StepCard(
            index: 2,
            title: 'Scan their QR',
            subtitle: 'Point your camera at their code.',
            done: state.hasScannedTheirKey,
            onTap: onScan,
          ),
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
                  ? 'Deriving shared secret…'
                  : 'Waiting for both steps…',
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: <Widget>[
          Text(
            'Let them scan this.',
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
            label: "They scanned — I'm done",
            icon: Icons.check,
            onPressed: onDone,
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onDone, child: const Text('Back')),
          const SizedBox(height: 8),
        ],
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
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _handled = false;
  String? _error;

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      try {
        final key = PairingCodec.decodePublicKey(raw);
        _handled = true;
        await _controller.stop();
        await widget.onDetected(key);
        return;
      } on FormatException catch (e) {
        if (!mounted) return;
        setState(() => _error = e.message);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: _controller,
      builder: (context, state, _) {
        final error = state.error;
        if (error?.errorCode == MobileScannerErrorCode.permissionDenied) {
          return _PermissionDeniedPane(onCancel: widget.onCancel);
        }
        return Stack(
          children: <Widget>[
            MobileScanner(
              controller: _controller,
              onDetect: (capture) => unawaited(_handleCapture(capture)),
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
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
            'Camera permission is turned off.',
            style: textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Signet needs the camera only to scan pairing QR codes. '
            'Turn it on in your phone settings: Apps → Signet → '
            'Permissions → Camera.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          BigButton(
            label: 'Back',
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

