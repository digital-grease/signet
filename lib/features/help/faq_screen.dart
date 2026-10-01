import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/signet_theme.dart';
import '../../l10n/app_localizations.dart';

/// FAQ — in-app answers to the questions that tend to come up during or
/// right after a pairing. Deliberately written for the "grandma test"
/// audience: no jargon, no crypto terminology unless the answer is
/// incomplete without it, one-paragraph answers where possible.
///
/// ExpansionTiles keep the screen scannable — the user sees the question
/// list first, opens only the one they want. No search box (28 questions
/// would justify one; 10 does not).
///
/// "Contact us" lives in the Home AppBar help menu, not here, so a user
/// who didn't find their answer has one obvious next step (file an issue)
/// without needing to backtrack through the FAQ.
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const String _issuesUrl =
      'https://github.com/digital-grease/signet/issues';

  static List<_FaqEntry> _entries(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return <_FaqEntry>[
      _FaqEntry(question: l10n.faqQ1, answer: l10n.faqA1),
      _FaqEntry(question: l10n.faqQ2, answer: l10n.faqA2),
      _FaqEntry(question: l10n.faqQ3, answer: l10n.faqA3),
      _FaqEntry(question: l10n.faqQ4, answer: l10n.faqA4),
      _FaqEntry(question: l10n.faqQ5, answer: l10n.faqA5),
      _FaqEntry(question: l10n.faqQ6, answer: l10n.faqA6),
      _FaqEntry(question: l10n.faqQ7, answer: l10n.faqA7),
      _FaqEntry(question: l10n.faqQ8, answer: l10n.faqA8),
      _FaqEntry(question: l10n.faqQ9, answer: l10n.faqA9),
      _FaqEntry(question: l10n.faqQ10, answer: l10n.faqA10),
      _FaqEntry(question: l10n.faqQ11, answer: l10n.faqA11),
    ];
  }

  Future<void> _openIssues() async {
    final uri = Uri.parse(_issuesUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final panelColor = isDark ? SignetTokens.panel : SignetTokens.panelL;
    final borderColor = isDark ? SignetTokens.border : SignetTokens.borderL;
    final l10n = AppLocalizations.of(context);
    final entries = _entries(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.faqTitle)),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          itemCount: entries.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            if (i == entries.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      l10n.faqStillStuckHeader,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.faqStillStuckBody,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: _openIssues,
                        child: Text(l10n.faqContactUsButton),
                      ),
                    ),
                  ],
                ),
              );
            }
            final entry = entries[i];
            return Container(
              decoration: BoxDecoration(
                color: panelColor,
                border: Border.all(color: borderColor),
              ),
              child: Theme(
                data: theme.copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  title: Text(
                    entry.question,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        entry.answer,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FaqEntry {
  const _FaqEntry({required this.question, required this.answer});

  final String question;
  final String answer;
}
