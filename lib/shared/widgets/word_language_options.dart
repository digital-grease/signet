import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/wordlists.dart';
import '../../core/prefs/settings_controller.dart';
import '../../l10n/app_localizations.dart';
import '../word_semantics.dart';

/// One radio option per shipped word list: the language's own name and
/// three sample words, so a person recognises their language by sight
/// whatever the UI language. Used by the first-run picker and Settings.
///
/// zh-1 is offered twice, 中文（普通话） in simplified and 中文（國語） in
/// traditional characters: the same list, so choosing one also sets the
/// phone's script (plan Tasks 3.3 and 3.5). Both are marked 测试版 / 測試版
/// (beta) in v0.5.0: no native speaker has checked the list (spike
/// chinese-words.md decision 7; FAQ "Why are Chinese words marked beta?").
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
          for (final traditional in list.hasScripts
              ? const <bool?>[false, true]
              : const <bool?>[null])
            _Option(
              list: list,
              traditional: traditional,
              selected: list == selected &&
                  (traditional == null ||
                      traditional == WordList.showTraditionalChinese),
              onTap: () {
                if (traditional != null) {
                  ProviderScope.containerOf(context, listen: false)
                      .read(zhTraditionalProvider.notifier)
                      .set(traditional);
                }
                onChanged(list);
              },
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
    this.traditional,
  });

  final WordList list;

  /// The script this option shows, for a list with two; null otherwise.
  final bool? traditional;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final script = traditional ?? WordList.showTraditionalChinese;
    final endonym = list.endonymIn(traditional: script);
    final beta = list == WordList.zh1 ? (script ? '測試版' : '测试版') : null;
    final samples = list.renderIn(WordLanguageOptions._sampleIndices,
        traditional: script);
    final sample = samples.join(' · ');
    // Drawn with radio icons, so tell TalkBack it is a radio group and
    // which option is selected.
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      // The name and the samples in their own language's voice.
      attributedLabel: attributedWords(
        AppLocalizations.of(context).wordLanguageSampleSemantics(
            beta == null ? endonym : '$endonym $beta', sample),
        list,
        words: <String>[
          endonym,
          ?beta,
          ...samples,
        ],
      ),
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
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          endonym,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (beta != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              border: Border.all(color: scheme.outline),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              beta,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                      ],
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
