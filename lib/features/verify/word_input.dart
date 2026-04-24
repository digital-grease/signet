import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/crypto/bip39_english_wordlist.dart';

/// 4-slot BIP-39 word input used on the Verify screen.
///
/// Each slot shows a single-line text field. Once the user types 2+
/// characters, a horizontal row of up to 6 matching wordlist chips appears.
/// Tapping a chip commits the word and advances focus. The widget also
/// handles the "whole phrase pasted at once" case: if any field receives
/// text containing internal whitespace or hyphens and that text splits
/// into exactly [wordCount] wordlist entries, all slots are filled in
/// one stroke.
///
/// When all [wordCount] slots hold valid wordlist entries the widget fires
/// [onSubmit] exactly once. The parent decides what "once" means; after an
/// async result comes back, it can either leave the filled entries in place
/// (on ✅) or bump [resetKey] to clear every slot and refocus slot 0 (on ❌).
class WordInput extends StatefulWidget {
  const WordInput({
    super.key,
    required this.onSubmit,
    this.wordCount = 4,
    this.enabled = true,
    this.resetKey = 0,
    this.autofocus = true,
    this.prefillWords,
  });

  final int wordCount;
  final Future<void> Function(List<String> words) onSubmit;
  final bool enabled;

  /// Incrementing this integer resets the slots and refocuses the first.
  /// Lets the parent drive "try again" flow without reaching into our state.
  final int resetKey;
  final bool autofocus;

  /// Optional pre-populated values for the slots. When non-null and its
  /// length matches [wordCount], the slots render these values on first
  /// build and on every [resetKey] bump. Used by the "Load from file"
  /// path on the backup-import screen so users see the PAKE words
  /// that came out of the bundle instead of empty slots with silently
  /// cached state behind them.
  final List<String>? prefillWords;

  @override
  State<WordInput> createState() => _WordInputState();
}

class _WordInputState extends State<WordInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late final Set<String> _wordSet;
  bool _submitting = false;
  int? _lastSubmittedOnResetKey;

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
        if (mounted) unawaited(_maybeSubmit());
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

  void _reset() {
    setState(() {
      for (final c in _controllers) {
        c.clear();
      }
      _submitting = false;
    });
    final didPrefill = _applyPrefill();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (didPrefill) {
        unawaited(_maybeSubmit());
      } else {
        _focusNodes[0].requestFocus();
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

  bool _tryDistributePaste(int slotIndex, String pasted) {
    final parts = pasted
        .toLowerCase()
        .split(RegExp(r'[\s\-]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length != widget.wordCount) return false;
    if (!parts.every(_wordSet.contains)) return false;
    for (var i = 0; i < widget.wordCount; i++) {
      _controllers[i].text = parts[i];
    }
    _focusNodes[widget.wordCount - 1].unfocus();
    _maybeSubmit();
    return true;
  }

  void _onSlotChanged(int index, String value) {
    if (_submitting) return;
    if (_looksLikePaste(value)) {
      if (_tryDistributePaste(index, value)) {
        setState(() {});
        return;
      }
    }
    final trimmed = value.trim().toLowerCase();
    if (trimmed != value) {
      _controllers[index].value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    }
    setState(() {});
    // Exact-match auto-advance: if the user types a full wordlist entry
    // and there's no longer word starting with it, jump to next slot.
    if (_wordSet.contains(trimmed) &&
        !bip39EnglishWordlist.any(
          (w) => w.length > trimmed.length && w.startsWith(trimmed),
        )) {
      _advanceFrom(index);
    }
  }

  void _commitChip(int index, String word) {
    _controllers[index].text = word;
    setState(() {});
    _advanceFrom(index);
  }

  void _advanceFrom(int index) {
    if (index + 1 < widget.wordCount) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
      _maybeSubmit();
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

  Future<void> _maybeSubmit() async {
    if (_submitting) return;
    final words = _collectValidWords();
    if (words == null) return;
    if (_lastSubmittedOnResetKey == widget.resetKey) return;
    _lastSubmittedOnResetKey = widget.resetKey;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(words);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < widget.wordCount; i++) ...<Widget>[
          _slotField(context, i),
          if (_controllers[i].text.length >= 2 &&
              !_wordSet.contains(_controllers[i].text.trim().toLowerCase()))
            _suggestionRow(i, _matchesFor(_controllers[i].text)),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed:
                _submitting || !widget.enabled ? null : _reset,
            icon: const Icon(Icons.clear),
            label: const Text('Clear all'),
          ),
        ),
        if (_submitting)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                'Checking…',
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
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
      label: 'Word ${index + 1} of ${widget.wordCount}',
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
          hintText: 'word',
          border: const OutlineInputBorder(),
          errorText: looksInvalid ? 'Not a valid word' : null,
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    controller.clear();
                    setState(() {});
                    _focusNodes[index].requestFocus();
                  },
                ),
        ),
        onChanged: (v) => _onSlotChanged(index, v),
        onSubmitted: (_) => _advanceFrom(index),
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
                  onPressed: () => _commitChip(slot, w),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
