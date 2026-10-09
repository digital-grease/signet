import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/crypto/pair_role.dart';
import '../../core/crypto/pairing.dart';
import '../../core/crypto/transport_package.dart';
import '../../core/crypto/verification.dart';
import '../../core/logging/breadcrumb.dart';
import '../../core/models/label_policy.dart';
import '../../core/models/relationship.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/secure_clipboard.dart';
import '../../shared/package_error_text.dart';
import '../../shared/widgets/secure_screen.dart';
import '../verify/word_input.dart';

/// Receiver side of the Phase-10 long-distance pairing flow. Two phases:
///
/// 1. **Unlock**: user pastes the sender's LDP transport package and
///    enters the 8-word PAKE secret received over a trusted channel.
///    AES-GCM authentication either succeeds (proceed) or fails
///    (InvalidPakeException → inline error).
/// 2. **Confirm**: we derive the shared secret via ECDH against our fresh
///    ephemeral key pair, compute the pair-time 4-word phrase, and
///    display it alongside a response LDP package. The user confirms
///    the phrase matches on the sender's screen (via the same trusted
///    channel) AND sends the response package back. Tap COMMIT to write
///    the relationship.
///
/// Wrapped in [SecureScreen] throughout — the PAKE secret is visible to
/// screenshots if we weren't careful.
class PairTransportInScreen extends ConsumerStatefulWidget {
  const PairTransportInScreen({super.key});

  @override
  ConsumerState<PairTransportInScreen> createState() =>
      _PairTransportInScreenState();
}

