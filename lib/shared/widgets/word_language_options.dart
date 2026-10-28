import 'package:flutter/material.dart';

import '../../core/crypto/wordlists.dart';
import '../../l10n/app_localizations.dart';

/// One radio option per shipped word list: the language's own name and
/// three sample words, so a person recognises their language by sight
/// whatever the UI language. Used by the first-run picker and Settings.
class WordLanguageOptions extends StatelessWidget {
  const WordLanguageOptions({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// Null selects nothing (a contact whose language this version lacks).
  final WordList? selected;
  final ValueChanged<WordList> onChanged;

  /// The same three indices in every list, so the samples line up.
  static const List<int> _sampleIndices = <int>[1916, 1530, 1234];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final list in WordList.shipped)
          _Option(
            list: list,
            selected: list == selected,
            onTap: () => onChanged(list),
          ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.list,
    required this.selected,
    required this.onTap,
  });

  final WordList list;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sample =
        list.render(WordLanguageOptions._sampleIndices).join(' · ');
    // Drawn with radio icons, so tell TalkBack it is a radio group and
    // which option is selected.
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: AppLocalizations.of(context)
          .wordLanguageSampleSemantics(list.endonym, sample),
      // excludeSemantics drops the InkWell's own tap, so give it back here
      // for TalkBack, Switch Access and Voice Access.
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: <Widget>[
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      list.endonym,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sample,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
