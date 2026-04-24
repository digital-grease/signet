import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/crypto/backup_bundle.dart';
import '../../core/crypto/transport_package.dart';
import '../../core/models/relationship.dart';
import '../../core/providers.dart';
import '../../shared/widgets/secure_screen.dart';

/// Bulk backup export — one bundle, one PAKE, every paired relationship.
///
/// Mirrors [BackupExportScreen] structurally but iterates the entire
/// `SecureStore.listRelationships()` set and encodes them into a single
/// BLK transport-package payload (see `.devloop/spikes/bulk-backup.md`).
/// The user runs this once when switching phones instead of N separate
/// export flows.
///
/// Wire shape at the [BackupBundle] layer is identical to a single-
/// relationship export — one `signet:tp1:` line + one 8-word PAKE line —
/// so the platform share-sheet handoff and file-parser on the receiving
/// side don't need format-specific branches. Dispatch between single
/// and bulk happens on the payload-type byte during import.
class BulkBackupExportScreen extends ConsumerStatefulWidget {
  const BulkBackupExportScreen({super.key});

  @override
  ConsumerState<BulkBackupExportScreen> createState() =>
      _BulkBackupExportScreenState();
}

class _BulkBackupExportScreenState
    extends ConsumerState<BulkBackupExportScreen> {
  List<Relationship>? _relationships;
  _Generated? _generated;
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadRelationships();
  }

  Future<void> _loadRelationships() async {
    try {
      final store = ref.read(secureStoreProvider);
      final rels = await store.listRelationships();
      if (!mounted) return;
      setState(() => _relationships = rels);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _handleGenerate() async {
    final rels = _relationships;
    if (rels == null || rels.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final store = ref.read(secureStoreProvider);
      final records = <BlkRelationshipRecord>[];
      for (final r in rels) {
        final secret = await store.getSharedSecretById(r.id);
        if (secret == null) continue;
        records.add(BlkRelationshipRecord(
          sharedSecret: secret,
          role: r.role,
          label: r.label,
          pairedAt: r.pairedAt,
          silentHaptics: r.silentHaptics,
        ));
      }
      if (records.isEmpty) {
        throw StateError('No relationships had retrievable secrets.');
      }
      final pakeWords = TransportPackage.mintPakeWords();
      final wire = await TransportPackage.encodeBlk(
        records: records,
        pakeWords: pakeWords,
      );
      if (!mounted) return;
      setState(() {
        _generated = _Generated(
          recordCount: records.length,
          pakeWords: pakeWords,
          wire: wire,
        );
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _generated == null ? 'BACK UP EVERYTHING' : 'BULK BACKUP READY',
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go('/'),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null && _generated == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Could not prepare backup: $_error'),
      );
    }
    final rels = _relationships;
    if (rels == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (rels.isEmpty && _generated == null) {
      return _EmptyState();
    }
    final gen = _generated;
    if (gen == null) {
      return _ReadyToGenerate(
        relationships: rels,
        busy: _busy,
        onGenerate: _handleGenerate,
        error: _error,
      );
    }
    return _BulkBackupContent(generated: gen);
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Nothing to back up yet.',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pair with someone first, then come back here to create a '
            'bulk backup.',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyToGenerate extends StatelessWidget {
  const _ReadyToGenerate({
    required this.relationships,
    required this.busy,
    required this.onGenerate,
    required this.error,
  });

  final List<Relationship> relationships;
  final bool busy;
  final VoidCallback onGenerate;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Back up ${relationships.length} '
          '${relationships.length == 1 ? 'relationship' : 'relationships'}',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Every paired contact below goes into one encrypted file with '
          'one 8-word PAKE. You store the file and the words separately, '
          'then use them to bring every pairing across to a new phone.',
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          color: scheme.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final r in relationships)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          r.label,
                          style: TextStyle(
                            fontSize: 15,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        r.role.wireName.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: 12),
          Text('$error', style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy ? null : onGenerate,
          child: Text(busy ? 'GENERATING…' : 'GENERATE BULK BACKUP'),
        ),
      ],
    );
  }
}

class _BulkBackupContent extends StatelessWidget {
  const _BulkBackupContent({required this.generated});
  final _Generated generated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '${generated.recordCount} '
          '${generated.recordCount == 1 ? 'relationship' : 'relationships'} '
          'backed up',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
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
              'can restore every pairing on their own phone. Paper in two '
              'places (home + safety deposit box) is a reasonable start. '
              'A password manager that syncs to a cloud is NOT.',
        ),
        const SizedBox(height: 24),
        const _SectionHeader('PAKE SECRET'),
        const SizedBox(height: 6),
        Text(
          'Write these 8 words somewhere safe. You will type them into '
          'the new phone to unlock everything at once.',
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
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(
                  ClipboardData(text: generated.pakeWords.join(' ')),
                );
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('PAKE words copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy PAKE'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionHeader('BACKUP PACKAGE'),
        const SizedBox(height: 6),
        Text(
          'The whole set of pairings, encrypted with the 8 words above. '
          'Share this via any channel — the words keep it sealed.',
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
                final bundle = BackupBundle.format(
                  peerLabel:
                      '${generated.recordCount} relationships (bulk)',
                  wire: generated.wire,
                  pakeWords: generated.pakeWords,
                  generatedAt: DateTime.now(),
                );
                await SharePlus.instance.share(
                  ShareParams(
                    text: bundle,
                    subject:
                        'Signet bulk backup - ${generated.recordCount} peers',
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
              'If this file AND the 8 words are ever found by someone '
              'else, UNPAIR every relationship in it and re-pair in '
              'person. The backup contains the same shared secrets your '
              'current pairings use.',
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

class _Generated {
  _Generated({
    required this.recordCount,
    required this.pakeWords,
    required this.wire,
  });

  final int recordCount;
  final List<String> pakeWords;
  final String wire;
}