class _PairTransportInScreenState
    extends ConsumerState<PairTransportInScreen> {
  final TextEditingController _packageController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();
  List<String> _pakeWords = const <String>[];
  int _pakeResetKey = 0;

  String? _unlockError;
  bool _unlocking = false;

  _UnlockedState? _unlocked;
  bool _committing = false;

  @override
  void dispose() {
    _packageController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Unlock phase
  // ------------------------------------------------------------------

  Future<void> _handleUnlock() async {
    if (_unlocking) return;
    final wire = _packageController.text.trim();
    if (wire.isEmpty) {
      setState(() =>
          _unlockError =
              AppLocalizations.of(context).pairTransportInPasteEmptyError);
      return;
    }
    if (_pakeWords.length != 8) {
      setState(() =>
          _unlockError =
              AppLocalizations.of(context).pairTransportInWordsIncompleteError);
      return;
    }
    setState(() {
      _unlocking = true;
      _unlockError = null;
    });
    try {
      final ldp = await TransportPackage.decodeLdp(
        wire,
        pakeWords: _pakeWords,
      );
      final ourKeyPair = await PairingHandshake.generateEphemeralKeyPair();
      final sharedSecret = await PairingHandshake.deriveSharedSecret(
        ours: ourKeyPair,
        theirPublicKey: ldp.publicKey,
      );
      final totpSecret =
          await PairingHandshake.deriveTotpSecret(sharedSecret: sharedSecret);
      final phrase = await PairingVerification.derivePhrase(
        sharedSecret: sharedSecret,
      );
      final responseWire = await TransportPackage.encodeLdp(
        publicKey: ourKeyPair.publicKey,
        labelHint: '', // receiver hint is not useful to the sender
        pakeWords: _pakeWords,
        // Answer in the request's wire version so a sender on an older
        // build (which reads only version 1) can still open the response.
        version: ldp.version,
      );
      if (!mounted) return;
      setState(() {
        _unlocked = _UnlockedState(
          senderPublicKey: ldp.publicKey,
          ourKeyPair: ourKeyPair,
          totpSecret: totpSecret,
          phrase: phrase,
          responseWire: responseWire,
        );
        _labelController.text = ldp.labelHint;
        _unlocking = false;
      });
    } on InvalidPakeException catch (e) {
      if (!mounted) return;
      setState(() {
        _unlockError = AppLocalizations.of(context)
            .commonUnlockFailedError(e.message);
        _unlocking = false;
        _pakeResetKey++;
      });
    } on WeakPublicKeyException {
      if (!mounted) return;
      setState(() {
        _unlockError = AppLocalizations.of(context).pairingWeakKeyRemoteError;
        _unlocking = false;
      });
    } on InvalidPackageException catch (e) {
      if (!mounted) return;
      setState(() {
        _unlockError = packageErrorText(e, AppLocalizations.of(context));
        _unlocking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _unlockError = AppLocalizations.of(context)
            .pairTransportInProcessFailedError(e.toString());
        _unlocking = false;
      });
    }
  }

  // ------------------------------------------------------------------
  // Commit phase
  // ------------------------------------------------------------------

  Future<void> _handleCommit() async {
    final unlocked = _unlocked;
    if (unlocked == null || _committing) return;
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      setState(() =>
          _unlockError = AppLocalizations.of(context).commonGiveContactName);
      return;
    }
    final labelReason = LabelPolicy.rejectionReason(label);
    if (labelReason != null) {
      setState(() => _unlockError = labelReason);
      return;
    }
    setState(() => _committing = true);
    try {
      final role = PairRole.assign(
        ourPublicKey: unlocked.ourKeyPair.publicKey,
        theirPublicKey: unlocked.senderPublicKey,
      );
      final relationship = Relationship.fresh(label: label, role: role);
      await ref.read(secureStoreProvider).saveRelationshipV2(
            relationship,
            sharedSecret: unlocked.totpSecret,
          );
      ref
          .read(debugLogProvider)
          .log(BreadcrumbEvent.pairingCommit, relationship: relationship);
      ref.invalidate(relationshipsProvider);
      if (!mounted) return;
      context.go('/pair/complete/${relationship.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _unlockError =
            AppLocalizations.of(context).commonSaveFailedError(e.toString());
        _committing = false;
      });
    }
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_unlocked == null
              ? l10n.pairTransportInImportTitle
              : l10n.commonConfirmPairingTitle),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go('/'),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child:
                _unlocked == null ? _buildUnlockPane() : _buildConfirmPane(),
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockPane() {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeader(l10n.pairTransportInIncomingHeader),
        const SizedBox(height: 8),
        Text(
          l10n.pairTransportInPasteInstruction,
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _packageController,
          minLines: 3,
          maxLines: 5,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'signet:tp1:...',
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text == null) return;
              setState(() => _packageController.text = data!.text!);
            },
            icon: const Icon(Icons.content_paste),
            label: Text(l10n.commonPasteFromClipboard),
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader(l10n.commonPakeSecretHeader),
        const SizedBox(height: 6),
        Text(
          l10n.pairTransportInPakeDescription,
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        WordInput(
          wordCount: 8,
          autofocus: false,
          resetKey: _pakeResetKey,
          onSubmit: (words) async {
            setState(() => _pakeWords = words);
          },
        ),
        if (_unlockError != null) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              border: Border(left: BorderSide(color: scheme.error, width: 4)),
            ),
            child: Text(
              _unlockError!,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _unlocking ? null : _handleUnlock,
          child: Text(
            _unlocking
                ? l10n.commonUnlocking
                : l10n.pairTransportInUnlockButton,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmPane() {
    final unlocked = _unlocked!;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeader(l10n.commonPairTimePhraseHeader),
        const SizedBox(height: 8),
        Text(
          l10n.pairTransportInPhraseInstruction,
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
              for (var i = 0; i < unlocked.phrase.length; i++)
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
                          unlocked.phrase[i],
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
        const SizedBox(height: 24),
        _SectionHeader(l10n.pairTransportInResponseHeader),
        const SizedBox(height: 8),
        Text(
          l10n.pairTransportInResponseInstruction,
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
            unlocked.responseWire,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final result = await SecureClipboard.copy(unlocked.responseWire);
              messenger.showSnackBar(SnackBar(
                content: Text(switch (result) {
                  SecureCopyResult.protected => l10n.commonCopiedProtected,
                  SecureCopyResult.plain => l10n.commonCopiedPlain,
                  SecureCopyResult.failed => l10n.commonCopyFailed,
                }),
              ));
            },
            icon: const Icon(Icons.copy),
            label: Text(l10n.pairTransportInCopyResponseButton),
          ),
        ),
        const SizedBox(height: 24),
        _SectionHeader(l10n.commonNameThisContactHeader),
        const SizedBox(height: 8),
        TextField(
          controller: _labelController,
          maxLength: 32,
          decoration: InputDecoration(
            hintText: l10n.commonNameHintExample,
          ),
        ),
        if (_unlockError != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            _unlockError!,
            style: TextStyle(color: scheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _committing ? null : _handleCommit,
          child: Text(_committing ? l10n.commonSaving : l10n.commonCommitPair),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _committing ? null : () => context.go('/'),
          child: Text(l10n.commonCancelCaps),
        ),
      ],
    );
  }
}

class _UnlockedState {
  _UnlockedState({
    required this.senderPublicKey,
    required this.ourKeyPair,
    required this.totpSecret,
    required this.phrase,
    required this.responseWire,
  });

  final List<int> senderPublicKey;
  final PairingKeyPair ourKeyPair;
  final List<int> totpSecret;
  final List<String> phrase;
  final String responseWire;
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
