import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/crypto/backup_bundle.dart';
import '../../core/crypto/transport_package.dart';
import '../../core/models/relationship.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
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
        throw StateError(l10n.bulkBackupExportNoSecretsError);
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
            _generated == null
                ? AppLocalizations.of(context).bulkBackupExportSetupTitle
                : AppLocalizations.of(context).bulkBackupExportReadyTitle,
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
        child: Text(
          AppLocalizations.of(context)
              .bulkBackupExportPrepareError(_error.toString()),
        ),
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
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.bulkBackupExportEmptyTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.bulkBackupExportEmptyBody,
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.bulkBackupExportReadyHeading(relationships.length),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.bulkBackupExportReadyBody,
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
          child: Text(
              busy ? l10n.commonGenerating : l10n.bulkBackupExportGenerateButton),
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.bulkBackupExportDoneHeading(generated.recordCount),
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
          headline: l10n.commonStoreSeparatelyHeader,
          body: l10n.bulkBackupExportStoreSeparatelyBody,
        ),
        const SizedBox(height: 24),
        _SectionHeader(l10n.commonPakeSecretHeader),
        const SizedBox(height: 6),
        Text(
          l10n.bulkBackupExportWordsInstruction,
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
                  SnackBar(
                    content:
                        Text(l10n.bulkBackupExportPakeCopiedSnackbar),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: Text(l10n.bulkBackupExportCopyPakeButton),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionHeader(l10n.commonBackupPackageHeader),
        const SizedBox(height: 6),
        Text(
          l10n.bulkBackupExportPackageInstruction,
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
                  SnackBar(
                    content: Text(l10n.commonPackageCopiedSnackbar),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: Text(l10n.commonCopyPackage),
            ),
            TextButton.icon(
              onPressed: () async {
                final bundle = BackupBundle.format(
                  peerLabel: l10n.bulkBackupExportShareLabel(
                    generated.recordCount,
                  ),
                  wire: generated.wire,
                  pakeWords: generated.pakeWords,
                  generatedAt: DateTime.now(),
                );
                await SharePlus.instance.share(
                  ShareParams(
                    text: bundle,
                    subject: l10n.bulkBackupExportShareSubject(
                      generated.recordCount,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.ios_share),
              label: Text(l10n.commonSharePackage),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _WarningBlock(
          color: scheme.secondary,
          bg: scheme.surfaceContainerHighest,
          fg: scheme.onSurface,
          headline: l10n.commonRememberHeader,
          body: l10n.bulkBackupExportRememberBody,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/'),
          child: Text(l10n.commonIveSavedIt),
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
