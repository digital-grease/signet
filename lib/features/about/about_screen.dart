import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/signet_theme.dart';
import '../../l10n/app_localizations.dart';

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
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  static const String _sourceUrl = 'https://github.com/digital-grease/signet';
  static const String _privacyUrl =
      'https://github.com/digital-grease/signet/blob/main/PRIVACY.md';
  static const String _issuesUrl =
      'https://github.com/digital-grease/signet/issues';
  static const String _supportUrl = 'https://www.buymeacoffee.com/digitalgrease';

  // Version is loaded asynchronously from PackageInfo so it always tracks
  // pubspec.yaml rather than drifting from a hand-bumped constant. The "…"
  // placeholder is shown for the single frame before PackageInfo resolves.
  String _version = '…';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() => _version = 'v${info.version}');
    });
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Section(
                title: l10n.aboutSectionSignet,
                body:
                    '${l10n.aboutIntroBody}\n\n'
                    '${l10n.aboutVersionLabel(_version)}',
              ),
              const SizedBox(height: 12),
              _Section(
                title: l10n.aboutSectionLicense,
                body: l10n.aboutLicenseBody,
              ),
              const SizedBox(height: 12),
              _Section(
                title: l10n.aboutSectionSource,
                body: l10n.aboutSourceBody,
                actionLabel: l10n.aboutOpenRepositoryButton,
                onAction: () => _open(_sourceUrl),
              ),
              const SizedBox(height: 12),
              _Section(
                title: l10n.aboutSectionPrivacy,
                body: l10n.aboutPrivacyBody,
                actionLabel: l10n.aboutPrivacyPolicyButton,
                onAction: () => _open(_privacyUrl),
              ),
              const SizedBox(height: 12),
              _Section(
                title: l10n.aboutSectionReportBug,
                body: l10n.aboutReportBugBody,
                actionLabel: l10n.aboutOpenIssuesButton,
                onAction: () => _open(_issuesUrl),
              ),
              const SizedBox(height: 12),
              _Section(
                title: l10n.aboutSectionSupport,
                body: l10n.aboutSupportBody,
                actionLabel: l10n.aboutBuyMeCoffeeButton,
                onAction: () => _open(_supportUrl),
                actionTone: _ActionTone.highlight,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.aboutCopyright,
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
