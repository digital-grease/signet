import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../core/crypto/bip39_english_wordlist.dart';
import '../../l10n/app_localizations.dart';

/// Multi-slot BIP-39 word input: 4 slots on the Verify screen, 8 for the
/// PAKE words on the restore and long-distance pairing screens.
///
/// Each slot shows a single-line text field. Once the user types 2+
/// characters, a horizontal row of up to 6 matching wordlist chips appears.
/// Tapping a chip commits the word and advances focus. The widget also
/// handles the "whole phrase pasted at once" case: if any field receives
/// text containing internal whitespace or hyphens and that text splits
/// into exactly [wordCount] wordlist entries, all slots are filled in
/// one stroke.
///
/// Confirmation (plan Task 3.3): 49 wordlist words are also the start of
/// longer ones ("act" / "action", "car" / "carbon"). A slot counts as
/// confirmed when it holds a word that cannot be the start of another, or
/// when the user picked it from a chip, pressed the keyboard's next/done
/// key on it, pasted it, or it was prefilled. A typed prefix word stays
/// unconfirmed and keeps its chips (the word itself first), so typing
/// "act" on the way to "action" never fires a check.
///
/// Two ways out:
/// - [onSubmit] (Verify): fired automatically after any edit that leaves
///   every slot valid and confirmed, or by the large [submitLabel] button
///   as soon as every slot is valid. The parent bumps [resetKey] after
///   each result to clear the slots.
/// - [onWordsChanged] (PAKE words): reports the current valid words, or
///   null, after every edit, so the parent always unlocks with what is on
///   screen.
class WordInput extends StatefulWidget {
  const WordInput({
    super.key,
    this.onSubmit,
    this.onWordsChanged,
    this.submitLabel,
    this.wordCount = 4,
    this.enabled = true,
    this.resetKey = 0,
    this.autofocus = true,
    this.prefillWords,
    this.onTypingChanged,
    this.focusOnReset = true,
  });

  final int wordCount;
  final Future<void> Function(List<String> words)? onSubmit;

  /// Called after every edit with the words when every slot holds a valid
  /// word, otherwise null.
  final ValueChanged<List<String>?>? onWordsChanged;

  /// Label of the submit button, shown when non-null and [onSubmit] is set.
  final String? submitLabel;
  final bool enabled;

  /// Incrementing this integer resets the slots and refocuses the first.
  /// Lets the parent drive "try again" flow without reaching into our state.
  final int resetKey;
  final bool autofocus;

  /// Optional pre-populated values for the slots. When non-null and its
  /// length matches [wordCount], the slots render these values on first
  /// build and on every [resetKey] bump. Used by the "Load from file"
  /// path on the backup-import screen so users see the PAKE words
  /// that came out of the file instead of empty slots.
  final List<String>? prefillWords;

  /// Called with true when the first character goes into an empty input,
  /// and with false when every slot is empty again. Video-mode verify
  /// freezes its WATCH FOR gesture while the user types.
  final ValueChanged<bool>? onTypingChanged;

  /// Whether a [resetKey] bump puts the cursor back in the first slot.
  /// False dismisses the keyboard instead: on Verify, after a pass, or
  /// while the gesture question is open, a keyboard would cover it.
  final bool focusOnReset;

  @override
  State<WordInput> createState() => _WordInputState();
}

/// Wordlist words that are also the start of a longer wordlist word.
final Set<String> _prefixWords = () {
  final words = bip39EnglishWordlist.toSet();
  return <String>{
    for (final w in bip39EnglishWordlist)
      for (var n = 3; n < w.length; n++)
        if (words.contains(w.substring(0, n))) w.substring(0, n),
  };
}();

