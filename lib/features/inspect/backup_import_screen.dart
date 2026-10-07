import 'dart:async';
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
import '../../l10n/app_localizations.dart';
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
    final result = await FilePicker.pickFiles(
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
        setState(() => _error =
            AppLocalizations.of(context).backupImportFileReadError);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = AppLocalizations.of(context)
            .backupImportFileReadFailedError(e.toString()),
      );
      return;
    }
    try {
      final bundle = BackupBundle.parse(contents);
      if (!mounted) return;
      setState(() {
        _packageController.text = bundle.wire;
        // Bumping _pakeResetKey causes WordInput to re-run _reset, which
        // now picks up the new prefillWords value below and populates
        // the slots visibly (phase-1 bugfix — previously the slots
        // rendered empty and only the internal _pakeWords cache held
        // the loaded words, which was confusing to users who didn't
        // realise UNLOCK would work without re-typing).
        _pakeResetKey++;
        _pakeWords = bundle.pakeWords;
        _error = null;
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = AppLocalizations.of(context)
            .backupImportInvalidFileError(e.message),
      );
    }
  }

  // ------------------------------------------------------------------
  // Unlock
  // ------------------------------------------------------------------

  Future<void> _handleUnlock() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final wire = _packageController.text.trim();
    if (wire.isEmpty) {
      setState(() => _error = l10n.backupImportPasteEmptyError);
      return;
    }
    if (_pakeWords.length != 8) {
      setState(() => _error = l10n.backupImportWordsIncompleteError);
      return;
    }

    // Payload-type dispatch — branch between single-relationship (LPR) and
    // bulk (BLK) restores before attempting decryption. Reject LDP (pairing
    // invitations are not backups) and any unknown / malformed wire with
    // a user-facing error.
    final payloadType = TransportPackage.peekPayloadType(wire);
    if (payloadType == null) {
      setState(() => _error = l10n.backupImportNotBackupError);
      return;
    }
    if (payloadType == TransportPayloadType.ldp) {
      setState(() => _error = l10n.backupImportInvitationError);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    if (payloadType == TransportPayloadType.blk) {
      try {
        final decoded = await TransportPackage.decodeBlk(
          wire,
          pakeWords: _pakeWords,
        );
        if (!mounted) return;
        // Hand off to the bulk-import flow — the screen owns preview,
        // collision resolution, and per-record commit. Single-screen
        // dispatch avoids asking the user for the same 8 words twice.
        setState(() => _busy = false);
        unawaited(
          context.push('/inspect/import-bulk', extra: decoded),
        );
      } on InvalidPakeException catch (e) {
        if (!mounted) return;
        setState(() {
          _error = AppLocalizations.of(context).commonUnlockFailedError(
            e.message,
          );
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
          _error = AppLocalizations.of(context)
              .commonUnlockFailedError(e.toString());
          _busy = false;
        });
      }
      return;
    }

    // LPR — single-relationship restore, existing flow.
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
        _error =
            AppLocalizations.of(context).commonUnlockFailedError(e.message);
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
        _error = AppLocalizations.of(context)
            .commonUnlockFailedError(e.toString());
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
        _error =
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
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_decoded == null
              ? l10n.backupImportRestoreTitle
              : l10n.backupImportConfirmTitle),
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeader(l10n.commonBackupPackageHeader),
        const SizedBox(height: 6),
        Text(
          l10n.backupImportPasteInstruction,
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
                if (!mounted) return;
                final text = data?.text;
                if (text == null || text.trim().isEmpty) {
                  setState(
                    () => _error = l10n.backupImportClipboardEmptyError,
                  );
                  return;
                }
                setState(() {
                  _packageController.text = text;
                  _error = null;
                });
              },
              icon: const Icon(Icons.content_paste),
              label: Text(l10n.commonPasteFromClipboard),
            ),
            TextButton.icon(
              onPressed: _handleLoadFromFile,
              icon: const Icon(Icons.folder_open),
              label: Text(l10n.backupImportLoadFromFileButton),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionHeader(l10n.commonPakeSecretHeader),
        const SizedBox(height: 6),
        Text(
          l10n.backupImportWordsInstruction,
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
          prefillWords: _pakeWords.length == 8 ? _pakeWords : null,
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
          child: Text(
            _busy ? l10n.commonUnlocking : l10n.backupImportUnlockButton,
          ),
        ),
      ],
    );
  }

  Widget _buildCommitPane() {
    final decoded = _decoded!;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeader(l10n.backupImportRestoredPeerHeader),
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
              _MonoKV(
                k: l10n.backupImportRoleLabel,
                v: decoded.role.wireName.toUpperCase(),
              ),
              _MonoKV(
                k: l10n.backupImportOriginallyLabel,
                v: _formatDate(decoded.pairedAt),
              ),
              _MonoKV(
                k: l10n.backupImportHapticsLabel,
                v: decoded.silentHaptics
                    ? l10n.backupImportHapticsOff
                    : l10n.backupImportHapticsOn,
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
                l10n.backupImportWhatItDoesHeader,
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
                l10n.backupImportWhatItDoesBody(decoded.label),
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
          child: Text(_busy ? l10n.commonSaving : l10n.backupImportCommitButton),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy ? null : () => context.go('/'),
          child: Text(l10n.commonCancelCaps),
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

// Silence "only imported for PairRole" if tree-shaken — PairRole is used
// through LprPackage.role.
// ignore: unused_element
void _pairRoleRef() {
  const _ = PairRole.a;
}
