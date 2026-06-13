import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/logging/crash_report_url_builder.dart';

/// Bottom sheet offering the three export destinations for a scrubbed debug
/// log: a pre-filled GitHub issue, the OS share sheet, or the clipboard.
///
/// The [scrubbedLog] passed in has ALREADY been through
/// `DebugLogExportScrubber` — secrets removed, contacts replaced with
/// `<peer-N>` tags. This widget only moves that text off-device.
Future<void> showDebugLogExportSheet(
  BuildContext context, {
  required String scrubbedLog,
  required String device,
  required String osVersion,
  required String appVersion,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _LogExportSheet(
      scrubbedLog: scrubbedLog,
      device: device,
      osVersion: osVersion,
      appVersion: appVersion,
    ),
  );
}

class _LogExportSheet extends StatelessWidget {
  const _LogExportSheet({
    required this.scrubbedLog,
    required this.device,
    required this.osVersion,
    required this.appVersion,
  });

  final String scrubbedLog;
  final String device;
  final String osVersion;
  final String appVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'EXPORT DEBUG LOG',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                letterSpacing: 2.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Secrets are removed and your contacts are shown as tags like '
              '<peer-1>. The log still describes app behavior, so review it '
              'before sharing. If you file a GitHub issue, don\'t type a '
              'contact\'s name in the description box — that box is not scrubbed.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('FILE A GITHUB ISSUE'),
              onPressed: () => _fileIssue(context),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.ios_share),
              label: const Text('SHARE…'),
              onPressed: () => _share(context),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('COPY TO CLIPBOARD'),
              onPressed: () => _copy(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fileIssue(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final result = CrashReportUrlBuilder.buildDebugLog(
      device: device,
      osVersion: osVersion,
      appVersion: appVersion,
      log: scrubbedLog,
    );
    // On overflow the URL carries only the head; drop the full log onto the
    // clipboard so the user can paste it below the truncation marker.
    if (result is CrashReportUrlTruncated) {
      await Clipboard.setData(ClipboardData(text: result.fullTrace));
    }
    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse(result.url),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      launched = false;
    }
    if (!launched) {
      await Clipboard.setData(ClipboardData(text: scrubbedLog));
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t open the browser — log copied instead.'),
        ),
      );
    }
    navigator.pop();
  }

  Future<void> _share(BuildContext context) async {
    final navigator = Navigator.of(context);
    await SharePlus.instance.share(
      ShareParams(text: scrubbedLog, subject: 'Signet debug log'),
    );
    navigator.pop();
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    await Clipboard.setData(ClipboardData(text: scrubbedLog));
    messenger?.showSnackBar(
      const SnackBar(content: Text('Debug log copied to clipboard.')),
    );
    navigator.pop();
  }
}
