import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/crypto/backup_bundle.dart';
import '../../core/crypto/transport_package.dart';
import '../../core/models/relationship.dart';
import '../../core/providers.dart';
import '../../shared/widgets/secure_screen.dart';

/// Paper-mnemonic export for lost-phone recovery. Mints a fresh 8-word
/// PAKE secret, encodes the existing relationship as an LPR package, and
/// presents both to the user with instructions to **store them separately
/// and offline**. The package-text is rendered both as a QR (for cameras)
/// and as selectable text (for paste / OCR / backup). The PAKE secret is
/// rendered as a numbered mono list the user writes down somewhere
/// different — a password manager, a safety deposit box, whatever.
///
/// Critically: the user must store the PAKE secret on a different
/// physical artifact than the package itself. If an attacker finds both,
/// they have the full shared secret. This is called out explicitly in
/// the WARNING block.
///
/// Wrapped in [SecureScreen] — the package contains the shared secret
/// (encrypted) and the PAKE secret is plaintext; screenshots would
/// capture both.
class BackupExportScreen extends ConsumerStatefulWidget {
  const BackupExportScreen({super.key, required this.relationshipId});

  final String relationshipId;

  @override
  ConsumerState<BackupExportScreen> createState() =>
      _BackupExportScreenState();
}

class _BackupExportScreenState extends ConsumerState<BackupExportScreen> {
  _Generated? _generated;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      final store = ref.read(secureStoreProvider);
      final relationship =
          await store.getRelationshipById(widget.relationshipId);
      final secret =
          await store.getSharedSecretById(widget.relationshipId);
      if (!mounted) return;
      if (relationship == null || secret == null) {
        setState(() => _error = StateError('Relationship not found.'));
        return;
      }
      final pakeWords = TransportPackage.mintPakeWords();
      final wire = await TransportPackage.encodeLpr(
        label: relationship.label,
        role: relationship.role,
        pairedAt: relationship.pairedAt,
        silentHaptics: relationship.silentHaptics,
        sharedSecret: secret,
        pakeWords: pakeWords,
      );
      if (!mounted) return;
      setState(() {
        _generated = _Generated(
          relationship: relationship,
          pakeWords: pakeWords,
          wire: wire,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BACK UP TO PAPER'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go('/'),
          ),
        ),
        body: SafeArea(
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not generate backup: $_error'),
        ),
      );
    }
    final gen = _generated;
    if (gen == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: _BackupContent(generated: gen),
    );
  }
}

class _BackupContent extends StatelessWidget {
  const _BackupContent({required this.generated});
  final _Generated generated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Back up ${generated.relationship.label}',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Writing this down lets you restore this pairing on a new phone '
          "if you lose this one. ${generated.relationship.label}'s phone "
          "won't know anything changed.",
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        _WarningBlock(
          color: scheme.error,
          bg: scheme.errorContainer,
          fg: scheme.onErrorContainer,
          headline: 'STORE THESE SEPARATELY //',
          body:
              'The PAKE secret and the backup package must live on '
              'different physical artifacts. If someone finds both, they '
              'can restore this pairing on their own phone. Paper in two '
              'places (home + safety deposit box) is a reasonable start. '
              'A password manager that syncs to a cloud is NOT.',
        ),
        const SizedBox(height: 24),
        const _SectionHeader('PAKE SECRET'),
        const SizedBox(height: 6),
        Text(
          'Write these 8 words somewhere safe. You will type them into '
          'the new phone to unlock the package.',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < generated.pakeWords.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
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
                          generated.pakeWords[i],
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
        const SizedBox(height: 24),
        const _SectionHeader('BACKUP PACKAGE'),
        const SizedBox(height: 6),
        Text(
          'Scan this QR on the new phone, or copy-paste the text below. '
          'This is a different artifact from the PAKE secret above — do '
          'not store them together.',
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: QrImageView(
              data: generated.wire,
              size: 240,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(8),
              gapless: true,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          color: scheme.surfaceContainerHighest,
          child: SelectableText(
            generated.wire,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: generated.wire));
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Package copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy package'),
            ),
            TextButton.icon(
              onPressed: () async {
                // Hand the whole bundle to the platform share sheet so
                // the user can save it anywhere (Files, an encrypted
                // note, Bluetooth to another device, etc.). We do NOT
                // pick cloud destinations for them — the user does.
                final bundle = BackupBundle.format(
                  peerLabel: generated.relationship.label,
                  wire: generated.wire,
                  pakeWords: generated.pakeWords,
                  generatedAt: DateTime.now(),
                );
                await SharePlus.instance.share(
                  ShareParams(
                    text: bundle,
                    subject:
                        'Signet backup - ${generated.relationship.label}',
                  ),
                );
              },
              icon: const Icon(Icons.ios_share),
              label: const Text('Share package'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _WarningBlock(
          color: scheme.secondary,
          bg: scheme.surfaceContainerHighest,
          fg: scheme.onSurface,
          headline: 'REMEMBER //',
          body:
              'If this paper is ever found by someone else, UNPAIR '
              '${generated.relationship.label} immediately and re-pair '
              'in person. The backup contains the same shared secret '
              'your current pairing uses.',
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/'),
          child: const Text("I'VE SAVED IT"),
        ),
      ],
    );
  }
}

class _WarningBlock extends StatelessWidget {
  const _WarningBlock({
    required this.color,
    required this.bg,
    required this.fg,
    required this.headline,
    required this.body,
  });

  final Color color;
  final Color bg;
  final Color fg;
  final String headline;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            headline,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: color,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(fontSize: 13, color: fg, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Generated {
  _Generated({
    required this.relationship,
    required this.pakeWords,
    required this.wire,
  });

  final Relationship relationship;
  final List<String> pakeWords;
  final String wire;
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
