import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/crypto/wordlists.dart';
import '../../l10n/app_localizations.dart';
import '../word_semantics.dart';
import 'word_language_options.dart';

/// "Words: Français" with a CHANGE button, on the pairing and confirm
/// screens (v0.5.0 plan Task 1.5). Preselected, so keeping the language is
/// zero taps; CHANGE opens the list of languages in a sheet.
class WordLanguageRow extends StatelessWidget {
  const WordLanguageRow({
    super.key,
    required this.selected,
    required this.onChanged,
    this.hint,
    this.note,
    this.compact = false,
  });

  /// A single line with no frame, for the header of a phrase box where
  /// every pixel keeps the confirm button on screen. Ignores [hint].
  final bool compact;

  final WordList selected;

  /// Null shows the row without the CHANGE button.
  final ValueChanged<WordList>? onChanged;

  /// What the choice means here, under the label. Null for the compact
  /// row on a screen whose own instructions say it.
  final String? hint;

  /// An extra line, such as the other phone's choice.
  final String? note;

  Future<void> _change(BuildContext context) async {
    final picked = await showModalBottomSheet<WordList>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  AppLocalizations.of(sheet).wordLanguageTitle,
                  style: Theme.of(sheet).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 8),
              WordLanguageOptions(
                selected: selected,
                onChanged: (list) => Navigator.of(sheet).pop(list),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    // Also for the same list: picking the other zh-1 script changes how
    // the words are written, so the screen must redraw.
    onChanged?.call(picked);
    // The words on screen just changed language: say so.
    unawaited(SemanticsService.sendAnnouncement(
      View.of(context),
      AppLocalizations.of(context).wordLanguageRowLabel(picked.endonym),
      Directionality.of(context),
    ));
  }

  /// "Words: Français", with the language's name read in its own voice.
  Widget _label(BuildContext context, TextStyle? style) {
    final text =
        AppLocalizations.of(context).wordLanguageRowLabel(selected.endonym);
    return Semantics(
      attributedLabel:
          attributedWords(text, selected, words: <String>[selected.endonym]),
      excludeSemantics: true,
      child: Text(text, style: style?.copyWith(fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _label(context, Theme.of(context).textTheme.titleMedium),
        if (hint != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            hint!,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
        if (note != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            note!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ],
    );
    final change = onChanged == null
        ? null
        : Semantics(
            label: l10n.wordLanguageRowChangeSemantics,
            button: true,
            excludeSemantics: true,
            onTap: () => _change(context),
            child: TextButton(
              onPressed: () => _change(context),
              child: Text(l10n.wordLanguageRowChange),
            ),
          );
    // CHANGE beside the label at normal text, so the row stays short and
    // the confirm button stays on screen; under it at large text, where
    // side by side left the label a few letters wide.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    if (compact) {
      final label = _label(context, Theme.of(context).textTheme.titleSmall);
      return stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                label,
                if (change != null)
                  Align(alignment: AlignmentDirectional.centerEnd, child: change),
              ],
            )
          : Row(children: <Widget>[Expanded(child: label), ?change]);
    }
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, stacked ? 12 : 4, stacked ? 4 : 8),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                text,
                if (change != null)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: change,
                  )
                else
                  const SizedBox(height: 4),
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(child: text),
                ?change,
              ],
            ),
    );
  }
}
