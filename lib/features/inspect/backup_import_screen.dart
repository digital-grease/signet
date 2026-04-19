import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/crypto/backup_bundle.dart';
import '../../core/crypto/pair_role.dart';
import '../../core/crypto/transport_package.dart';
import '../../core/models/relationship.dart';
import '../../core/providers.dart';
import '../../shared/widgets/secure_screen.dart';
import '../verify/word_input.dart';

/// Lost-phone recovery import. Mirror of `BackupExportScreen`:
///
/// 1. **Unlock**: user pastes the LPR wire (from QR scan on paper or
///    clipboard) and enters the 8-word PAKE secret they stored
///    separately when they created the backup.
/// 2. **Preview + commit**: app decodes → renders a summary (label,
///    originally-paired date, role) → user taps COMMIT IMPORT. A fresh
///    `Relationship` is written to storage with a new local id but the
///    decoded label + role + silentHaptics. `pairedAt` is stamped to
///    now — that reflects "the rematerialization moment on this
///    device." The peer is unaware of the restore: their device still
///    has the original shared secret, and subsequent verifies work
///    unless they've rekeyed in the interim.
class BackupImportScreen extends ConsumerStatefulWidget {
  const BackupImportScreen({super.key});

  @override
  ConsumerState<BackupImportScreen> createState() =>
      _BackupImportScreenState();
}

class _BackupImportScreenState extends ConsumerState<BackupImportScreen> {
  final TextEditingController _packageController = TextEditingController();
  List<String> _pakeWords = const <String>[];
  int _pakeResetKey = 0;

  String? _error;
  bool _busy = false;

  LprPackage? _decoded;

  @override
  void dispose() {
    _packageController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Load from file
  // ------------------------------------------------------------------

  Future<void> _handleLoadFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      // Allow either plain text or arbitrary — don't filter on extension
      // because Android's file picker is flaky about .txt vs .* filtering.
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    String contents;
    try {
      if (file.bytes != null) {
        contents = String.fromCharCodes(file.bytes!);
      } else if (file.path != null) {
        contents = await File(file.path!).readAsString();
      } else {
        setState(() => _error = 'Could not read the selected file.');
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not read the file: $e');
      return;
    }
    try {
      final bundle = BackupBundle.parse(contents);
      if (!mounted) return;
      setState(() {
        _packageController.text = bundle.wire;
        // NOTE: WordInput currently doesn't support programmatic pre-fill
        // — the user must paste the PAKE line (or re-type). To bridge
        // the gap we populate _pakeWords directly, which the UNLOCK
        // handler reads. The WordInput remains visually empty. For a
        // clean UX polish pass, extend WordInput with a `prefillWords`
        // prop and wire it via resetKey.
        _pakeResetKey++;
        _pakeWords = bundle.pakeWords;
        _error = null;
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'File is not a valid Signet backup: ${e.message}');
    }
  }

  // ------------------------------------------------------------------
  // Unlock
  // ------------------------------------------------------------------

  Future<void> _handleUnlock() async {
    if (_busy) return;
    final wire = _packageController.text.trim();
    if (wire.isEmpty) {
      setState(() => _error = 'Paste your backup package.');
      return;
    }
    if (_pakeWords.length != 8) {
      setState(() => _error = 'Enter the 8 PAKE words you stored separately.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final decoded = await TransportPackage.decodeLpr(
        wire,
        pakeWords: _pakeWords,
      );
      if (!mounted) return;
      setState(() {
        _decoded = decoded;
        _busy = false;
      });
    } on InvalidPakeException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not unlock: ${e.message}';
        _busy = false;
        _pakeResetKey++;
      });
    } on InvalidPackageException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not unlock: $e';
        _busy = false;
      });
    }
  }

  // ------------------------------------------------------------------
  // Commit import
  // ------------------------------------------------------------------

  Future<void> _handleCommit() async {
    final decoded = _decoded;
    if (decoded == null || _busy) return;
    setState(() => _busy = true);
    try {
      final fresh = Relationship.fresh(
        label: decoded.label,
        role: decoded.role,
        silentHaptics: decoded.silentHaptics,
      );
      await ref.read(secureStoreProvider).saveRelationshipV2(
            fresh,
            sharedSecret: decoded.sharedSecret,
          );
      ref.invalidate(relationshipsProvider);
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save: $e';
        _busy = false;
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
          title: Text(_decoded == null ? 'RESTORE BACKUP' : 'CONFIRM IMPORT'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go('/'),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: _decoded == null ? _buildUnlockPane() : _buildCommitPane(),
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
        const _SectionHeader('BACKUP PACKAGE'),
        const SizedBox(height: 6),
        Text(
          'Paste the backup package from your paper. Starts with "signet:tp1:". '
          'If you scanned a QR, paste the text that came out.',
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
          decoration: const InputDecoration(hintText: 'signet:tp1:...'),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton.icon(
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text == null) return;
                setState(() => _packageController.text = data!.text!);
              },
              icon: const Icon(Icons.content_paste),
              label: const Text('Paste from clipboard'),
            ),
            TextButton.icon(
              onPressed: _handleLoadFromFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Load from file'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionHeader('PAKE SECRET'),
        const SizedBox(height: 6),
        Text(
          'The 8 words from your paper or password manager — stored '
          'separately from the package above.',
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
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              border: Border(left: BorderSide(color: scheme.error, width: 4)),
            ),
            child: Text(
              _error!,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _handleUnlock,
          child: Text(_busy ? 'UNLOCKING…' : 'UNLOCK BACKUP'),
        ),
      ],
    );
  }

  Widget _buildCommitPane() {
    final decoded = _decoded!;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionHeader('RESTORED PEER'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          color: scheme.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                decoded.label,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              _MonoKV(k: 'ROLE //', v: decoded.role.wireName.toUpperCase()),
              _MonoKV(
                k: 'ORIGINALLY //',
                v: _formatDate(decoded.pairedAt),
              ),
              _MonoKV(
                k: 'HAPTICS //',
                v: decoded.silentHaptics ? 'OFF' : 'ON',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            border: Border(left: BorderSide(color: scheme.secondary, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'WHAT THIS DOES //',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: scheme.secondary,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'This phone will start sharing a secret with ${decoded.label} '
                "using the same key material as the old phone. ${decoded.label}'s "
                "phone won't know anything changed. If they've already "
                'rekeyed with someone else since your backup, verifies '
                'will fail until you re-pair in person.',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurface,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _handleCommit,
          child: Text(_busy ? 'SAVING…' : 'COMMIT IMPORT'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy ? null : () => context.go('/'),
          child: const Text('CANCEL'),
        ),
      ],
    );
  }

  static String _formatDate(DateTime dt) {
    final u = dt.toUtc();
    final y = u.year.toString().padLeft(4, '0');
    final m = u.month.toString().padLeft(2, '0');
    final d = u.day.toString().padLeft(2, '0');
    return '$y-$m-$d UTC';
  }
}

class _MonoKV extends StatelessWidget {
  const _MonoKV({required this.k, required this.v});
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
          children: <TextSpan>[
            TextSpan(text: k.padRight(14)),
            TextSpan(text: v, style: TextStyle(color: scheme.onSurface)),
          ],
        ),
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

// Silence "only imported for PairRole" if tree-shaken — PairRole is used
// through LprPackage.role.
// ignore: unused_element
void _pairRoleRef() {
  const _ = PairRole.a;
}
