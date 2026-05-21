import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/logging/crash_recorder.dart';
import '../../core/logging/crash_report_url_builder.dart';

/// Modal dialog shown on next launch after a crash is detected via
/// [CrashDetector]. Three actions:
///
///   - **File issue** — opens the pre-filled `crash_report.yml` form on
///     GitHub via `url_launcher`. If the URL exceeds the budget, the
///     full trace is copied to clipboard simultaneously so the user can
///     paste it below the embedded head.
///   - **Copy log** — puts the scrubbed trace on the clipboard alone.
///     For users who want to file via a different channel (email,
///     messenger to a friend, etc.).
///   - **Dismiss** — closes the dialog. The sentinel is always cleared
///     via [onClose] regardless of which path the user took.
///
/// The dialog is wrapped in a `Semantics(liveRegion: true)` so screen
/// readers announce its appearance over the home screen.
class CrashReportDialog extends StatelessWidget {
  const CrashReportDialog({
    super.key,
    required this.report,
    required this.onClose,
  });

  final CrashReport report;

  /// Called after the user takes any action (file / copy / dismiss).
  /// The caller is responsible for invoking
  /// `CrashDetector.dismissPendingReport()` here so the dialog doesn't
  /// re-fire on the next launch.
  final VoidCallback onClose;

  /// Convenience method: build the dialog content + show it.
  static Future<void> show(
    BuildContext context, {
    required CrashReport report,
    required VoidCallback onClose,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => CrashReportDialog(
        report: report,
        onClose: onClose,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Semantics(
        liveRegion: true,
        child: Text(
          'Signet had trouble',
          style: TextStyle(
            color: theme.colorScheme.error,
            fontFamily: 'monospace',
          ),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'The app crashed during your last session. Sending the '
              'report helps us fix what happened.',
            ),
            const SizedBox(height: 12),
            Text(
              'The report contains:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const _Bullet('Your device + OS + app version'),
            const _Bullet(
              'A stack trace, with any cryptographic material (paired '
              'secrets, verify codes, backup payloads) replaced with '
              '[redacted:N] markers before it leaves your phone.',
            ),
            const SizedBox(height: 12),
            Text(
              'Choose how to send it:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => _onDismiss(context),
          child: const Text('DISMISS'),
        ),
        TextButton(
          onPressed: () => _onCopyLog(context),
          child: const Text('COPY LOG'),
        ),
        FilledButton(
          onPressed: () => _onFileIssue(context),
          child: const Text('FILE ISSUE'),
        ),
      ],
    );
  }

  Future<void> _onDismiss(BuildContext context) async {
    Navigator.of(context).pop();
    onClose();
  }

  Future<void> _onCopyLog(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: report.scrubbedTrace));
    if (!context.mounted) return;
    Navigator.of(context).pop();
    messenger?.showSnackBar(
      const SnackBar(content: Text('Crash log copied to clipboard.')),
    );
    onClose();
  }

  Future<void> _onFileIssue(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = CrashReportUrlBuilder.build(
      device: report.device,
      osVersion: report.osVersion,
      appVersion: report.appVersion,
      trace: report.scrubbedTrace,
    );
    // If truncated, also drop the full trace onto the clipboard so the
    // user can paste below the embedded head per the dialog's instruction.
    if (result is CrashReportUrlTruncated) {
      await Clipboard.setData(ClipboardData(text: result.fullTrace));
    }
    final uri = Uri.parse(result.url);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (!launched) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the browser. The crash log has been '
            'copied to your clipboard so you can paste it manually.',
          ),
        ),
      );
      await Clipboard.setData(ClipboardData(text: report.scrubbedTrace));
    } else if (result is CrashReportUrlTruncated) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'Trace was long — the full log is on your clipboard. '
            'Paste it below the truncation marker on GitHub.',
          ),
        ),
      );
    }
    onClose();
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
