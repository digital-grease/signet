import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/crypto/pair_role.dart';
import '../../core/crypto/transport_package.dart';
import '../../core/models/relationship.dart';
import '../../core/providers.dart';
import '../../shared/widgets/secure_screen.dart';

/// Per-record decision on how a bulk-restored relationship lands on this
/// device. Conflict rows default to [skip] (no overwrite of an existing
/// pairing); non-conflict rows default to [create].
enum _Disposition {
  /// Commit as a fresh Relationship with a brand-new local id and the
  /// record's label verbatim. Used for records whose label is NOT
  /// already paired on this device, and also for conflict records when
  /// the user explicitly accepts the collision.
  create,

  /// Commit as a fresh Relationship with `" (restored)"` appended to
  /// the label; the existing same-labelled pairing is left alone.
  rename,

  /// Replace the existing pairing's shared secret + role +
  /// silent-haptics with the values from the bulk record. Reuses the
  /// existing relationship's local id so verify screens keyed by id
  /// keep working across the restore.
  overwrite,

  /// Drop this record on the floor. Default for conflict rows; user-
  /// toggleable for non-conflict rows.
  skip,
}

/// Bulk backup import — preview + per-record commit.
///
/// Reached only via dispatch from [BackupImportScreen] when the pasted
/// wire's payload-type byte is BLK (0x03). The decoded [BlkPackage]
/// arrives via `GoRouterState.extra`; we never re-run decryption here.
/// If the user lands on this route with no extra (e.g. deep-linked), we
/// bounce back to `/inspect/import`.
///
/// Collision resolution: any record whose label matches an existing
/// paired relationship gets three per-row radios (skip / rename /
/// overwrite) with [_Disposition.skip] as the default, so the grandma-
/// test-grade accidental tap never destroys an existing pairing.
class BulkBackupImportScreen extends ConsumerStatefulWidget {
  const BulkBackupImportScreen({super.key, required this.decoded});

  final BlkPackage decoded;

  @override
  ConsumerState<BulkBackupImportScreen> createState() =>
      _BulkBackupImportScreenState();
}

