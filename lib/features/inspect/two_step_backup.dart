import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/crypto/backup_bundle.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/secure_clipboard.dart';
import '../../shared/share_text_file.dart';

/// The two-step backup save used by the single and bulk export screens
/// (plan Phase 2, bug S1): the encrypted package and its 8 words are saved
/// separately and never travel together.
///
/// Step 1 saves the package (file, copy, or the QR). Step 2 then reveals
/// the words, with paper as the main option and a separate WORDS file as
/// the fallback. The words are never offered on the clipboard. Leaving the
/// screen sweeps the files handed to the share sheet.
class TwoStepBackupSaver extends StatefulWidget {
  const TwoStepBackupSaver({
    super.key,
    required this.wire,
    required this.pakeWords,
    required this.fingerprint,
    required this.generatedAt,
    required this.onDone,
    this.showQr = true,
    @visibleForTesting this.shareFile = shareTextFile,
    @visibleForTesting this.sweep = sweepSharedExports,
  });

  /// Writes a file and opens the share sheet; false if the user backed
  /// out. Replaced in widget tests.
  final Future<bool> Function({required String fileName, required String text})
      shareFile;

  /// Deletes shared files on dispose; replaced in widget tests.
  final Future<void> Function() sweep;

  /// False for bulk backups: a package with many relationships is too
  /// large for a scannable QR code.
  final bool showQr;

  final String wire;
  final List<String> pakeWords;

  /// Six-digit fingerprint ("123 456") shared by both files.
  final String fingerprint;
  final DateTime generatedAt;

  /// Called by the final button once both steps are done.
  final VoidCallback onDone;

  @override
  State<TwoStepBackupSaver> createState() => _TwoStepBackupSaverState();
}

class _TwoStepBackupSaverState extends State<TwoStepBackupSaver> {
  bool _packageSaved = false;
  bool _wordsSaved = false;

  /// A share sheet is open. Both save buttons wait for it: share_plus
  /// rejects a second share while one is in progress.
  bool _sharing = false;

  @override
  void dispose() {
    // The WORDS file is plaintext and the package file is half the secret:
    // nothing handed to the share sheet may outlive this screen.
    widget.sweep();
    super.dispose();
  }

  Future<void> _savePackageFile() async {
    final ok = await _share(
      fileName: BackupFiles.packageFileName(
          widget.generatedAt, widget.fingerprint),
      text: BackupFiles.formatPackage(
        wire: widget.wire,
        fingerprint: widget.fingerprint,
        generatedAt: widget.generatedAt,
      ),
    );
    if (ok && mounted) setState(() => _packageSaved = true);
  }

  /// Share one file. Backing out of the share sheet, or a failure (full
  /// disk, no share target), leaves the step undone, so the user never
  /// believes a file was saved when it was not. Failures are reported.
  Future<bool> _share({required String fileName, required String text}) async {
    if (_sharing) return false;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _sharing = true);
    try {
      return await widget.shareFile(fileName: fileName, text: text);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupShareFailed)));
      return false;
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// Copying is not saving: the clipboard is overwritten by the next copy.
  /// The user confirms with "I saved it another way" once it is pasted
  /// somewhere.
  Future<void> _copyPackage(AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await SecureClipboard.copy(widget.wire);
    messenger.showSnackBar(SnackBar(
      content: Text(switch (result) {
        SecureCopyResult.protected =>
          l10n.backupPackageCopiedSnackbar(l10n.commonCopiedProtected),
        SecureCopyResult.plain =>
          l10n.backupPackageCopiedSnackbar(l10n.commonCopiedPlain),
        SecureCopyResult.failed => l10n.commonCopyFailed,
      }),
      duration: const Duration(seconds: 6),
    ));
  }

  Future<void> _saveWordsFile() async {
    final ok = await _share(
      fileName:
          BackupFiles.wordsFileName(widget.generatedAt, widget.fingerprint),
      text: BackupFiles.formatWords(
        pakeWords: widget.pakeWords,
        fingerprint: widget.fingerprint,
        generatedAt: widget.generatedAt,
      ),
    );
    if (ok && mounted) setState(() => _wordsSaved = true);
  }

  @override
  Widget build(BuildContext context) {
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
        // ---------------------------------------------------------- step 1
        _StepHeader(
          label: l10n.backupStep1Header,
          done: _packageSaved,
          doneLabel: l10n.backupStepDone,
        ),
        const SizedBox(height: 6),
        Text(
          widget.showQr ? l10n.backupStep1Body : l10n.backupStep1BodyNoQr,
          style: muted,
        ),
        const SizedBox(height: 14),
        if (widget.showQr) ...<Widget>[
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: QrImageView(
                data: widget.wire,
                size: 240,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(8),
                gapless: true,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          color: scheme.surfaceContainerHighest,
          child: SelectableText(
            widget.wire,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        const SizedBox(height: 6),
        Text(l10n.backupFingerprintLine(widget.fingerprint), style: muted),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _sharing ? null : _savePackageFile,
          icon: const Icon(Icons.save_alt),
          label: Text(l10n.backupSavePackageFile),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.end,
          children: <Widget>[
            TextButton.icon(
              onPressed: () => _copyPackage(l10n),
              icon: const Icon(Icons.copy),
              label: Text(l10n.commonCopyPackage),
            ),
            TextButton(
              onPressed: () => setState(() => _packageSaved = true),
              child: Text(l10n.backupSavedAnotherWay),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // ---------------------------------------------------------- step 2
        _StepHeader(
          label: l10n.backupStep2Header,
          done: _wordsSaved,
          doneLabel: l10n.backupStepDone,
        ),
        const SizedBox(height: 6),
        if (!_packageSaved)
          Text(l10n.backupStep2Locked, style: muted)
        else ...<Widget>[
          Text(l10n.backupStep2Body, style: muted),
          const SizedBox(height: 10),
          _WordsList(words: widget.pakeWords),
          const SizedBox(height: 6),
          Text(l10n.backupFingerprintLine(widget.fingerprint), style: muted),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => setState(() => _wordsSaved = true),
            icon: const Icon(Icons.edit_note),
            label: Text(l10n.backupWroteOnPaper),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _sharing ? null : _saveWordsFile,
            icon: const Icon(Icons.save_alt),
            label: Text(l10n.backupSaveWordsFile),
          ),
          const SizedBox(height: 4),
          Text(l10n.backupWordsFileWarning, style: muted),
        ],
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _packageSaved && _wordsSaved ? widget.onDone : null,
          child: Text(l10n.backupSavedBoth),
        ),
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.label,
    required this.done,
    required this.doneLabel,
  });

  final String label;
  final bool done;
  final String doneLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      header: true,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
          if (done)
            Text(
              doneLabel,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _WordsList extends StatelessWidget {
  const _WordsList({required this.words});
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      color: scheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < words.length; i++)
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
                      words[i],
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
    );
  }
}
