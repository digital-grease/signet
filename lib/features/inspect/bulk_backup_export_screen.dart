import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/crypto/backup_bundle.dart';
import '../../core/crypto/transport_package.dart';
import '../../core/models/label_policy.dart';
import '../../core/models/relationship.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/secure_screen.dart';
import 'two_step_backup.dart';

/// Bulk backup export — one bundle, one PAKE, every paired relationship.
///
/// Mirrors [BackupExportScreen] structurally but iterates the entire
/// `SecureStore.listRelationships()` set and encodes them into a single
/// BLK transport-package payload (see `.devloop/spikes/bulk-backup.md`).
/// The user runs this once when switching phones instead of N separate
/// export flows.
///
/// The saved files have the same shape as a single-relationship export
/// (a PACKAGE file and a WORDS file, see [BackupFiles]), so the restore
/// screen reads both the same way. Single and bulk are told apart by the
/// payload-type byte during import.
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
          // A name saved before the 64-byte limit is cut to fit; one long
          // name must not fail the whole backup.
          label: LabelPolicy.truncateToBytes(r.label, LabelPolicy.maxBytes),
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
      final fingerprint = await BackupFiles.fingerprint(wire);
      if (!mounted) return;
      setState(() {
        _generated = _Generated(
          recordCount: records.length,
          pakeWords: pakeWords,
          wire: wire,
          fingerprint: fingerprint!,
          generatedAt: DateTime.now(),
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
        unreadableCount: ref.watch(unreadableRelationshipsProvider).maybeWhen(
              data: (ids) => ids.length,
              orElse: () => 0,
            ),
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
    this.unreadableCount = 0,
  });

  /// Stored contacts that cannot be read (plan Task 4.4); not backed up.
  final int unreadableCount;
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
        if (unreadableCount > 0) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            l10n.bulkBackupExportSkipsUnreadable(unreadableCount),
            style: TextStyle(color: scheme.error, height: 1.4),
          ),
        ],
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
        const SizedBox(height: 16),
        _WarningBlock(
          color: scheme.secondary,
          bg: scheme.surfaceContainerHighest,
          fg: scheme.onSurface,
          headline: l10n.commonRememberHeader,
          body: l10n.bulkBackupExportRememberBody,
        ),
        const SizedBox(height: 24),
        // Package and words are saved in two separate steps and never
        // travel together (plan Phase 2, bug S1). No copy button for the
        // words (Task 2.4).
        TwoStepBackupSaver(
          wire: generated.wire,
          pakeWords: generated.pakeWords,
          fingerprint: generated.fingerprint,
          generatedAt: generated.generatedAt,
          showQr: false,
          onDone: () => context.go('/'),
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
    required this.recordCount,
    required this.pakeWords,
    required this.wire,
    required this.fingerprint,
    required this.generatedAt,
  });

  final int recordCount;
  final List<String> pakeWords;
  final String wire;
  final String fingerprint;
  final DateTime generatedAt;
}