class _BulkBackupImportScreenState
    extends ConsumerState<BulkBackupImportScreen> {
  List<Relationship>? _existing;
  Map<int, _Disposition> _dispositions = <int, _Disposition>{};
  Set<int> _conflictIndexes = <int>{};

  bool _busy = false;
  int _committed = 0;
  _Summary? _summary;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final store = ref.read(secureStoreProvider);
      final existing = await store.listRelationships();
      if (!mounted) return;
      final existingLabels = <String>{for (final r in existing) r.label};
      final initialDispositions = <int, _Disposition>{};
      final conflicts = <int>{};
      for (var i = 0; i < widget.decoded.records.length; i++) {
        if (existingLabels.contains(widget.decoded.records[i].label)) {
          conflicts.add(i);
          initialDispositions[i] = _Disposition.skip;
        } else {
          initialDispositions[i] = _Disposition.create;
        }
      }
      setState(() {
        _existing = existing;
        _dispositions = initialDispositions;
        _conflictIndexes = conflicts;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _handleCommit() async {
    if (_busy) return;
    final existing = _existing;
    if (existing == null) return;
    final byLabel = <String, Relationship>{
      for (final r in existing) r.label: r,
    };
    setState(() {
      _busy = true;
      _committed = 0;
      _error = null;
    });
    final store = ref.read(secureStoreProvider);
    var created = 0;
    var renamed = 0;
    var overwrote = 0;
    var skipped = 0;
    try {
      for (var i = 0; i < widget.decoded.records.length; i++) {
        final record = widget.decoded.records[i];
        final disposition = _dispositions[i] ?? _Disposition.skip;
        switch (disposition) {
          case _Disposition.skip:
            skipped++;
            break;
          case _Disposition.create:
            final fresh = Relationship(
              id: _mintId(),
              label: record.label,
              pairedAt: record.pairedAt,
              role: record.role,
              silentHaptics: record.silentHaptics,
            );
            await store.saveRelationshipV2(
              fresh,
              sharedSecret: record.sharedSecret,
            );
            created++;
            break;
          case _Disposition.rename:
            final fresh = Relationship(
              id: _mintId(),
              label: '${record.label} (restored)',
              pairedAt: record.pairedAt,
              role: record.role,
              silentHaptics: record.silentHaptics,
            );
            await store.saveRelationshipV2(
              fresh,
              sharedSecret: record.sharedSecret,
            );
            renamed++;
            break;
          case _Disposition.overwrite:
            // Reuse the existing id so verify screens keyed by id keep
            // working after the restore. Label stays the existing one
            // (which matches the record's label anyway — that's how we
            // detected the conflict).
            final existing = byLabel[record.label]!;
            final replacement = existing.copyWith(
              pairedAt: record.pairedAt,
              role: record.role,
              silentHaptics: record.silentHaptics,
            );
            await store.saveRelationshipV2(
              replacement,
              sharedSecret: record.sharedSecret,
            );
            overwrote++;
            break;
        }
        if (!mounted) return;
        setState(() => _committed = i + 1);
      }
      ref.invalidate(relationshipsProvider);
      if (!mounted) return;
      setState(() {
        _summary = _Summary(
          created: created,
          renamed: renamed,
          overwrote: overwrote,
          skipped: skipped,
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

  static String _mintId() =>
      Relationship.fresh(label: '_tmp_', role: _scratchRole()).id;

  @override
  Widget build(BuildContext context) {
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _summary == null ? 'BULK RESTORE' : 'RESTORED',
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
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $_error'),
      );
    }
    final summary = _summary;
    if (summary != null) {
      return _SuccessPane(summary: summary);
    }
    final existing = _existing;
    if (existing == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    return _PreviewPane(
      records: widget.decoded.records,
      dispositions: _dispositions,
      conflictIndexes: _conflictIndexes,
      busy: _busy,
      committed: _committed,
      onChangeDisposition: (index, disposition) {
        setState(() {
          _dispositions = Map<int, _Disposition>.from(_dispositions)
            ..[index] = disposition;
        });
      },
      onCommit: _handleCommit,
    );
  }
}

// `_mintId` needs a throwaway PairRole to ride `Relationship.fresh`'s id-
// minting side-effect; the role value itself is discarded.
PairRole _scratchRole() => PairRole.a;

// ---------------------------------------------------------------------------
// Preview pane
// ---------------------------------------------------------------------------

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({
    required this.records,
    required this.dispositions,
    required this.conflictIndexes,
    required this.busy,
    required this.committed,
    required this.onChangeDisposition,
    required this.onCommit,
  });

  final List<BlkRelationshipRecord> records;
  final Map<int, _Disposition> dispositions;
  final Set<int> conflictIndexes;
  final bool busy;
  final int committed;
  final void Function(int index, _Disposition next) onChangeDisposition;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final includedCount = dispositions.values
        .where((d) => d != _Disposition.skip)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Restore ${records.length} '
          '${records.length == 1 ? 'relationship' : 'relationships'}',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          conflictIndexes.isEmpty
              ? 'Tick the rows you want to restore. Every pairing below '
                  'will come back with its original label and pair date.'
              : 'Some of these labels are already paired on this phone. '
                  'Choose what to do for each — default is skip.',
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < records.length; i++)
          _RecordRow(
            index: i,
            record: records[i],
            isConflict: conflictIndexes.contains(i),
            disposition: dispositions[i] ?? _Disposition.skip,
            onChange: (next) => onChangeDisposition(i, next),
          ),
        const SizedBox(height: 24),
        if (busy)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Restoring $committed of ${records.length}…',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        FilledButton(
          onPressed: busy || includedCount == 0 ? null : onCommit,
          child: Text(
            busy
                ? 'RESTORING…'
                : includedCount == 0
                    ? 'NOTHING SELECTED'
                    : 'RESTORE $includedCount',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: busy ? null : () => context.go('/'),
          child: const Text('CANCEL'),
        ),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.index,
    required this.record,
    required this.isConflict,
    required this.disposition,
    required this.onChange,
  });

  final int index;
  final BlkRelationshipRecord record;
  final bool isConflict;
  final _Disposition disposition;
  final ValueChanged<_Disposition> onChange;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      color: scheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (!isConflict)
                Checkbox(
                  value: disposition == _Disposition.create,
                  onChanged: (v) => onChange(
                    v == true ? _Disposition.create : _Disposition.skip,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      border: Border.all(color: scheme.error),
                    ),
                    child: Text(
                      'ALREADY PAIRED',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        color: scheme.onErrorContainer,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      record.label.isEmpty ? '(no label)' : record.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ROLE ${record.role.wireName.toUpperCase()} · '
                      'PAIRED ${_formatDate(record.pairedAt)}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isConflict) ...<Widget>[
            const SizedBox(height: 10),
            _ConflictRadio(
              value: _Disposition.skip,
              group: disposition,
              label: 'Skip — leave existing pairing alone',
              onChanged: onChange,
            ),
            _ConflictRadio(
              value: _Disposition.rename,
              group: disposition,
              label: 'Rename restored copy to "${record.label} (restored)"',
              onChanged: onChange,
            ),
            _ConflictRadio(
              value: _Disposition.overwrite,
              group: disposition,
              label: 'Overwrite existing pairing',
              onChanged: onChange,
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final u = dt.toUtc();
    final y = u.year.toString().padLeft(4, '0');
    final m = u.month.toString().padLeft(2, '0');
    final d = u.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _ConflictRadio extends StatelessWidget {
  const _ConflictRadio({
    required this.value,
    required this.group,
    required this.label,
    required this.onChanged,
  });

  final _Disposition value;
  final _Disposition group;
  final String label;
  final ValueChanged<_Disposition> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = value == group;
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 13, color: scheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Success pane
// ---------------------------------------------------------------------------

class _Summary {
  const _Summary({
    required this.created,
    required this.renamed,
    required this.overwrote,
    required this.skipped,
  });

  final int created;
  final int renamed;
  final int overwrote;
  final int skipped;
}

class _SuccessPane extends StatelessWidget {
  const _SuccessPane({required this.summary});
  final _Summary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Restore complete.',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _SummaryRow(label: 'RESTORED //', value: summary.created),
        if (summary.renamed > 0)
          _SummaryRow(label: 'RENAMED //', value: summary.renamed),
        if (summary.overwrote > 0)
          _SummaryRow(label: 'OVERWROTE //', value: summary.overwrote),
        if (summary.skipped > 0)
          _SummaryRow(label: 'SKIPPED //', value: summary.skipped),
        const SizedBox(height: 20),
        Text(
          summary.created + summary.renamed + summary.overwrote == 0
              ? 'Nothing was changed on this phone.'
              : 'Each restored pairing uses the same shared secret as the '
                  "old phone; their other side won't notice the restore "
                  'unless they rekey.',
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('DONE'),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: scheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
          children: <TextSpan>[
            TextSpan(text: label.padRight(16)),
            TextSpan(
              text: value.toString(),
              style: TextStyle(color: scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
