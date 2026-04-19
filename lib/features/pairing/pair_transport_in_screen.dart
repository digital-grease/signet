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
      setState(() => _unlockError = 'Paste the package from the sender.');
      return;
    }
    if (_pakeWords.length != 8) {
      setState(() => _unlockError = 'Enter all 8 words from the sender.');
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
        _unlockError = 'Could not unlock: ${e.message}';
        _unlocking = false;
        _pakeResetKey++;
      });
    } on InvalidPackageException catch (e) {
      if (!mounted) return;
      setState(() {
        _unlockError = e.message;
        _unlocking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _unlockError = 'Failed to process package: $e';
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
      setState(() => _unlockError = 'Give this contact a name.');
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
      ref.invalidate(relationshipsProvider);
      if (!mounted) return;
      context.go('/pair/complete/${relationship.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _unlockError = 'Could not save: $e';
        _committing = false;
      });
    }
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_unlocked == null ? 'IMPORT PACKAGE' : 'CONFIRM PAIRING'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionHeader('INCOMING PACKAGE'),
        const SizedBox(height: 8),
        Text(
          'Paste the text the sender gave you. Starts with "signet:tp1:".',
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
            label: const Text('Paste from clipboard'),
          ),
        ),
        const SizedBox(height: 16),
        const _SectionHeader('PAKE SECRET'),
        const SizedBox(height: 6),
        Text(
          'The 8 words the sender shared with you over a trusted channel '
          '(paper, encrypted email, a prior meeting note). Do not accept '
          'these words over an unverified voice call.',
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
          child: Text(_unlocking ? 'UNLOCKING…' : 'UNLOCK PACKAGE'),
        ),
      ],
    );
  }

  Widget _buildConfirmPane() {
    final unlocked = _unlocked!;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionHeader('PAIR-TIME PHRASE'),
        const SizedBox(height: 8),
        Text(
          'Ask the sender to confirm these 4 words appear on their screen, '
          'via the same trusted channel you used to share the PAKE secret. '
          'If they match, the package is authentic.',
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
        const _SectionHeader('YOUR RESPONSE'),
        const SizedBox(height: 8),
        Text(
          'Send this back to the sender, using the same channel you used '
          'to receive theirs. They will paste it to finish pairing.',
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
              await Clipboard.setData(
                ClipboardData(text: unlocked.responseWire),
              );
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Response copied to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy response'),
          ),
        ),
        const SizedBox(height: 24),
        const _SectionHeader('NAME THIS CONTACT'),
        const SizedBox(height: 8),
        TextField(
          controller: _labelController,
          maxLength: 32,
          decoration: const InputDecoration(
            hintText: 'e.g. Alice',
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
          child: Text(_committing ? 'SAVING…' : 'COMMIT PAIR'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _committing ? null : () => context.go('/'),
          child: const Text('CANCEL'),
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
      '$label //',
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
