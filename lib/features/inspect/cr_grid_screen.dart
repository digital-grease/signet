import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../core/crypto/challenge_response_grid.dart';
import '../../core/models/relationship.dart';
import '../../core/providers.dart';
import '../../shared/widgets/secure_screen.dart';
import 'cr_grid_pdf.dart';

/// Digital viewer for the challenge-response grid. Renders the full 8×8
/// table derived from the pair's shared secret. Used as the on-device
/// companion for the paper card — the challenger opens this screen on
/// their phone and, when the responder speaks a cell's answer, the
/// challenger locates the cell here and silently compares.
///
/// The responder, by definition of this fallback mode, is reading from
/// printed paper (no phone). They don't need this screen. Print export
/// ships in Task 11.7.
///
/// Entry: per-peer long-press menu → "Challenge-response grid."
class CrGridScreen extends ConsumerStatefulWidget {
  const CrGridScreen({super.key, required this.relationshipId});

  final String relationshipId;

  @override
  ConsumerState<CrGridScreen> createState() => _CrGridScreenState();
}

class _CrGridScreenState extends ConsumerState<CrGridScreen> {
  Relationship? _relationship;
  ChallengeResponseGrid? _grid;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final store = ref.read(secureStoreProvider);
      final relationship =
          await store.getRelationshipById(widget.relationshipId);
      final secret =
          await store.getSharedSecretById(widget.relationshipId);
      if (!mounted) return;
      if (relationship == null || secret == null) {
        setState(() => _loadError = StateError('Relationship not found.'));
        return;
      }
      final grid = await ChallengeResponseGrid.derive(secret);
      if (!mounted) return;
      setState(() {
        _relationship = relationship;
        _grid = grid;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  Future<void> _printGrid() async {
    final grid = _grid;
    final relationship = _relationship;
    if (grid == null || relationship == null) return;
    await Printing.layoutPdf(
      onLayout: (format) => CrGridPdf.build(
        peerLabel: relationship.label,
        grid: grid,
        generatedAt: DateTime.now(),
      ),
      name: 'signet-cr-${relationship.label}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPrint = _grid != null && _relationship != null;
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CHALLENGE-RESPONSE'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Print grid',
              icon: const Icon(Icons.print_outlined),
              onPressed: canPrint ? _printGrid : null,
            ),
          ],
        ),
        body: SafeArea(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load grid: $_loadError'),
        ),
      );
    }
    final grid = _grid;
    final relationship = _relationship;
    if (grid == null || relationship == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Grid for ${relationship.label}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "When ${relationship.label} can't use their phone but can speak, "
            'use this grid as a fallback. You ask for a cell (e.g. '
            '"${grid.rowLabels.first} × ${grid.colLabels.first}"); they '
            'read the answer from the paper copy you both shared. Compare '
            'silently on your side.',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              border:
                  Border(left: BorderSide(color: scheme.secondary, width: 4)),
            ),
            child: Text(
              'This is a FALLBACK. If you can run a rotating-word verify, '
              'do that first — its defenses are stronger. Use this only '
              'when the responder has no phone.',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionHeader('GRID // 8×8'),
          const SizedBox(height: 10),
          _GridTable(grid: grid),
          const SizedBox(height: 20),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            'AIRPLANE // NO NETWORK · NO TELEMETRY · STRONGBOX',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: scheme.onSurfaceVariant,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridTable extends StatelessWidget {
  const _GridTable({required this.grid});

  final ChallengeResponseGrid grid;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Column header row (col labels).
          Row(
            children: <Widget>[
              const SizedBox(width: 72),
              for (final col in grid.colLabels)
                Container(
                  width: 80,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  child: Text(
                    col,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: scheme.secondary,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          // Body rows.
          for (var row = 0; row < ChallengeResponseGrid.rowCount; row++)
            Container(
              height: 64,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: scheme.outlineVariant, width: 1),
                ),
              ),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 72,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          grid.rowLabels[row],
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: scheme.secondary,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  for (var col = 0;
                      col < ChallengeResponseGrid.colCount;
                      col++)
                    _CellTile(
                      rowLabel: grid.rowLabels[row],
                      colLabel: grid.colLabels[col],
                      words: grid.cells[row][col],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CellTile extends StatelessWidget {
  const _CellTile({
    required this.rowLabel,
    required this.colLabel,
    required this.words,
  });

  final String rowLabel;
  final String colLabel;
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showAnswer(context),
        child: Container(
          width: 80,
          height: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: scheme.outlineVariant, width: 1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final word in words)
                Text(
                  word,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: scheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAnswer(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(
            '$rowLabel × $colLabel',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: scheme.secondary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final word in words)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    word,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
            ],
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
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
