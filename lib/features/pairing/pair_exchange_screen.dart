import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/big_button.dart';
import '../../shared/widgets/qr_scanner.dart';
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
              // Back is not "done": the other phone may not have scanned
              // yet (plan Task 3.5, P5).
              onBack: () => setState(() => _mode = _ExchangeMode.overview),
            ),
          _ExchangeMode.scanning => QrScannerView(
              onCancel: () => setState(() => _mode = _ExchangeMode.overview),
              // Pasting a key is a debug-build path only.
              onUsePaste: _debugPairing
                  ? () => setState(() => _mode = _ExchangeMode.pasting)
                  : null,
              onCode: (text) async {
                final Uint8List key;
                try {
                  key = PairingCodec.decodePublicKey(text);
                } on FormatException catch (e) {
                  return e.message;
                }
                final notifier = ref.read(pairingControllerProvider.notifier);
                await notifier.recordTheirPublicKey(key);
                if (mounted) setState(() => _mode = _ExchangeMode.overview);
                return null;
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

    // Scrolls when large text or a small screen makes the steps taller than
    // the viewport; otherwise fills it so the status line stays at the
    // bottom (the Spacer needs a bounded height, which IntrinsicHeight
    // provides inside the scroll view).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: _overviewColumn(context, textTheme, colors, l10n),
          ),
        ),
      ),
    );
  }

  Widget _overviewColumn(
    BuildContext context,
    TextTheme textTheme,
    ColorScheme colors,
    AppLocalizations l10n,
  ) {
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
                state.failure == PairingFailure.weakPublicKey
                    ? l10n.pairingWeakKeyInPersonError
                    : state.error!,
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
  const _ShowingPane({
    required this.state,
    required this.onDone,
    required this.onBack,
  });

  final PairingState state;
  final VoidCallback onDone;
  final VoidCallback onBack;

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
              onPressed: onBack,
              child: Text(l10n.commonBack),
            ),
            const SizedBox(height: 8),
          ],
        ),
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

