import 'dart:convert';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/crypto/pair_role.dart';
import '../../core/crypto/pairing.dart';
import '../../core/crypto/transport_package.dart';
import '../../core/crypto/verification.dart';
import '../../core/models/relationship.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../core/models/label_policy.dart';
import '../../shared/label_input.dart';
import '../../shared/secure_clipboard.dart';
import '../../shared/package_error_text.dart';
import '../../shared/widgets/secure_screen.dart';

/// Sender side of Phase-10 long-distance pairing. Three linear phases:
///
/// 1. **Setup**: user names the contact, taps GENERATE. We mint an
///    ephemeral X25519 key pair + an 8-word PAKE secret.
/// 2. **Share + wait**: we display the outgoing LDP package (for the
///    channel-of-package) and the 8 PAKE words (for a *different*
///    trusted channel). The user transports both separately to the
///    peer. The peer runs the receiver flow and sends back a response
///    package. We paste it here and tap UNLOCK RESPONSE.
/// 3. **Confirm**: we derive the shared secret + pair-time phrase from
///    our private key and the peer's public key inside the response.
///    User confirms the phrase matches the peer's screen (via the same
///    trusted channel) and taps COMMIT PAIR.
class PairTransportOutScreen extends ConsumerStatefulWidget {
  const PairTransportOutScreen({super.key});

  @override
  ConsumerState<PairTransportOutScreen> createState() =>
      _PairTransportOutScreenState();
}

enum _Phase { setup, shareAndWait, confirm }

