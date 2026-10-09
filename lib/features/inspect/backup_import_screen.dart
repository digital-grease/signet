import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show listEquals;
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
import '../../shared/package_error_text.dart';
import '../../shared/widgets/secure_screen.dart';
import '../verify/word_input.dart';

/// Lost-phone recovery import. Mirror of `BackupExportScreen`:
///
/// 1. **Unlock**: user loads or pastes the package (the PACKAGE file, or
///    an old combined backup) and types or loads the 8 words they kept
///    apart from it (on paper, or in the WORDS file). Before decrypting,
///    a WORDS file's fingerprint is checked against the package so a
///    mix-up between two backups is named as such.
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

  /// Every package wire read from the last loaded or pasted text, longest
  /// join first (see [BackupText.wireCandidates]). The field shows the
  /// first; the rest are tried only while the field still holds it.
  List<String> _packageCandidates = const <String>[];

  /// Fingerprint from the header of a loaded WORDS file, and the words it
  /// came with. Dropped once the user types different words.
  String? _wordsFingerprint;
  List<String>? _loadedWords;

  /// An old single-file backup (package and words together) was loaded.
  bool _legacyBundle = false;

  String? _error;
  bool _busy = false;

  LprPackage? _decoded;

  @override
  void dispose() {
    _packageController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Package and words input (file, paste, typing)
  // ------------------------------------------------------------------

  /// Take a package from loaded or pasted text: a PACKAGE file, an old
  /// combined backup, or a bare (possibly wrapped) wire.
  void _applyPackageText(String text) {
    final l10n = AppLocalizations.of(context);
    final read = BackupText.read(text);
    if (read.wireCandidates.isEmpty) {
      setState(() => _error = read.pakeWords != null
          ? l10n.backupImportIsWordsError
          : l10n.backupImportNotBackupError);
      return;
    }
    setState(() {
      _packageCandidates = read.wireCandidates;
      _packageController.text = read.wireCandidates.first;
      _legacyBundle = read.isLegacyCombined;
      _error = null;
    });
    // An old combined backup carries its own words: they belong to this
    // package, so they replace any words (and fingerprint) loaded before.
    final words = read.pakeWords;
    if (words != null) _setWords(words, null);
  }

  /// Take the 8 words from loaded or pasted text: a WORDS file, an old
  /// combined backup, or a plain line of words.
  void _applyWordsText(String text) {
    final l10n = AppLocalizations.of(context);
    final read = BackupText.read(text);
    final words = read.pakeWords;
    if (words == null) {
      setState(() => _error = read.wireCandidates.isNotEmpty
          ? l10n.backupImportIsPackageError
          : l10n.backupImportNoWordsError);
      return;
    }
    _setWords(words, read.declaredFingerprint);
    if (read.isLegacyCombined) {
      setState(() => _legacyBundle = true);
      if (_packageController.text.trim().isEmpty) _applyPackageText(text);
    }
  }

  void _setWords(List<String> words, String? fingerprint) {
    setState(() {
      // Bumping _pakeResetKey makes WordInput re-run its reset, which
      // fills the slots from prefillWords so the user sees the loaded
      // words instead of empty slots.
      _pakeResetKey++;
      _pakeWords = words;
      _loadedWords = words;
      _wordsFingerprint = fingerprint;
      _error = null;
    });
  }

  Future<void> _pasteInto(void Function(String text) apply) async {
    final l10n = AppLocalizations.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      setState(() => _error = l10n.backupImportClipboardEmptyError);
      return;
    }
    apply(text);
  }

  /// Backups are a few hundred bytes of text; anything far larger is the
  /// wrong file. Checked before Dart reads it, so a picked video is never
  /// loaded into memory. (The native picker has already copied the file
  /// into the app cache by then; [_loadFromFile] clears that copy.)
  static const int _maxBackupFileBytes = 256 * 1024;

  /// The file's bytes, or null if it is larger than [_maxBackupFileBytes].
  /// Uses the size the picker already knows when available and otherwise
  /// streams, stopping as soon as the cap is passed, so an oversized file
  /// is never loaded whole.
  static Future<List<int>?> _readCapped(PlatformFile file) async {
    final known = file.lengthSync();
    if (known != null && known > _maxBackupFileBytes) return null;
    final out = <int>[];
    await for (final chunk in file.readAsByteStream()) {
      out.addAll(chunk);
      if (out.length > _maxBackupFileBytes) return null;
    }
    return out;
  }

  Future<void> _loadFromFile(void Function(String text) apply) async {
    try {
      await _loadPickedFile(apply);
    } finally {
      // The native picker copies the chosen file into the app cache before
      // Dart sees it, and never deletes it. For a backup that copy is half
      // the secret (or, for an old backup, all of it) in plaintext, so
      // remove it on every path.
      try {
        await FilePicker.clearTemporaryFiles();
      } catch (_) {
        // Best effort: the OS clears the cache eventually.
      }
    }
  }

  Future<void> _loadPickedFile(void Function(String text) apply) async {
    final String contents;
    try {
      // Single file: pickFiles() allows multi-select by default since
      // file_picker 12. Any type: Android's picker is flaky about .txt
      // filtering.
      final file = await FilePicker.pickFile(type: FileType.any);
      if (!mounted || file == null) return;
      final bytes = await _readCapped(file);
      if (!mounted) return;
      if (bytes == null) {
        setState(() => _error =
            AppLocalizations.of(context).backupImportFileTooLargeError);
        return;
      }
      contents = decodeBackupText(bytes);
    } catch (_) {
      if (!mounted) return;
      // No exception text: it can contain cache paths and is not for users.
      setState(() =>
          _error = AppLocalizations.of(context).backupImportFileReadError);
      return;
    }
    apply(contents);
  }

  // ------------------------------------------------------------------
  // Unlock
  // ------------------------------------------------------------------

  /// The package wires to try, longest join first. Reuses the candidates
  /// from the last load or paste while the field still shows them;
  /// otherwise parses whatever the user typed or pasted into the field.
  List<String> _currentCandidates(String fieldText) {
    final loaded = _packageCandidates;
    if (loaded.isNotEmpty && fieldText == loaded.first) return loaded;
    return BackupText.read(fieldText).wireCandidates;
  }

  /// Decrypt with each candidate in turn. If none works, rethrows the
  /// error from the first (longest, most likely) candidate.
  static Future<T> _decodeFirst<T>(
    List<String> candidates,
    Future<T> Function(String wire) decode,
  ) async {
    Object? firstError;
    StackTrace? firstStack;
    for (final wire in candidates) {
      try {
        return await decode(wire);
      } on InvalidPakeException catch (e, st) {
        firstError ??= e;
        firstStack ??= st;
      } on InvalidPackageException catch (e, st) {
        firstError ??= e;
        firstStack ??= st;
      }
    }
    Error.throwWithStackTrace(firstError!, firstStack!);
  }

  Future<void> _handleUnlock() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final fieldText = _packageController.text.trim();
    if (fieldText.isEmpty) {
      setState(() => _error = l10n.backupImportPasteEmptyError);
      return;
    }
    var candidates = _currentCandidates(fieldText);
    if (candidates.isEmpty) {
      setState(() => _error = BackupText.read(fieldText).pakeWords != null
          ? l10n.backupImportIsWordsError
          : l10n.backupImportNotBackupError);
      return;
    }
    if (_pakeWords.length != 8) {
      setState(() => _error = l10n.backupImportWordsIncompleteError);
      return;
    }

    // Match the words file to the package before decrypting, so a mix-up
    // between two backups says so instead of "wrong words". The package
    // fingerprint is always recomputed, never read from a header.
    final wordsFingerprint = _wordsFingerprint;
    if (wordsFingerprint != null) {
      final fingerprints = <String?>[
        for (final c in candidates) await BackupFiles.fingerprint(c),
      ];
      if (!mounted) return;
      final matching = <String>[
        for (var i = 0; i < candidates.length; i++)
          if (fingerprints[i] == wordsFingerprint) candidates[i],
      ];
      final packageFingerprint =
          fingerprints.firstWhere((f) => f != null, orElse: () => null);
      if (matching.isEmpty && packageFingerprint != null) {
        setState(() {
          _error = l10n.backupImportFingerprintMismatchError(
              packageFingerprint, wordsFingerprint);
          // Clear the wrong words so the right ones can be typed or loaded
          // in their place.
          _pakeWords = const <String>[];
          _loadedWords = null;
          _wordsFingerprint = null;
          _pakeResetKey++;
        });
        return;
      }
      if (matching.isNotEmpty) candidates = matching;
    }

    // Payload-type dispatch — branch between single-relationship (LPR) and
    // bulk (BLK) restores before attempting decryption. Reject LDP (pairing
    // invitations are not backups) and any unknown / malformed wire with
    // a user-facing error. Candidates differ only in how many wrapped
    // lines were joined, so they share the header; a join that took in a
    // line too many may not parse at all and is dropped here.
    TransportPayloadType? payloadType;
    final parseable = <String>[];
    try {
      for (final c in candidates) {
        final type = TransportPackage.peekPayloadType(c);
        if (type == null) continue;
        payloadType ??= type;
        parseable.add(c);
      }
    } on UnsupportedPackageVersionException catch (e) {
      setState(() => _error = packageErrorText(e, l10n));
      return;
    }
    candidates = parseable;
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
        final decoded = await _decodeFirst(
          candidates,
          (wire) => TransportPackage.decodeBlk(wire, pakeWords: _pakeWords),
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
          _error = packageErrorText(e, AppLocalizations.of(context));
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
      final decoded = await _decodeFirst(
        candidates,
        (wire) => TransportPackage.decodeLpr(wire, pakeWords: _pakeWords),
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
        _error = packageErrorText(e, AppLocalizations.of(context));
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
    final muted = TextStyle(
      fontSize: 13,
      color: scheme.onSurfaceVariant,
      height: 1.4,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeader(l10n.backupImportPackageHeader),
        const SizedBox(height: 6),
        Text(l10n.backupImportPasteInstruction, style: muted),
        const SizedBox(height: 10),
        TextField(
          controller: _packageController,
          minLines: 3,
          maxLines: 5,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: const InputDecoration(hintText: 'signet:tp1:...'),
        ),
        Wrap(
          alignment: WrapAlignment.end,
          children: <Widget>[
            TextButton.icon(
              onPressed: () => _pasteInto(_applyPackageText),
              icon: const Icon(Icons.content_paste),
              label: Text(l10n.commonPasteFromClipboard),
            ),
            TextButton.icon(
              onPressed: () => _loadFromFile(_applyPackageText),
              icon: const Icon(Icons.folder_open),
              label: Text(l10n.backupImportLoadPackageFile),
            ),
          ],
        ),
        if (_legacyBundle) ...<Widget>[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                border:
                    Border(left: BorderSide(color: scheme.secondary, width: 4)),
              ),
              child: Text(
                l10n.backupImportLegacyNotice,
                style: TextStyle(color: scheme.onSurface, height: 1.4),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _SectionHeader(l10n.backupImportWordsHeader),
        const SizedBox(height: 6),
        Text(l10n.backupImportWordsInstruction, style: muted),
        const SizedBox(height: 12),
        WordInput(
          wordCount: 8,
          autofocus: false,
          resetKey: _pakeResetKey,
          prefillWords: _pakeWords.length == 8 ? _pakeWords : null,
          onSubmit: (words) async {
            setState(() {
              _pakeWords = words;
              // A loaded file's fingerprint only describes the words it
              // came with.
              if (!listEquals(words, _loadedWords)) _wordsFingerprint = null;
            });
          },
        ),
        Wrap(
          alignment: WrapAlignment.end,
          children: <Widget>[
            TextButton.icon(
              onPressed: () => _pasteInto(_applyWordsText),
              icon: const Icon(Icons.content_paste),
              label: Text(l10n.commonPasteFromClipboard),
            ),
            TextButton.icon(
              onPressed: () => _loadFromFile(_applyWordsText),
              icon: const Icon(Icons.folder_open),
              label: Text(l10n.backupImportLoadWordsFile),
            ),
          ],
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
        // Informational, not an alarm: the secret is intact. A live region
        // so TalkBack announces it when the commit pane appears.
        for (final notice in <String>[
          if (decoded.labelRepaired) l10n.backupImportRepairedLabelNotice,
          if (decoded.pairedAtRepaired) l10n.backupImportRepairedDateNotice,
          if (_legacyBundle) l10n.backupImportLegacyNotice,
        ]) ...<Widget>[
          Semantics(
            liveRegion: true,
            child: Text(
              notice,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ),
          const SizedBox(height: 10),
        ],
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
