import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/signet_theme.dart';

/// About / Support screen — app metadata, external links, a support button.
///
/// Design parallels the fauxx About screen: a column of panel cards, each
/// a section (app description / license / source / privacy / support),
/// each with body copy and one optional action button. No icons, no
/// flourish — operator-theme consistent.
///
/// External links (source, privacy, BMC) open in the OS browser via
/// `url_launcher`. Signet itself has no `INTERNET` permission; the
/// browser handles the actual fetch, off-process.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _version = 'v0.2.0-alpha';
  static const String _sourceUrl = 'https://github.com/digital-grease/signet';
  static const String _privacyUrl =
      'https://github.com/digital-grease/signet/blob/main/PRIVACY.md';
  static const String _issuesUrl =
      'https://github.com/digital-grease/signet/issues';
  static const String _supportUrl = 'https://www.buymeacoffee.com/digitalgrease';

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('ABOUT')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const _Section(
                title: 'SIGNET',
                body:
                    'Cryptographic multi-factor authentication for human '
                    'relationships. Defends against voice and video deepfake '
                    'vishing via device-to-device rotating codes. '
                    'Zero server, offline-first.\n\n'
                    'Version: $_version',
              ),
              const SizedBox(height: 12),
              const _Section(
                title: 'LICENSE',
                body:
                    'AGPL-3.0-only. Signet is free software; you are free to '
                    'use, modify, and redistribute it under the terms of the '
                    'GNU Affero General Public License version 3.',
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'SOURCE',
                body: 'Source code, issue tracker, and release artifacts live '
                    'on GitHub.',
                actionLabel: 'OPEN REPOSITORY',
                onAction: () => _open(_sourceUrl),
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'PRIVACY',
                body:
                    'Signet collects nothing. It sends nothing. There is no '
                    'server, no account, no telemetry.',
                actionLabel: 'PRIVACY POLICY',
                onAction: () => _open(_privacyUrl),
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'REPORT A BUG',
                body: 'Found a problem? File an issue on GitHub. Include the '
                    'device, OS version, and the steps that triggered it.',
                actionLabel: 'OPEN ISSUES',
                onAction: () => _open(_issuesUrl),
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'SUPPORT THE PROJECT',
                body:
                    'If Signet is useful to you, consider buying me a coffee. '
                    'Signet is solo-maintained, and there is no paid tier or '
                    'upsell in the app. Support is optional and appreciated.',
                actionLabel: 'BUY ME A COFFEE',
                onAction: () => _open(_supportUrl),
                actionTone: _ActionTone.highlight,
              ),
              const SizedBox(height: 24),
              Text(
                '© digital-grease',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ActionTone { standard, highlight }

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.actionTone = _ActionTone.standard,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final _ActionTone actionTone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final panelColor = isDark ? SignetTokens.panel : SignetTokens.panelL;
    final borderColor = isDark ? SignetTokens.border : SignetTokens.borderL;

    return Container(
      decoration: BoxDecoration(
        color: panelColor,
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              letterSpacing: 2.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: actionTone == _ActionTone.highlight
                  ? FilledButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    )
                  : OutlinedButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
