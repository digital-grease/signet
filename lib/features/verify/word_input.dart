import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../core/crypto/wordlists.dart';
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
/// Languages (plan Task 8.4c): [lists] are the word lists a slot accepts.
/// Verify passes English only; the 8-word PAKE inputs pass every shipped
/// list, so French words are accepted, with or without accents. Chips come
/// from the lists that hold every word typed so far, so one French-only
/// word switches them to French. Words are reported as the matched list's
/// own spelling (accented, NFC), never as typed.
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
    this.lists = const <WordList>[],
  });

  final int wordCount;

  /// The word lists a slot accepts; empty means English only.
  final List<WordList> lists;
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

/// Per list: every proper start of a folded word ("act" for "action").
/// A typed word that is one of these, in ANY accepted list, may still be
/// on its way to a longer word: English "absurd" to French "absurde",
/// French "futur" to English "future".
final Map<String, Set<String>> _properPrefixesByList = {};

Set<String> _properPrefixesOf(WordList list) =>
    _properPrefixesByList.putIfAbsent(list.id, () => <String>{
          for (final w in _foldedOf(list))
            for (var n = 1; n < w.length; n++) w.substring(0, n),
        });

/// Folded form of every word, per list, for prefix matching.
final Map<String, List<String>> _foldedByList = {};

List<String> _foldedOf(WordList list) => _foldedByList.putIfAbsent(
      list.id,
      () => list.words.map((w) => WordList.fold(w)!).toList(),
    );

class _WordInputState extends State<WordInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late final List<bool> _confirmed;
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

  List<WordList> get _lists =>
      widget.lists.isEmpty ? <WordList>[WordList.english] : widget.lists;

  /// The lists that hold every confirmed word so far (all of [_lists] when
  /// none, or when the words mix lists). A word still being typed does not
  /// count, so "absurd" on its way to "absurde" does not hide French chips.
  List<WordList> get _activeLists {
    final lists = _lists;
    if (lists.length == 1) return lists;
    final typed = [
      for (var i = 0; i < _controllers.length; i++)
        if (_confirmed[i] && lists.any((l) => l.contains(_controllers[i].text)))
          _controllers[i].text,
    ];
    final active = [
      for (final l in lists)
        if (typed.every(l.contains)) l,
    ];
    return active.isEmpty ? lists : active;
  }

  /// [text] as the matched list spells it, or null if it is not a word of
  /// any accepted list.
  String? _canonical(String text) {
    for (final l in [..._activeLists, ..._lists]) {
      final i = l.indexOf(text);
      if (i != null) return l.wordAt(i);
    }
    return null;
  }

  bool _isWord(String text) => _canonical(text) != null;

  /// A word that is also the start of a longer word of any accepted list
  /// (not just the active ones: the next letter may switch languages).
  bool _isPrefixWord(String text) {
    final folded = WordList.fold(text);
    if (folded == null || !_isWord(text)) return false;
    return _lists.any((l) => _properPrefixesOf(l).contains(folded));
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
    if (prefix.trim().length < 2) return const <String>[];
    final folded = WordList.fold(prefix.trim());
    if (folded == null) return const <String>[];
    final hits = <String>[];
    for (final l in _activeLists) {
      final foldedWords = _foldedOf(l);
      for (var i = 0; i < foldedWords.length; i++) {
        if (foldedWords[i].startsWith(folded)) {
          hits.add(l.wordAt(i));
          if (hits.length >= 6) return hits;
        }
      }
    }
    return hits;
  }

  bool _isPrefixOfAnyWord(String text) {
    final folded = WordList.fold(text);
    if (folded == null) return false;
    return _activeLists.any((l) => _foldedOf(l).any((w) => w.startsWith(folded)));
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
    if (!parts.every(_isWord)) return false;
    for (var i = 0; i < widget.wordCount; i++) {
      _controllers[i].text = _canonical(parts[i])!;
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
    if (value.endsWith(' ') && _isWord(trimmed)) {
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
    final unambiguous = _isWord(trimmed) && !_isPrefixWord(trimmed);
    if (unambiguous) _showCanonical(index);
    setState(() => _confirmed[index] = unambiguous);
    if (unambiguous) _advanceFrom(index);
    _afterChange();
  }

  /// A chip tap or the keyboard's next/done key on a valid word confirms
  /// it, prefix word or not.
  void _confirmSlot(int index, String word) {
    if (_submitting) return;
    if (_controllers[index].text != word) _controllers[index].text = word;
    _showCanonical(index);
    setState(() => _confirmed[index] = _isWord(word));
    _advanceFrom(index);
    _afterChange();
  }

  /// A confirmed slot shows the word as its list spells it ("eleve" typed
  /// shows "élève").
  void _showCanonical(int index) {
    final controller = _controllers[index];
    final shown = _canonical(controller.text.trim());
    if (shown == null || shown == controller.text) return;
    controller.value = TextEditingValue(
      text: shown,
      selection: TextSelection.collapsed(offset: shown.length),
    );
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
    } else if (!_willAutoSubmit()) {
      _focusNodes[index].unfocus();
    }
    // Otherwise the keyboard stays up through the check and the parent's
    // reset decides: slot 1 for a retry, or unfocus. Closing it here and
    // reopening it a frame later for the retry left the body a few pixels
    // tall in Android split screen (QA 2026-10-13).
  }

  /// Whether [_afterChange] is about to hand the words to [WordInput.onSubmit].
  bool _willAutoSubmit() {
    if (widget.onSubmit == null) return false;
    final words = _collectValidWords();
    return words != null &&
        _confirmed.every((c) => c) &&
        !listEquals(words, _lastSubmitted);
  }

  List<String>? _collectValidWords() {
    final words = <String>[];
    for (final c in _controllers) {
      final w = _canonical(c.text.trim());
      if (w == null) return null;
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
    if (!_isWord(text)) return true;
    return !_confirmed[index];
  }

  Widget _slotField(BuildContext context, int index) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final controller = _controllers[index];
    final value = controller.text.trim().toLowerCase();
    final isKnown = _isWord(value);
    final looksInvalid =
        value.length >= 2 && !isKnown && !_isPrefixOfAnyWord(value);
    return Semantics(
      label: AppLocalizations.of(context)
          .wordInputSlotSemantics(index + 1, widget.wordCount),
      // No `textField: true`: that made this wrapper a separate text-field
      // node, so TalkBack focused the inner field and read only "word".
      // Without it the label merges into the field's own node.
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
          if (_isWord(word)) {
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
