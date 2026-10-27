import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Shown instead of a contact's words when its word language is one this
/// version of Signet does not have (restored from a newer Signet's
/// backup). English words in its place would fail against the real
/// contact. Never softer than ❌: it says the contact cannot be checked
/// and what to do about an urgent request meanwhile.
///
/// [damaged]: the language came from a damaged backup tag, which no update
/// fixes; the advice is to pair again.
class WordLanguageUnknownNotice extends StatelessWidget {
  const WordLanguageUnknownNotice({
    super.key,
    required this.label,
    this.damaged = false,
  });

  final String label;
  final bool damaged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.warning_amber_rounded, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              damaged
                  ? AppLocalizations.of(context).wordLanguageDamagedMessage(label)
                  : AppLocalizations.of(context).wordLanguageUnknownMessage(label),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).wordLanguageUnknownWarning(label),
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: scheme.error, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