class _PairTransportOutScreenState
    extends ConsumerState<PairTransportOutScreen> {
  final TextEditingController _labelController = TextEditingController();
  // Optional: the sender's own name, sent as the hint the receiver's phone
  // suggests as the name for them (plan Task 3.6, P6).
  final TextEditingController _ownNameController = TextEditingController();
  String? _ownNameError;
  final TextEditingController _responseController = TextEditingController();

  _Phase _phase = _Phase.setup;
  String? _errorText;
  bool _busy = false;

  _GeneratedState? _generated;
  _ConfirmState? _confirming;

  @override
  void dispose() {
    _labelController.dispose();
    _ownNameController.dispose();
    _responseController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Phase 1: Generate
  // ------------------------------------------------------------------

  Future<void> _handleGenerate() async {
    if (_busy) return;
    final label = LabelPolicy.clean(_labelController.text);
    final l10n = AppLocalizations.of(context);
    final rejection = LabelPolicy.check(label);
    if (rejection != null) {
      setState(() => _errorText = rejection == LabelRejection.empty
          ? l10n.commonGiveContactName
          : labelRejectionText(rejection, l10n));
      return;
    }
    // Optional. Checked against the package limit here too: text still
    // being composed in an input method can get past the field's cap.
    final ownName = LabelPolicy.clean(_ownNameController.text);
    final ownNameRejection = ownName.isEmpty
        ? null
        : utf8.encode(ownName).length > TransportPackage.maxLabelHintBytes
            ? LabelRejection.tooLong
            : LabelPolicy.check(ownName);
    if (ownNameRejection != null) {
      setState(() =>
          _ownNameError = labelRejectionText(ownNameRejection, l10n));
      return;
    }
    setState(() {
      _busy = true;
      _errorText = null;
      _ownNameError = null;
    });
    try {
      final keyPair = await PairingHandshake.generateEphemeralKeyPair();
      final pakeWords = TransportPackage.mintPakeWords();
      final outgoing = await TransportPackage.encodeLdp(
        publicKey: keyPair.publicKey,
        labelHint: ownName,
        pakeWords: pakeWords,
      );
      if (!mounted) return;
      setState(() {
        _generated = _GeneratedState(
          label: label,
          ourKeyPair: keyPair,
          pakeWords: pakeWords,
          outgoingWire: outgoing,
        );
        _phase = _Phase.shareAndWait;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = AppLocalizations.of(context)
            .pairTransportOutGenerateError(e.toString());
        _busy = false;
      });
    }
  }

  // ------------------------------------------------------------------
  // Phase 2: Unlock receiver's response
  // ------------------------------------------------------------------

  Future<void> _handleUnlockResponse() async {
    final gen = _generated;
    if (gen == null || _busy) return;
    final wire = _responseController.text.trim();
    if (wire.isEmpty) {
      setState(() => _errorText =
          AppLocalizations.of(context).pairTransportOutPasteEmptyError);
      return;
    }
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      final ldp = await TransportPackage.decodeLdp(
        wire,
        pakeWords: gen.pakeWords,
      );
      // Our own outgoing package decodes with the same words; it is not a
      // response (plan Task 3.6, P8).
      if (listEquals(ldp.publicKey, gen.ourKeyPair.publicKey)) {
        if (!mounted) return;
        setState(() {
          _errorText =
              AppLocalizations.of(context).pairTransportOutOwnPackageError;
          _busy = false;
        });
        return;
      }
      final sharedSecret = await PairingHandshake.deriveSharedSecret(
        ours: gen.ourKeyPair,
        theirPublicKey: ldp.publicKey,
      );
      final totpSecret = await PairingHandshake.deriveTotpSecret(
        sharedSecret: sharedSecret,
      );
      final phrase = await PairingVerification.derivePhrase(
        sharedSecret: sharedSecret,
      );
      if (!mounted) return;
      setState(() {
        _confirming = _ConfirmState(
          peerPublicKey: ldp.publicKey,
          totpSecret: totpSecret,
          phrase: phrase,
        );
        _phase = _Phase.confirm;
        _busy = false;
      });
    } on InvalidPakeException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = AppLocalizations.of(context)
            .pairTransportOutUnlockFailedError(e.message);
        _busy = false;
      });
    } on WeakPublicKeyException {
      if (!mounted) return;
      setState(() {
        _errorText = AppLocalizations.of(context).pairingWeakKeyRemoteError;
        _busy = false;
      });
    } on InvalidPackageException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = packageErrorText(e, AppLocalizations.of(context));
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = AppLocalizations.of(context)
            .pairTransportOutUnlockFailedError(e.toString());
        _busy = false;
      });
    }
  }

  // ------------------------------------------------------------------
  // Phase 3: Commit
  // ------------------------------------------------------------------

  Future<void> _handleCommit() async {
    final gen = _generated;
    final conf = _confirming;
    if (gen == null || conf == null || _busy) return;
    setState(() => _busy = true);
    try {
      final role = PairRole.assign(
        ourPublicKey: gen.ourKeyPair.publicKey,
        theirPublicKey: conf.peerPublicKey,
      );
      final relationship = Relationship.fresh(label: gen.label, role: role);
      await ref.read(secureStoreProvider).saveRelationshipV2(
            relationship,
            sharedSecret: conf.totpSecret,
          );
      ref.invalidate(relationshipsProvider);
      if (!mounted) return;
      context.go('/pair/complete/${relationship.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText =
            AppLocalizations.of(context).commonSaveFailedError(e.toString());
        _busy = false;
      });
    }
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = switch (_phase) {
      _Phase.setup => l10n.pairTransportOutNewPackageTitle,
      _Phase.shareAndWait => l10n.pairTransportOutShareWaitTitle,
      _Phase.confirm => l10n.commonConfirmPairingTitle,
    };
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go('/'),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: switch (_phase) {
              _Phase.setup => _buildSetupPane(),
              _Phase.shareAndWait => _buildShareAndWaitPane(),
              _Phase.confirm => _buildConfirmPane(),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSetupPane() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeader(l10n.commonNameThisContactHeader),
        const SizedBox(height: 6),
        Text(
          l10n.pairTransportOutNameDescription,
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _labelController,
          autofocus: true,
          inputFormatters: <TextInputFormatter>[
            Utf8LengthLimitingTextInputFormatter(LabelPolicy.maxBytes),
          ],
          buildCounter:
              utf8ByteCounter(_labelController, LabelPolicy.maxBytes),
          decoration: InputDecoration(hintText: l10n.commonNameHintExample),
        ),
        const SizedBox(height: 12),
        _SectionHeader(l10n.pairTransportOutYourNameHeader),
        const SizedBox(height: 6),
        Text(
          l10n.pairTransportOutYourNameDescription,
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ownNameController,
          inputFormatters: <TextInputFormatter>[
            Utf8LengthLimitingTextInputFormatter(
                TransportPackage.maxLabelHintBytes),
          ],
          buildCounter: utf8ByteCounter(
              _ownNameController, TransportPackage.maxLabelHintBytes),
          decoration: InputDecoration(errorText: _ownNameError),
          onChanged: (_) {
            if (_ownNameError != null) setState(() => _ownNameError = null);
          },
        ),
        if (_errorText != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(_errorText!, style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _handleGenerate,
          child: Text(
            _busy ? l10n.commonGenerating : l10n.pairTransportOutGenerateButton,
          ),
        ),
      ],
    );
  }

  Widget _buildShareAndWaitPane() {
    final gen = _generated!;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeader(l10n.pairTransportOutOutgoingHeader),
        const SizedBox(height: 6),
        Text(
          l10n.pairTransportOutOutgoingInstruction(gen.label),
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          color: scheme.surfaceContainerHighest,
          child: SelectableText(
            gen.outgoingWire,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final result = await SecureClipboard.copy(gen.outgoingWire);
              messenger.showSnackBar(SnackBar(
                content: Text(switch (result) {
                  SecureCopyResult.protected => l10n.commonCopiedProtected,
                  SecureCopyResult.plain => l10n.commonCopiedPlain,
                  SecureCopyResult.failed => l10n.commonCopyFailed,
                }),
              ));
            },
            icon: const Icon(Icons.copy),
            label: Text(l10n.commonCopyPackage),
          ),
        ),
        const SizedBox(height: 20),
        _SectionHeader(l10n.commonPakeSecretHeader),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          color: scheme.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < gen.pakeWords.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${i + 1}.',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          gen.pakeWords[i],
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // No copy button for the words (bug R4): they go to the other person
        // on a different channel from the package, and a clipboard holding
        // the words is one paste away from landing next to it.
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            border: Border(left: BorderSide(color: scheme.secondary, width: 4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: scheme.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.pairTransportOutChannelWarning,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionHeader(l10n.pairTransportOutReceiveHeader),
        const SizedBox(height: 6),
        Text(
          l10n.pairTransportOutReceiveInstruction(gen.label),
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _responseController,
          minLines: 3,
          maxLines: 5,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: const InputDecoration(hintText: 'signet:tp1:...'),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text == null) return;
              setState(() => _responseController.text = data!.text!);
            },
            icon: const Icon(Icons.content_paste),
            label: Text(l10n.commonPasteFromClipboard),
          ),
        ),
        if (_errorText != null) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              border:
                  Border(left: BorderSide(color: scheme.error, width: 4)),
            ),
            child: Text(
              _errorText!,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _handleUnlockResponse,
          child: Text(
            _busy
                ? l10n.commonUnlocking
                : l10n.pairTransportOutUnlockResponseButton,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmPane() {
    final conf = _confirming!;
    final gen = _generated!;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeader(l10n.commonPairTimePhraseHeader),
        const SizedBox(height: 8),
        Text(
          l10n.pairTransportOutPhraseInstruction(gen.label),
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          color: scheme.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < conf.phrase.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${i + 1}.',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          conf.phrase[i],
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_errorText != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(_errorText!, style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _handleCommit,
          child: Text(_busy ? l10n.commonSaving : l10n.commonCommitPair),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy ? null : () => context.go('/'),
          child: Text(l10n.commonCancelCaps),
        ),
      ],
    );
  }
}

class _GeneratedState {
  _GeneratedState({
    required this.label,
    required this.ourKeyPair,
    required this.pakeWords,
    required this.outgoingWire,
  });

  final String label;
  final PairingKeyPair ourKeyPair;
  final List<String> pakeWords;
  final String outgoingWire;
}

class _ConfirmState {
  _ConfirmState({
    required this.peerPublicKey,
    required this.totpSecret,
    required this.phrase,
  });

  final List<int> peerPublicKey;
  final List<int> totpSecret;
  final List<String> phrase;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
