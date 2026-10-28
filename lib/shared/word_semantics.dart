import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../core/crypto/wordlists.dart';
import '../core/crypto/zh_wordlist.dart';

// Word language for screen readers (v0.5.0 plan Task 1.5b, word-language
// spike §9): every word Signet shows carries its list's language, so
// TalkBack reads French words with a French voice on an English UI and
// English words with an English voice on a French one. A word read in the
// wrong voice is the same kind of mishearing the word lists exist to avoid.

/// The locale [list]'s words are read in, from its BCP-47 tag
/// (language, then an optional 4-letter script and 2-letter or 3-digit
/// region: `fr`, `zh-CN`, `zh-Hans-CN`).
Locale wordLocale(WordList list) {
  final parts = list.languageTag.split('-');
  String? script;
  String? region;
  for (final p in parts.skip(1)) {
    if (p.length == 4) {
      script = p;
    } else if (p.length == 2 || p.length == 3) {
      region = p;
    }
  }
  return Locale.fromSubtags(
    languageCode: parts.first,
    scriptCode: script,
    countryCode: region,
  );
}

final RegExp _letter = RegExp(r'[\p{L}\p{M}]', unicode: true);

/// [text] with [list]'s language marked on every whole-word occurrence of
/// [words], or on all of [text] when [words] is null. For a sentence that
/// mixes UI text and words ("Verification phrase: orange anchor cat
/// wagon"). [within]: the substituted part of [text] (the words joined),
/// so a UI word that is also a list word ("phrase" is French) stays in
/// the UI's voice.
AttributedString attributedWords(
  String text,
  WordList list, {
  Iterable<String>? words,
  String? within,
}) {
  final ranges = <TextRange>[];
  final at = within == null ? -1 : text.indexOf(within);
  final from = at < 0 ? 0 : at;
  final to = at < 0 ? text.length : at + within!.length;
  if (words == null) {
    if (text.isNotEmpty) ranges.add(TextRange(start: 0, end: text.length));
  } else {
    final found = <TextRange>[];
    for (final w in words.toSet()) {
      if (w.isEmpty) continue;
      for (var i = text.indexOf(w, from);
          i >= 0 && i + w.length <= to;
          i = text.indexOf(w, i + w.length)) {
        // Whole words only: "phrase" in "Verification phrase:" or
        // "second" in "secondes" is UI text, not a list word.
        final before = i == 0 ? '' : text[i - 1];
        final after = i + w.length >= text.length ? '' : text[i + w.length];
        if (_letter.hasMatch(before) || _letter.hasMatch(after)) continue;
        found.add(TextRange(start: i, end: i + w.length));
      }
    }
    found.sort((a, b) => a.start.compareTo(b.start));
    for (final r in found) {
      // Skip a word inside one already marked ("able" in "table").
      if (ranges.isEmpty || r.start >= ranges.last.end) ranges.add(r);
    }
  }
  final locale = wordLocale(list);
  return AttributedString(text, attributes: <StringAttribute>[
    for (final r in ranges) LocaleStringAttribute(range: r, locale: locale),
  ]);
}

/// A word of [list], shown as [Text] and read in [list]'s language.
///
/// zh-1 words (plan Task 3.3) also get their glyph locale on the style, so
/// Han unification picks simplified or traditional shapes; a reading line
/// under the word (pinyin with simplified characters, Zhuyin with the
/// Taiwan reading with traditional), which screen readers skip; and, with
/// [bothScripts], the other script next to it, so a simplified phone and a
/// traditional phone on a confirm screen show the same text.
class WordText extends StatelessWidget {
  const WordText(
    this.word, {
    super.key,
    required this.list,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.softWrap,
    this.showReading = true,
    this.bothScripts = false,
  });

  final String word;
  final WordList list;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;

  /// Show a zh-1 word's reading line (off where there is no room, such
  /// as the grid's cells).
  final bool showReading;

  /// Show a zh-1 word in both scripts (the pair-time confirm screens).
  final bool bothScripts;

  @override
  Widget build(BuildContext context) {
    final zh = list.otherScriptWords != null;
    final index = zh ? list.indexOf(word) : null;
    final locale = wordLocale(list);
    final shown = zh && bothScripts && index != null
        ? _bothScripts(word, list.otherScriptWords![index])
        : word;
    final text = Semantics(
      attributedLabel: attributedWords(word, list),
      excludeSemantics: true,
      child: Text(
        shown,
        style: zh ? (style ?? const TextStyle()).copyWith(locale: locale) : style,
        textAlign: textAlign,
        overflow: overflow,
        maxLines: maxLines,
        softWrap: softWrap,
      ),
    );
    if (!zh || !showReading || index == null) return text;
    final entry = zhWordlist[index];
    final reading = WordList.showTraditionalChinese && !bothScripts
        ? entry.zhuyin
        : entry.pinyin;
    final size = style?.fontSize ?? DefaultTextStyle.of(context).style.fontSize;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: switch (textAlign) {
        TextAlign.center => CrossAxisAlignment.center,
        TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
        _ => CrossAxisAlignment.start,
      },
      children: <Widget>[
        text,
        ExcludeSemantics(
          child: Text(
            reading,
            textAlign: textAlign,
            style: TextStyle(
              fontSize: size == null ? null : size * 0.45,
              color: style?.color?.withValues(alpha: 0.75),
              locale: locale,
            ),
          ),
        ),
      ],
    );
  }

  static String _bothScripts(String a, String b) => a == b ? a : '$a · $b';
}