class _WordInputState extends State<WordInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late final List<bool> _confirmed;
  late final Set<String> _wordSet;
  bool _submitting = false;
  bool _typing = false;

  /// The words last handed to [WordInput.onSubmit] since the last reset,
  /// so an edit that changes nothing does not check the same words twice.
  List<String>? _lastSubmitted;

  @override
  void initState() {
    super.initState();
    _controllers = List<TextEditingController>.generate(
      widget.wordCount,
      (_) => TextEditingController(),
    );
    _focusNodes = List<FocusNode>.generate(
      widget.wordCount,
      (_) => FocusNode(),
    );
    _confirmed = List<bool>.filled(widget.wordCount, false);
    _wordSet = bip39EnglishWordlist.toSet();
    final didPrefill = _applyPrefill();
    // Don't steal focus into slot 0 when the slots are already populated;
    // the user's next action is a button tap (UNLOCK), not more typing.
    if (widget.autofocus && !didPrefill) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.enabled) {
          _focusNodes[0].requestFocus();
        }
      });
    }
    if (didPrefill) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _afterChange();
      });
    }
  }

  @override
  void didUpdateWidget(WordInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetKey != widget.resetKey) {
      _reset();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  /// [fromParent]: a [WordInput.resetKey] bump, which re-applies
  /// [WordInput.prefillWords]. The Clear all button empties the slots.
  void _reset({bool fromParent = true}) {
    setState(() {
      for (final c in _controllers) {
        c.clear();
      }
      _confirmed.fillRange(0, _confirmed.length, false);
      _submitting = false;
      _lastSubmitted = null;
    });
    final didPrefill = fromParent && _applyPrefill();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // After the frame: _reset runs inside didUpdateWidget, where the
      // parent cannot setState.
      _afterChange();
      if (didPrefill) return;
      if (widget.focusOnReset) {
        _focusNodes[0].requestFocus();
      } else {
        for (final node in _focusNodes) {
          node.unfocus();
        }
      }
    });
  }

  /// Populate controllers from [WordInput.prefillWords] when provided and
  /// its length matches [wordCount]. Returns `true` when prefill took
  /// effect so callers can skip the autofocus/focus-first-slot handoff.
  bool _applyPrefill() {
    final prefill = widget.prefillWords;
    if (prefill == null || prefill.length != widget.wordCount) return false;
    for (var i = 0; i < widget.wordCount; i++) {
      _controllers[i].text = prefill[i];
      _confirmed[i] = true;
    }
    return true;
  }

  List<String> _matchesFor(String prefix) {
    if (prefix.length < 2) return const <String>[];
    final lower = prefix.toLowerCase();
    final hits = <String>[];
    for (final w in bip39EnglishWordlist) {
      if (w.startsWith(lower)) {
        hits.add(w);
        if (hits.length >= 6) break;
      }
    }
    return hits;
  }

  bool _looksLikePaste(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    return RegExp(r'[\s\-]').hasMatch(trimmed);
  }

  bool _tryDistributePaste(String pasted) {
    final parts = pasted
        .toLowerCase()
        .split(RegExp(r'[\s\-]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length != widget.wordCount) return false;
    if (!parts.every(_wordSet.contains)) return false;
    for (var i = 0; i < widget.wordCount; i++) {
      _controllers[i].text = parts[i];
      _confirmed[i] = true;
    }
    _focusNodes[widget.wordCount - 1].unfocus();
    return true;
  }

  void _onSlotChanged(int index, String value) {
    if (_submitting) return;
    if (_looksLikePaste(value) && _tryDistributePaste(value)) {
      setState(() {});
      _afterChange();
      return;
    }
    final trimmed = value.trim().toLowerCase();
    // A space typed after a real word means "done with this word", like
    // the keyboard's next key: it confirms even a prefix word ("act ").
    if (value.endsWith(' ') && _wordSet.contains(trimmed)) {
      _controllers[index].value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
      _confirmSlot(index, trimmed);
      return;
    }
    if (trimmed != value) {
      _controllers[index].value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    }
    // A complete word that cannot be the start of a longer one is
    // unambiguous: confirm it and move on.
    final unambiguous =
        _wordSet.contains(trimmed) && !_prefixWords.contains(trimmed);
    setState(() => _confirmed[index] = unambiguous);
    if (unambiguous) _advanceFrom(index);
    _afterChange();
  }

  /// A chip tap or the keyboard's next/done key on a valid word confirms
  /// it, prefix word or not.
  void _confirmSlot(int index, String word) {
    if (_submitting) return;
    if (_controllers[index].text != word) _controllers[index].text = word;
    setState(() => _confirmed[index] = _wordSet.contains(word));
    _advanceFrom(index);
    _afterChange();
  }

  void _clearSlot(int index) {
    _controllers[index].clear();
    setState(() => _confirmed[index] = false);
    _focusNodes[index].requestFocus();
    _afterChange();
  }

  void _advanceFrom(int index) {
    if (index + 1 < widget.wordCount) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
    }
  }

  List<String>? _collectValidWords() {
    final words = <String>[];
    for (final c in _controllers) {
      final w = c.text.trim().toLowerCase();
      if (!_wordSet.contains(w)) return null;
      words.add(w);
    }
    return words;
  }

  /// Runs after every edit: report state to the parent and auto-submit when
  /// every slot holds a confirmed word that has not been checked yet.
  void _afterChange() {
    final typing = _controllers.any((c) => c.text.isNotEmpty);
    if (typing != _typing) {
      _typing = typing;
      widget.onTypingChanged?.call(typing);
    }
    final words = _collectValidWords();
    widget.onWordsChanged?.call(words);
    if (words != null &&
        _confirmed.every((c) => c) &&
        !listEquals(words, _lastSubmitted)) {
      unawaited(_submit(words));
    }
  }

  Future<void> _submit(List<String> words) async {
    final onSubmit = widget.onSubmit;
    if (onSubmit == null || _submitting) return;
    _lastSubmitted = words;
    setState(() => _submitting = true);
    try {
      await onSubmit(words);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final words = _collectValidWords();
    final submitLabel = widget.submitLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < widget.wordCount; i++) ...<Widget>[
          _slotField(context, i),
          if (_showsChips(i))
            _suggestionRow(i, _matchesFor(_controllers[i].text)),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _submitting || !widget.enabled
                ? null
                : () => _reset(fromParent: false),
            icon: const Icon(Icons.clear),
            label: Text(l10n.wordInputClearAllButton),
          ),
        ),
        if (submitLabel != null && widget.onSubmit != null) ...<Widget>[
          const SizedBox(height: 4),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            onPressed: words == null || _submitting || !widget.enabled
                ? null
                : () => unawaited(_submit(words)),
            child: Text(submitLabel),
          ),
        ],
        if (_submitting)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                l10n.wordInputChecking,
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Chips show while a slot holds 2+ characters that are not yet a
  /// confirmed word: a partial word, or a prefix word such as "act".
  bool _showsChips(int index) {
    final text = _controllers[index].text.trim().toLowerCase();
    if (text.length < 2) return false;
    if (!_wordSet.contains(text)) return true;
    return !_confirmed[index];
  }

  Widget _slotField(BuildContext context, int index) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final controller = _controllers[index];
    final value = controller.text.trim().toLowerCase();
    final isKnown = _wordSet.contains(value);
    final looksInvalid = value.length >= 2 && !isKnown &&
        !bip39EnglishWordlist.any((w) => w.startsWith(value));
    return Semantics(
      label: AppLocalizations.of(context)
          .wordInputSlotSemantics(index + 1, widget.wordCount),
      textField: true,
      child: TextField(
        controller: controller,
        focusNode: _focusNodes[index],
        enabled: widget.enabled && !_submitting,
        textInputAction: index + 1 < widget.wordCount
            ? TextInputAction.next
            : TextInputAction.done,
        keyboardType: TextInputType.text,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.none,
        style: textTheme.titleLarge?.copyWith(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          prefixText: '${index + 1}.  ',
          prefixStyle: textTheme.titleMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
          hintText: AppLocalizations.of(context).wordInputHint,
          border: const OutlineInputBorder(),
          errorText: looksInvalid
              ? AppLocalizations.of(context).wordInputInvalidWordError
              : null,
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: AppLocalizations.of(context).wordInputClearTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: () => _clearSlot(index),
                ),
        ),
        onChanged: (v) => _onSlotChanged(index, v),
        onSubmitted: (v) {
          final word = v.trim().toLowerCase();
          if (_wordSet.contains(word)) {
            _confirmSlot(index, word);
          } else {
            _advanceFrom(index);
          }
        },
      ),
    );
  }

  Widget _suggestionRow(int slot, List<String> matches) {
    if (matches.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (final w in matches)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(w),
                  onPressed: () => _confirmSlot(slot, w),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
