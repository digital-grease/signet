import '../crypto/wordlists.dart';
import '../crypto/zh_input.dart';
import '../crypto/zh_reading_table.dart';
import '../crypto/zh_wordlist.dart';

/// Pre-write scrubber for crash-log stack traces and error messages.
///
/// **Layer 2** of the four-layer defense in `.devloop/spikes/log-shipping.md`:
///
///   1. Code-side discipline — secrets never appear in toString/error messages
///      in the first place (enforced by `test/logging/leak_prevention_test.dart`).
///   2. **This scrubber** — strips anything that slipped past layer 1.
///   3. AES-GCM at rest — `crashlog_cipher.dart` encrypts the scrubbed blob.
///   4. OS sandbox + FDE — broader containment.
///
/// Strategy: **deny-by-default** with an allow-list. A stack frame line and
/// an unstructured error message line both flow through the same pipeline;
/// tokens that don't match a known-safe shape are replaced with
/// `[redacted:N]` markers (N = original token length, preserved for
/// debugging signal).
///
/// Mechanical redact patterns run first, ahead of the allow-list. These
/// have a **100% pass-or-fail-the-build** test bar (`test/logging/log_scrubber_test.dart`):
///
///   - Hex strings ≥ 16 chars (X25519 keys, AEAD ciphertexts, HKDF output).
///   - Byte lists of 8+ bytes: `[71, 55, 86, ...]` (also signed, and also
///     wrapped across lines), `0x47, 0x37, ...`, `47:37:56:...` and a
///     hexdump's `47 37 56 ...` (how a `List<int>` or a key dump prints).
///   - Base64url strings ≥ 16 chars (transport-package bodies), and
///     standard base64 (`+`, `/`, `=`) ≥ 16 chars that looks like random
///     data (what `SecureStore` writes).
///   - The literal `signet:tp1:` transport-wire prefix.
///   - The source line a `FormatException` echoes (above its `^` caret,
///     or right after the message when there is no offset).
///   - Runs of 4+ words of any shipped list (verify codes, PAKE words)
///     separated by anything but Latin letters and decimal digits: spaces,
///     punctuation and symbols in any script (CJK and fullwidth included),
///     text in other scripts, plus at most one list number of 1-2 digits in
///     any script or a list-final "and" or "et", looked for across the
///     whole text. Shorter runs
///     pass through — "above", "abandon", "able" are common English.
///   - Runs of 4+ zh-1 words: in characters (any written form, glued or
///     separated, starting anywhere in a line of Han), in pinyin (tone
///     marks, tone digits or none; a word's syllables spaced, hyphenated
///     or glued, one word per token), in Zhuyin, numbered or joined the
///     Chinese way (一、 第二个： 和), also inside `\uXXXX`, `%XX` and HTML
///     escapes. Each run is redacted whole.
///   - Values after a name-like key (`label`, `labelHint`, `title`,
///     `peer`, `displayName`, ...), quoted or not.
///
/// `package:<pkg>/<path>.dart` and `dart:<lib>` code paths (with an
/// optional `:line:col`) are exempt from the base64 and BIP-39 rules, but
/// only when the match lies wholly inside the path, so a secret glued onto
/// one is still caught.
///
/// Judgment patterns (pair labels in toString dumps, user clipboard pastes
/// inside exception messages, novel sensitive formats) have a ~95% bar:
/// double-quoted strings get their contents replaced with a length marker.
class LogScrubber {
  const LogScrubber._();

  /// Scrub [input] for sensitive material. Pure function — no I/O, no
  /// global state. Safe to call from any thread / isolate.
  static String scrub(String input) {
    if (input.isEmpty) return input;
    var text = _redactFormatSourceEchoes(input);
    // Across line breaks: a byte list can be wrapped or printed one value
    // per line.
    text = text.replaceAllMapped(
      _decimalByteListPattern,
      (Match m) => _redactToken(m.group(0)!.length),
    );
    text = text.split('\n').map(_forcedRedactMechanical).join('\n');
    // The mechanical patterns are ASCII, so their word boundary falls at an
    // accent: "élève1abaisser2..." became "élè[redacted:28]". Letters left
    // touching a redaction belong to the same token (plan Task 8.4d).
    text = text.replaceAllMapped(_lettersGluedToRedaction, (Match m) {
      final inside = int.parse(m.group(2)!);
      return _redactToken(m.group(1)!.length + inside + m.group(3)!.length);
    });
    // Across line breaks: PAKE words are often written one per line.
    text = _redactListWords(text);
    text = _redactZhClusters(text);
    return text.split('\n').map(_scrubLineJudgment).join('\n');
  }

  // ===========================================================================
  // Per-line judgment pipeline
  // ===========================================================================

  static String _scrubLineJudgment(String line) {
    if (line.isEmpty) return line;
    line = _redactSingleQuotedLabels(line);
    line = _redactQuotedContent(line);
    line = _tokenLevelRedact(line);
    return line;
  }

  // ===========================================================================
  // FormatException source echo (100% bar)
  // ===========================================================================

  static final _caretLinePattern = RegExp(r'^\s*\^\s*$');

  /// `FormatException.toString()` prints the offending input on its own
  /// line, with a `^` caret line under it. That input is whatever was being
  /// parsed: a pasted package, a backup file, words. Redact the line whole.
  static String _redactFormatSourceEchoes(String text) {
    final lines = text.split('\n');
    for (var i = 1; i < lines.length; i++) {
      if (_caretLinePattern.hasMatch(lines[i]) && lines[i - 1].isNotEmpty) {
        lines[i - 1] = _redactToken(lines[i - 1].length);
      }
    }
    // Without an offset there is no caret: the source is simply the line
    // after the message (as DateTime.parse, num.parse and others print it).
    for (var i = 0; i + 1 < lines.length; i++) {
      if (!_formatExceptionLine.hasMatch(lines[i])) continue;
      final next = lines[i + 1];
      if (next.isEmpty ||
          _caretLinePattern.hasMatch(next) ||
          _traceStructureLine.hasMatch(next) ||
          next.startsWith('[redacted:')) {
        continue;
      }
      lines[i + 1] = _redactToken(next.length);
    }
    return lines.join('\n');
  }

  static final _formatExceptionLine = RegExp(r'FormatException:');

  /// A stack frame or trace marker, never an echoed source.
  static final _traceStructureLine =
      RegExp(r'^\s*(?:#\d+\s|<asynchronous|\(elided|When the exception)');

  // ===========================================================================
  // Mechanical redact patterns (100% bar)
  // ===========================================================================

  // signet:tp1: (or a later scheme) + base64url body — catastrophic if
  // leaked. Order matters: run this before the base64 regex so the prefix
  // and body are redacted as one unit with the recognizable length.
  static final _wirePrefixPattern =
      RegExp(r'signet:tp[0-9]+:[A-Za-z0-9+/_-]+={0,2}');

  // Hex run ≥ 16 chars — covers shared secrets, AEAD tags, HKDF outputs.
  static final _hexRunPattern = RegExp(r'\b[0-9a-fA-F]{16,}\b');

  static final _lettersGluedToRedaction = RegExp(
    // The lookbehind starts a match only at the start of a letter run, so
    // a long unspaced CJK line is not rescanned from every position
    // (quadratic: 9.7 s for 8,000 characters before; v0.5.0 Task 0.1).
    r'(?<![\p{L}\p{M}])([\p{L}\p{M}]*)\[redacted:(\d+)\]([\p{L}\p{M}]*)',
    unicode: true,
  );

  // Base64-URL run ≥ 16 chars. Signet's transport-wire uses base64url
  // (`A-Za-z0-9_-`), not classic base64. Excluding `/` and `+` from the
  // alphabet keeps path segments like `package:signet/features/verify`
  // from false-positive matching. The trailing `={0,2}` allows padding.
  // Pure-letter runs are excluded — those are caught by the allow-list
  // and shouldn't be redacted as base64 unless they also have digits or
  // base64-only punctuation (`_-`).
  static final _base64RunPattern = RegExp(r'\b[A-Za-z0-9_-]{16,}={0,2}\b');
  static final _allLettersPattern = RegExp(r'^[A-Za-z]+$');
  static final _identifierLikeRunPattern = RegExp(r'^[A-Za-z_]+$');

  // Byte lists of 8+ bytes, as a `List<int>` or a key dump prints them:
  // decimal `[71, 55, ...]`, `0x47, 0x37, ...`, and `47:37:56:...` /
  // `47-37-56-...`. Fewer than 8 (an IP address, a MAC, a version, a
  // `line:column`) is left alone.
  // Signed values too (`Int8List`, Java's `Arrays.toString(byte[])` in a
  // PlatformException). Applied to the whole text, so a list wrapped
  // across lines is still one list.
  static final _decimalByteListPattern = RegExp(
      r'(?<![\d.])(?:-?\d{1,3}\s*,\s*){7,}-?\d{1,3}(?![\d.])');
  static final _hexByteListPattern = RegExp(
      r'(?:0[xX][0-9a-fA-F]{1,2}[,\s]\s*){7,}0[xX][0-9a-fA-F]{1,2}\b');
  // `47:37:56:...`, `47-37-...` and a hexdump's `c8 c0 7a 69 ...`.
  static final _pairedHexPattern = RegExp(
      r'\b(?:[0-9a-fA-F]{2}[: -]){7,}[0-9a-fA-F]{2}\b');

  // Standard base64 (with `+`, `/`, `=`), as SecureStore writes secrets.
  // Only redacted when it looks like random data (a digit and both cases)
  // and is not part of a package:/dart: path.
  static final _standardBase64Pattern =
      RegExp(r'(?<![A-Za-z0-9+/])[A-Za-z0-9+/]{16,}={0,2}');
  static final _hasDigit = RegExp(r'[0-9]');
  static final _hasUpper = RegExp(r'[A-Z]');
  static final _hasLower = RegExp(r'[a-z]');
  static final _hasBase64Only = RegExp(r'[+/=]');

  static String _forcedRedactMechanical(String line) {
    if (line.isEmpty) return line;
    line = line.replaceAllMapped(
      _wirePrefixPattern,
      (Match m) => _redactToken(m.group(0)!.length),
    );
    for (final pattern in <RegExp>[
      _hexByteListPattern,
      _pairedHexPattern,
    ]) {
      line = line.replaceAllMapped(
        pattern,
        (Match m) => _redactToken(m.group(0)!.length),
      );
    }
    final paths = _pathRanges(line);
    line = line.replaceAllMapped(_standardBase64Pattern, (Match m) {
      final s = m.group(0)!;
      // Exempt only when the whole match lies within a code path, so a
      // secret glued onto the end of one is still caught.
      if (_withinAny(m.start, m.end, paths)) return s;
      if (_looksLikeFilePath(s)) return s;
      if (!_hasBase64Only.hasMatch(s) ||
          !_hasDigit.hasMatch(s) ||
          !_hasUpper.hasMatch(s) ||
          !_hasLower.hasMatch(s)) {
        return s;
      }
      return _redactToken(s.length);
    });
    line = line.replaceAllMapped(
      _hexRunPattern,
      (Match m) => _redactToken(m.group(0)!.length),
    );
    final codePaths = _pathRanges(line);
    line = line.replaceAllMapped(
      _base64RunPattern,
      (Match m) {
        final s = m.group(0)!;
        // A package:/dart: path segment is code, not a payload.
        if (_withinAny(m.start, m.end, codePaths)) return s;
        // Exempt pure-letter runs (English words, class names).
        if (_allLettersPattern.hasMatch(s)) return s;
        // Exempt pure letter+underscore runs (Dart identifiers like
        // `_RenderObjectElement`). Real base64 of random bytes virtually
        // always contains digits or `-`/`=`; an underscore alone doesn't
        // distinguish a payload from an identifier.
        if (_identifierLikeRunPattern.hasMatch(s)) return s;
        return _redactToken(s.length);
      },
    );
    return line;
  }

  // ===========================================================================
  // BIP-39 cluster detector (100% bar)
  // ===========================================================================

  // Word: a Latin letter, then Latin letters and combining marks with any
  // zero-width or soft-hyphen characters inside (plan Task 8.4d), so
  // "élève", its NFD form and "aban\u200Bdon" are each one candidate. Every
  // shipped list is Latin, so other scripts are never part of a candidate,
  // and Han or kana glued to a word ("验证码abandon", "abandon和ability",
  // NFD kana ending in a combining mark) separates (v0.5.0 Task 0.1), as do
  // variation selectors U+FE00-FE0F after a word ("abandon\uFE0F"). A
  // candidate counts when it is a word of any shipped list after the input
  // fold ([WordList.fold]) with fullwidth Latin narrowed; a run may mix
  // lists.
  static final RegExp _candidateWordPattern = RegExp(
    '\\p{Script=Latin}(?:(?![\uFE00-\uFE0F])'
    '[\\p{Script=Latin}\\p{M}\u200B-\u200F\u2060\uFEFF\u00AD\u061C])*',
    unicode: true,
  );

  static const Set<String> _joinWords = {'and', 'et'};

  static bool _isListWord(String candidate) {
    final narrow = candidate.replaceAllMapped(_fullwidthLatin,
        (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xFEE0));
    return WordList.shipped.any((l) => l.contains(narrow));
  }

  // Fullwidth A-Z and a-z, as an IME in fullwidth mode types them.
  static final RegExp _fullwidthLatin = RegExp('[\uFF21-\uFF3A\uFF41-\uFF5A]');

  /// Between two words of a run: anything that is neither a Latin letter
  /// nor a decimal digit, so whitespace, punctuation and symbols in any
  /// script (ASCII, French typography, CJK and fullwidth, emoji), letters
  /// of other scripts ("和"), numerals that are not decimal digits ("一、",
  /// "①") and variation selectors, plus at most one list number of 1-2
  /// decimal digits in any script ("1. abandon\n2. ability", "１．abandon",
  /// "١ abandon") or the word "and" or "et" ("able, about and above").
  /// Listing characters one by one kept missing neighbours (v0.5.0 Task
  /// 0.1 review); over-redaction is accepted.
  static const String _bip39SeparatorChars =
      r'(?:(?![\p{Script=Latin}\p{Nd}])[\s\S])';

  /// "and", or French "et": never a word of any list, they only join one.
  static final RegExp _andWord =
      RegExp(r'\b(?:and|et)\b', caseSensitive: false);
  static final RegExp _bip39SeparatorPattern = RegExp(
    '^$_bip39SeparatorChars*'
    '(?:(?:\\p{Nd}{1,2}[.)．）]?|and|et)$_bip39SeparatorChars*)?\$',
    caseSensitive: false,
    unicode: true,
  );

  /// A list comma, ASCII or CJK, before a list-final "and".
  static final RegExp _listComma = RegExp('[,，、﹐﹑､︐︑،]');

  /// Find runs of ≥ 4 consecutive BIP-39 words joined by
  /// [_bip39SeparatorPattern] separators; redact each word in any
  /// qualifying run. Single, double, or
  /// triple BIP-39 words are NOT redacted — they're common English and
  /// don't carry enough entropy to fingerprint a verify code or PAKE.
  /// List words in [text]: the Latin pass over the text as it stands,
  /// and again over it decoded ([_bip39WordRangesDecoded]). The union is
  /// redacted, so a run one reading only half sees is still redacted
  /// whole, and an earlier redaction never hides the rest of a run.
  static String _redactListWords(String text) => _redactRanges(text, <(int, int)>[
        ..._bip39WordRanges(text),
        ..._bip39WordRangesDecoded(text),
      ]);

  /// The list words in runs of 4+ in [line], as UTF-16 ranges in order.
  /// Words in a `package:`/`dart:` path are exempt unless [exemptPaths] is
  /// false (the decoded reading checks paths in the original instead).
  static List<(int, int)> _bip39WordRanges(String line,
      {bool exemptPaths = true, bool countMarkers = false}) {
    // With [countMarkers], an earlier redaction inside a run counts as one
    // of its words (a mechanical rule can take a piece of an escaped line,
    // "\U0000000Aability" looks like base64); it is never output again.
    final markers = countMarkers
        ? [
            for (final m in _redactionMarker.allMatches(line))
              (start: m.start, end: m.end, word: '', marker: true),
          ]
        : const <({int start, int end, String word, bool marker})>[];
    // "and" is never a code word itself: it is part of the separator in
    // "able, about and above".
    final matches = <({int start, int end, String word, bool marker})>[];
    var k = 0; // the next marker, both lists being in order
    for (final m in _candidateWordPattern.allMatches(line)) {
      while (k < markers.length && markers[k].end <= m.start) {
        matches.add(markers[k++]);
      }
      if (k < markers.length && m.start >= markers[k].start) continue;
      if (_joinWords.contains(m.group(0)!.toLowerCase())) continue;
      matches.add((start: m.start, end: m.end, word: m.group(0)!, marker: false));
    }
    matches.addAll(markers.skip(k));
    if (matches.length < 4) return const <(int, int)>[];

    // Mark each candidate word as BIP-39-or-not. Words in a package:/dart:
    // path ("package:flutter/src/widgets/...") are code, never secrets.
    final paths = exemptPaths ? _pathRanges(line) : const <List<int>>[];
    final isBip39 = matches
        .map((m) =>
            m.marker ||
            (_isListWord(m.word) && !_insideAny(m.start, paths)))
        .toList();

    // Walk and find runs of list words where adjacent words are separated
    // only by [_bip39SeparatorPattern] text.
    final ranges = <List<int>>[]; // [startMatchIdx, endMatchIdxExclusive]
    var i = 0;
    while (i < matches.length) {
      if (!isBip39[i]) {
        i++;
        continue;
      }
      var runEnd = i + 1;
      var sawComma = false;
      while (runEnd < matches.length && isBip39[runEnd]) {
        final between = line.substring(
          matches[runEnd - 1].end,
          matches[runEnd].start,
        );
        if (!_bip39SeparatorPattern.hasMatch(between)) break;
        // "and" joins a run only in list grammar ("able, about and
        // above"), not in prose ("... doctor and Anchor again").
        if (_andWord.hasMatch(between) && !sawComma) break;
        if (between.contains(_listComma)) sawComma = true;
        runEnd++;
      }
      if (runEnd - i >= 4) ranges.add(<int>[i, runEnd]);
      i = runEnd;
    }

    return [
      for (final r in ranges)
        for (var k = r[0]; k < r[1]; k++)
          if (!matches[k].marker) (matches[k].start, matches[k].end),
    ];
  }

  /// Text the Latin pass cannot see through as it stands: escapes,
  /// entities and markup ([_ZhView] decodes them), ligatures and joiners
  /// inside words.
  static final RegExp _needsDecodedPass =
      RegExp('[\\\\%&<ﬀ-ﬆ͏᠎]');

  /// A list marker made of a letter or a Roman numeral ("I.", "Ⅳ.", "a)",
  /// "[b]", "ｃ）", glued to the word or not), blanked before the decoded
  /// reading (same length, so offsets keep).
  static final RegExp _letterListMarker = RegExp(
    '(?<![\\p{L}\\p{M}])'
    '(?:[A-Za-zＡ-Ｚａ-ｚ]|[ivxIVX]{1,4}|[Ⅰ-ⅿ])'
    '[.)．）:\\]］]',
    unicode: true,
  );

  /// The list words in [text] read decoded: escapes and entities
  /// (`\n`, `、`, `%0A`, `%E3%80%81`, `&nbsp;`, `&eacute;`, tags,
  /// ligatures, joiners dropped) and letter list markers as separators
  /// (plan Task 0.6), as ranges of the original text. Empty when the
  /// decoded reading is the text itself, which the plain reading covers.
  static List<(int, int)> _bip39WordRangesDecoded(String text) {
    final decode = _needsDecodedPass.hasMatch(text);
    final view = decode ? _ZhView.of(text, pinyinColon: false) : null;
    final decoded = view?.text ?? text;
    final read = decoded.replaceAllMapped(
        _letterListMarker, (m) => ' ' * (m.end - m.start));
    if (read == text) return const <(int, int)>[];
    final paths = _pathRanges(text);
    final out = <(int, int)>[];
    for (final (s16, e16)
        in _bip39WordRanges(read, exemptPaths: false, countMarkers: true)) {
      final start = view == null ? s16 : view.starts[view.runeAt(s16)];
      final end = view == null ? e16 : view.ends[view.runeAt(e16) - 1];
      // A path only counts where the original has one: decoding
      // "%2F" must not make one up around the words.
      if (_withinAny(start, end, paths)) continue;
      out.add((start, end));
    }
    return out;
  }

  // ===========================================================================
  // zh-1 cluster detector (100% bar)
  // ===========================================================================

  /// Every written form of every zh-1 entry (simplified, Taiwan
  /// traditional, other accepted forms). Characters count as a word only
  /// as one of these, never through the reading table, which would take
  /// ordinary Chinese prose for words.
  static final Set<String> _zhForms = <String>{
    for (final w in zhWordlist) ...<String>{
      w.simplified,
      w.traditional,
      ...w.otherForms,
    },
  };

  /// Every Zhuyin reading of every zh-1 entry, with its tone marks and
  /// without, as the traditional reading line shows it ("ㄅㄚ ㄍㄜ") and
  /// glued ("ㄅㄚㄍㄜ").
  static final Set<String> _zhZhuyin = <String>{
    for (final w in zhWordlist)
      for (final z in <String>[w.zhuyin, w.zhuyin.replaceAll(_zhuyinTone, '')])
        ...<String>[z, z.replaceAll(' ', '')],
  };
  static final RegExp _zhuyinTone = RegExp('[ˊˇˋ˙]');
  static final RegExp _zhuyinSyllable =
      RegExp('[㄀-ㄯㆠ-ㆿˊˇˋ˙]+');

  static bool _isZhuyinRune(int r) =>
      (r >= 0x3100 && r <= 0x312F) ||
      (r >= 0x31A0 && r <= 0x31BF) ||
      r == 0x02CA ||
      r == 0x02C7 ||
      r == 0x02CB ||
      r == 0x02D9;

  /// Between two words, a list number or a joining word in Chinese
  /// (一、八哥 二、岸边, 第三个：按钮, 按钮和安全带) or "and" / "et": one
  /// may stand where a word of the run would otherwise have to start.
  static final RegExp _zhJoiner = RegExp(
    '(?:[和与與及或]|(?:and|et)(?![\\p{L}\\p{M}])|'
    '第?[一二三四五六七八九十两兩〇]{1,3}[个個]?[、.．:：)）])',
    caseSensitive: false,
    unicode: true,
  );

  static final RegExp _redactionMarker = RegExp(r'\[redacted:\d+\]');

  /// Between the syllables of one word written in pinyin: a tone digit
  /// and any spaces, apostrophes, hyphens or middle dots.
  static final RegExp _pinyinJoiner =
      RegExp('^[0-5]?[\\s\'‘’ʼ\\-‐‑·・]*\$');

  /// Find runs of ≥ 4 zh-1 words and redact each run whole: in characters
  /// (any written form, glued, one space or comma apart, or separated, at
  /// either parity of a glued line), in pinyin (one Latin token per word,
  /// or two or three syllable tokens, a trailing tone digit included; not
  /// several words glued into one token), in Zhuyin, or a mix, and inside
  /// `\uXXXX`, `%XX` and `&#...;` escapes ([_ZhView]). Words are joined as
  /// Latin-list words are ([_bip39SeparatorPattern]), plus one Chinese list
  /// number or joining word ([_zhJoiner]); any other character that is not
  /// part of a word ends the run: that is prose. An earlier redaction
  /// counts as a word, but a run needs one real word. Variation selectors
  /// and format characters are ignored, compatibility ideographs read as
  /// the character they stand for.
  static String _redactZhClusters(String text) {
    final runs = _zhRuns(text, _ZhView.of(text));
    // `\n` before "nai cha" is also a backslash and the word's first
    // letter: read it both ways.
    if (_letterEscape.hasMatch(text)) {
      runs.addAll(_zhRuns(text, _ZhView.of(text, letterEscapes: false)));
    }
    return _redactRanges(text, runs);
  }

  static final RegExp _letterEscape = RegExp(r'\\[ntrfvb]');

  /// The runs [_redactZhClusters] redacts in [text], read through [view],
  /// as ranges of [text].
  static List<(int, int)> _zhRuns(String text, _ZhView view) {
    final runes = view.runes;
    final n = runes.length;
    if (n < 8) return <(int, int)>[];
    const han = ZhInput.isHanRune;
    // A redaction an earlier pass made inside a run (a long pinyin word
    // can look like base64) still counts as one of its words.
    final markers = <(int, int)>[
      for (final m in _redactionMarker.allMatches(view.text))
        (view.runeAt(m.start), view.runeAt(m.end)),
    ];
    // A tone digit right after a word is part of it ("an4 quan2 dai4").
    int withTone(int end) => end < n &&
            runes[end] >= 0x30 &&
            runes[end] <= 0x35 &&
            (end + 1 >= n || runes[end + 1] < 0x30 || runes[end + 1] > 0x39)
        ? end + 1
        : end;
    for (var k = 0; k < markers.length; k++) {
      markers[k] = (markers[k].$1, withTone(markers[k].$2));
    }
    final markerStarts = {for (final m in markers) m.$1};
    bool startsWord(int i) =>
        han(runes[i]) ||
        _isLatinLetterRune(runes[i]) ||
        _isZhuyinRune(runes[i]) ||
        markerStarts.contains(i);

    // Each word as [start, end) in runes of the view.
    final words = <(int, int)>[...markers];
    // Characters, glued or with one space or comma between them, as a PDF
    // copy spaces them ("八 哥 岸 边").
    bool gap(int r) => r == 0x20 || r == 0x3000 || r == 0x2C || r == 0xFF0C ||
        r == 0x3001;
    for (var p = 0; p + 1 < n; p++) {
      if (!han(runes[p])) continue;
      final chars = <int>[runes[p]];
      var at = p;
      while (chars.length < 3) {
        if (at + 1 < n && han(runes[at + 1])) {
          at += 1;
        } else if (at + 2 < n && gap(runes[at + 1]) && han(runes[at + 2])) {
          at += 2;
        } else {
          break;
        }
        chars.add(runes[at]);
        if (_zhForms.contains(String.fromCharCodes(chars))) {
          words.add((p, at + 1));
        }
      }
    }
    // Zhuyin, one to three syllables a word.
    final zhuyin = [
      for (final m in _zhuyinSyllable.allMatches(view.text))
        (view.runeAt(m.start), view.runeAt(m.end)),
    ];
    for (var c = 0; c < zhuyin.length; c++) {
      for (var k = 1; k <= 3 && c + k <= zhuyin.length; k++) {
        final last = zhuyin[c + k - 1];
        if (k > 1 &&
            view.slice(zhuyin[c + k - 2].$2, last.$1).trim().isNotEmpty) {
          break;
        }
        final s = view.slice(zhuyin[c].$1, last.$2).replaceAll(RegExp(r'\s+'), ' ');
        if (_zhZhuyin.contains(s) ||
            _zhZhuyin.contains(s.replaceAll(_zhuyinTone, ''))) {
          words.add((zhuyin[c].$1, last.$2));
        }
      }
    }
    final latin = view.latinTokens();
    if (latin.isNotEmpty) {
      final paths = _pathRanges(text);
      final seen = <String, bool>{};
      bool names(String s) => seen.putIfAbsent(
          s, () => ZhInput.zh1.candidates(s).isNotEmpty);
      for (var c = 0; c < latin.length; c++) {
        if (_insideAny(view.starts[latin[c].$1], paths)) continue;
        for (var k = 1; k <= 3 && c + k <= latin.length; k++) {
          final last = latin[c + k - 1];
          if (k > 1) {
            final prev = latin[c + k - 2];
            // Several tokens make one word only as syllables (counted in
            // letters: NFD "zhuāng" is 7 code points).
            if (view.letters(prev.$1, prev.$2) > 6 ||
                view.letters(last.$1, last.$2) > 6) {
              break;
            }
            if (!_pinyinJoiner.hasMatch(view.slice(prev.$2, last.$1))) break;
          }
          final s = view.slice(latin[c].$1, last.$2);
          if (s.length > 30) break;
          if (names(s)) words.add((latin[c].$1, withTone(last.$2)));
        }
      }
    }
    if (words.length < 4) return <(int, int)>[];

    // nextLetter[i]: the first place at or after i where a word can
    // start, which is where the next word of a run must start.
    final nextLetter = List<int>.filled(n + 1, n);
    for (var i = n - 1; i >= 0; i--) {
      nextLetter[i] = startsWord(i) ? i : nextLetter[i + 1];
    }
    final byStart = <int, List<int>>{};
    for (var w = 0; w < words.length; w++) {
      (byStart[words[w].$1] ??= <int>[]).add(w);
    }
    // best[w]: the most words in a run starting with w; next[w]: the word
    // after it in that run; reach[w]: where that run ends. Of two runs
    // with as many words, the one reaching further wins, so syllables
    // grouped another way ("biao ge" for "... biao ge qu") leave nothing.
    final order = List<int>.generate(words.length, (i) => i)
      ..sort((a, b) => words[b].$1.compareTo(words[a].$1));
    final best = List<int>.filled(words.length, 1);
    final next = List<int>.filled(words.length, -1);
    final reach = [for (final w in words) w.$2];
    // Words in the run that are not earlier redactions: a run needs one,
    // so a row of Latin redactions is not merged into one.
    final real = [
      for (var w = 0; w < words.length; w++) w < markers.length ? 0 : 1,
    ];
    for (final w in order) {
      final end = words[w].$2;
      final q = nextLetter[end];
      if (!_bip39SeparatorPattern.hasMatch(view.slice(end, q))) continue;
      var followers = byStart[q];
      if (followers == null && q < n) {
        // One list number or joining word where the next word would start.
        final joiner = _zhJoiner.matchAsPrefix(view.text, view.offsetOf(q));
        if (joiner != null) {
          final after = view.runeAt(joiner.end);
          final q2 = nextLetter[after];
          if (_bip39SeparatorPattern.hasMatch(view.slice(after, q2))) {
            followers = byStart[q2];
          }
        }
      }
      if (followers == null) continue;
      for (final f in followers) {
        if (best[f] + 1 > best[w] ||
            (best[f] + 1 == best[w] && reach[f] > reach[w])) {
          best[w] = best[f] + 1;
          next[w] = f;
          reach[w] = reach[f];
          real[w] = real[f] + (w < markers.length ? 0 : 1);
        }
      }
    }

    final runs = <(int, int)>[]; // original offsets
    var covered = -1;
    final byStartAsc = List<int>.generate(words.length, (i) => i)
      ..sort((a, b) => words[a].$1.compareTo(words[b].$1));
    for (final w in byStartAsc) {
      if (words[w].$1 < covered || best[w] < 4 || real[w] == 0) continue;
      var last = w;
      while (next[last] >= 0) {
        last = next[last];
      }
      runs.add((view.starts[words[w].$1], view.ends[words[last].$2 - 1]));
      covered = words[last].$2;
    }
    return runs;
  }

  /// [text] with each of [ranges] redacted; overlapping ranges become one.
  static String _redactRanges(String text, List<(int, int)> ranges) {
    if (ranges.isEmpty) return text;
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(int, int)>[];
    for (final r in ranges) {
      if (merged.isNotEmpty && r.$1 < merged.last.$2) {
        final last = merged.removeLast();
        merged.add((last.$1, r.$2 > last.$2 ? r.$2 : last.$2));
      } else {
        merged.add(r);
      }
    }
    final buf = StringBuffer();
    var cursor = 0;
    for (final (start, end) in merged) {
      buf.write(text.substring(cursor, start));
      buf.write(_redactToken(end - start));
      cursor = end;
    }
    buf.write(text.substring(cursor));
    return buf.toString();
  }

  static bool _isLatinLetterRune(int r) =>
      _latinLetter.hasMatch(String.fromCharCode(r));
  static final RegExp _latinLetter = RegExp(r'\p{Script=Latin}', unicode: true);

  // ===========================================================================
  // Label values after a name-like key (100% bar)
  // ===========================================================================

  /// A key that names a person: anything containing label, name, contact,
  /// title or peer (`label`, `labelHint`, `peerLabel`, `labelText`,
  /// `displayName`, `title`, `peer`, `nickname`). The `\w*` on both sides
  /// takes in camelCase keys whole.
  static const String _nameKey =
      r'\b(\w*(?:label|name|contact|title|peer)\w*)(\s*[:=]\s*)';

  /// `label: 'Mom'`, `labelHint="Bob"`: the quoted value, either quote.
  static final _quotedLabelPattern = RegExp(
    '$_nameKey' r"""('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")""",
    caseSensitive: false,
  );

  /// `{id: x, label: Mom, role: a}`, `(label: Aunt May, id: 3)`: how Dart
  /// prints maps and records, without quotes. The value runs to the next
  /// `,` `)` `}` `]`. A `<peer-N>` token from the export scrubber, or a
  /// value already redacted, is left alone.
  static final _unquotedLabelPattern = RegExp(
    '$_nameKey' r"""((?![<\['"\s])[^,)}\]\n]*[^,)}\]\n\s])""",
    caseSensitive: false,
  );

  static String _redactSingleQuotedLabels(String line) {
    line = line.replaceAllMapped(_quotedLabelPattern, (Match m) {
      final quoted = m.group(3)!;
      final q = quoted[0];
      return '${m.group(1)}${m.group(2)}$q'
          '${_redactToken(quoted.length - 2)}$q';
    });
    return line.replaceAllMapped(
      _unquotedLabelPattern,
      (Match m) =>
          '${m.group(1)}${m.group(2)}${_redactToken(m.group(3)!.length)}',
    );
  }

  // ===========================================================================
  // Quoted-content redactor (~95% bar)
  // ===========================================================================

  static final _quotedStringPattern = RegExp(r'"([^"\\]|\\.)*"');

  /// Anything between double quotes is treated as suspicious content unless
  /// it matches a small set of Dart template-message patterns. The trade-off:
  /// false-positive redactions on legit messages like `"Unexpected character"`
  /// are recoverable (we widen the allow-list); false-negative leaks of
  /// `Relationship(label: "Mom")` style content are not.
  static String _redactQuotedContent(String line) {
    return line.replaceAllMapped(
      _quotedStringPattern,
      (Match m) {
        final raw = m.group(0)!;
        // Strip the surrounding quotes for inspection.
        final inner = raw.substring(1, raw.length - 1);
        if (_isTemplateMessage(inner)) return raw;
        return '"${_redactToken(inner.length)}"';
      },
    );
  }

  // Heuristic for "this quoted string looks like a Dart template-generated
  // exception message (no user data)". Two gates, both must pass:
  //
  //   1. Shape: ≥ 2 alphabetic words, total length ≤ 64.
  //   2. Capitalization: at most ONE word starts with a capital letter
  //      (the sentence opener).
  //
  // Examples:
  //   - "Unexpected character"   → 2 words, 1 cap → pass.
  //   - "Index out of range"     → 4 words, 1 cap → pass.
  //   - "Mom" / "Dad"            → 1 word        → fail → redact.
  //   - "Source A" / "Finance Team" / "My Therapist" → 2 words, 2 caps → redact.
  //   - "CONFIDENTIAL_SOURCE"    → has _         → fail → redact.
  //   - "Bob from work"          → 3 words, 1 cap → pass (RESIDUAL slip;
  //     structurally identical to "Some natural sentence"; an accepted
  //     judgment-class miss within the ≥95% bar).
  //
  // Bias: any ambiguity → redact. False positives lose debugging signal,
  // false negatives lose secrets.
  static final _multiWordTemplatePattern =
      RegExp(r'^[A-Za-z]+(?: [A-Za-z]+){1,7}$');
  static final _capitalizedWordStart = RegExp(r'^[A-Z]');

  static bool _isTemplateMessage(String s) {
    if (s.isEmpty) return true; // empty string isn't a leak
    if (s.length > 64) return false;
    if (!_multiWordTemplatePattern.hasMatch(s)) return false;
    // At most one capitalized word (the sentence opener).
    final caps = s.split(' ').where(_capitalizedWordStart.hasMatch).length;
    return caps <= 1;
  }

  // ===========================================================================
  // Token-level redactor (~95% bar)
  // ===========================================================================

  /// Identifier-shape tokens (Dart names). Numbers and punctuation pass
  /// through untouched in [_tokenLevelRedact] regardless.
  static final _identifierPattern = RegExp(r'[A-Za-z_][A-Za-z0-9_]*');

  /// Allow-list — exception types that are safe to keep verbatim. Dart's
  /// built-ins use template messages that don't carry user data.
  static const Set<String> _allowedExceptionTypes = <String>{
    'AbstractClassInstantiationError',
    'ArgumentError',
    'AssertionError',
    'CastError',
    'ConcurrentModificationError',
    'CyclicInitializationError',
    'Error',
    'Exception',
    'FallThroughError',
    'FormatException',
    'IntegerDivisionByZeroException',
    'NoSuchMethodError',
    'NullThrownError',
    'OutOfMemoryError',
    'RangeError',
    'StackOverflowError',
    'StateError',
    'TypeError',
    'UnimplementedError',
    'UnsupportedError',
    // Flutter / cryptography common ones
    'FlutterError',
    'PlatformException',
    'MissingPluginException',
    'TimeoutException',
    'HandshakeException',
    'SocketException',
    // Signet-defined
    'InvalidPakeException',
    'InvalidPackageException',
  };

  /// Trace-structure tokens that aren't identifiers but should pass.
  static const Set<String> _allowedStackMarkers = <String>{
    'asynchronous',
    'suspension',
    'gap',
    'anonymous',
    'closure',
    'new',
  };

  /// Package-path prefixes that mark a "safe to keep" region. Any
  /// identifier whose position falls inside a matching region passes the
  /// allow-list. The signet codebase is open source (AGPL-3.0), so file
  /// structure is public.
  static final RegExp _packagePathRegionPattern = RegExp(
    r'\b(?:package:[A-Za-z_]\w*(?:/[\w.\-]+)*\.dart'
    r'|dart:[A-Za-z_]\w*(?:/[\w.\-]+\.dart)?)(?::\d+(?::\d+)?)?',
  );

  static List<List<int>> _pathRanges(String text) => _packagePathRegionPattern
      .allMatches(text)
      .map((m) => <int>[m.start, m.end])
      .toList();

  /// Index of the range containing [index] in [ranges] (sorted, not
  /// overlapping), or -1. Binary search: the whole-text BIP-39 pass calls
  /// this once per word, and a linear scan made a 2 MB log quadratic.
  static int _rangeAt(int index, List<List<int>> ranges) {
    var lo = 0;
    var hi = ranges.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final r = ranges[mid];
      if (index < r[0]) {
        hi = mid - 1;
      } else if (index >= r[1]) {
        lo = mid + 1;
      } else {
        return mid;
      }
    }
    return -1;
  }

  static bool _insideAny(int index, List<List<int>> ranges) =>
      _rangeAt(index, ranges) >= 0;

  /// [start, end) lies wholly inside one range.
  static bool _withinAny(int start, int end, List<List<int>> ranges) {
    final i = _rangeAt(start, ranges);
    return i >= 0 && end <= ranges[i][1];
  }

  /// `/storage/emulated/0/Download/SignetBackup.txt`: a run that starts
  /// with `/` and whose segments are all short is a file path, not base64
  /// (a random blob does not split into short slash-separated pieces).
  static bool _looksLikeFilePath(String s) {
    if (!s.startsWith('/')) return false;
    final segments = s.split('/').where((e) => e.isNotEmpty).toList();
    return segments.length >= 2 && segments.every((e) => e.length < 16);
  }

  static String _tokenLevelRedact(String line) {
    // Pre-compute the ranges of package/dart paths — identifiers inside
    // them get kept verbatim.
    final pathRanges = _pathRanges(line);

    return _identifierPattern.allMatches(line).fold<_RedactState>(
      _RedactState(line: line, cursor: 0, buf: StringBuffer()),
      (state, match) {
        state.buf.write(line.substring(state.cursor, match.start));
        state.cursor = match.end;
        final tok = match.group(0)!;
        if (_keepIdentifier(tok, match.start, pathRanges)) {
          state.buf.write(tok);
        } else {
          state.buf.write(_redactToken(tok.length));
        }
        return state;
      },
    ).finish();
  }

  static bool _keepIdentifier(
    String tok,
    int start,
    List<List<int>> pathRanges,
  ) {
    // Stack-frame structural words like <asynchronous suspension>
    if (_allowedStackMarkers.contains(tok)) return true;
    // Exception types from the curated list
    if (_allowedExceptionTypes.contains(tok)) return true;
    // Dart conventions: identifiers starting with _ are private internals,
    // which are framework/app code path names, not data.
    if (tok.startsWith('_')) return true;
    // Inside a package: or dart: path, keep all identifier tokens (including
    // snake_case file names like verify_screen).
    for (final r in pathRanges) {
      if (start >= r[0] && start < r[1]) return true;
    }
    // CamelCase class name — keep. The dangerous "label leaked into
    // toString" content gets caught by the quoted-content redactor.
    if (RegExp(r'^[A-Z][A-Za-z0-9]*$').hasMatch(tok)) return true;
    // Short all-lowercase identifier — usually a method or local name in
    // a stack frame (`build`, `get`, `setState`, `then`). Allow up to
    // 24 chars; longer single-lowercase runs would have been caught by
    // the base64 regex if they had digits, and pure-letter long runs are
    // very rare in code.
    if (RegExp(r'^[a-z][a-z0-9]{0,23}$').hasMatch(tok)) return true;
    return false;
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  static String _redactToken(int originalLength) =>
      '[redacted:$originalLength]';
}

/// Mutable fold accumulator for [_tokenLevelRedact].
class _RedactState {
  _RedactState({required this.line, required this.cursor, required this.buf});
  final String line;
  int cursor;
  final StringBuffer buf;

  String finish() {
    buf.write(line.substring(cursor));
    return buf.toString();
  }
}

/// [text] as the zh-1 detector reads it: one entry per code point, with
/// `\uXXXX`, `\u{X...}` and `%XX` (UTF-8) escapes decoded, variation
/// selectors and format characters dropped, and compatibility ideographs
/// unified; each entry keeps the range of [text] it came from, so a run
/// found here is redacted in the original, escapes and all.
class _ZhView {
  _ZhView._(this.runes, this.starts, this.ends, this._text, this._offsets);

  final List<int> runes;
  final List<int> starts;
  final List<int> ends;

  /// The decoded text, and the UTF-16 offset in it of each rune.
  final String _text;
  final List<int> _offsets;

  /// The decoded text.
  String get text => _text;

  /// Runes [from, to) as a string.
  String slice(int from, int to) => _text.substring(_offsets[from], _offsets[to]);

  /// The UTF-16 offset in [text] of rune [i].
  int offsetOf(int i) => _offsets[i];

  /// The rune at UTF-16 offset [offset] of [text].
  int runeAt(int offset) => _runeAt(offset);

  /// Runes [from, to) that are not combining marks.
  int letters(int from, int to) {
    var count = 0;
    for (var i = from; i < to; i++) {
      final r = runes[i];
      if (r < 0x0300 || r > 0x036F) count++;
    }
    return count;
  }

  /// Runs of Latin letters (with combining marks), as [start, end) runes.
  List<(int, int)> latinTokens() => [
        for (final m in LogScrubber._candidateWordPattern.allMatches(_text))
          (_runeAt(m.start), _runeAt(m.end)),
      ];

  int _runeAt(int offset) {
    var lo = 0;
    var hi = _offsets.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_offsets[mid] < offset) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// [text] decoded. [pinyinColon]: read "u:" as ü, as CC-CEDICT writes
  /// lü (the zh-1 pass only: in the Latin pass "menu:ability" would become
  /// one word). [letterEscapes]: decode `\n`, `\t` and the other letter
  /// escapes (the zh-1 pass also reads the text without them, since `\n`
  /// before "nai cha" is a backslash and a letter of the word). Text
  /// encoded twice (`&amp;nbsp;`, `%250A`, `&lt;br&gt;`) is decoded again,
  /// up to three rounds.
  static _ZhView of(
    String text, {
    bool pinyinColon = true,
    bool letterEscapes = true,
  }) {
    var view = _decodeOnce(text, pinyinColon, letterEscapes);
    for (var round = 1;
        round < 3 && view._text != text && _encoded.hasMatch(view._text);
        round++) {
      final inner = _decodeOnce(view._text, pinyinColon, letterEscapes);
      if (inner._text == view._text) break;
      view = view._then(inner);
    }
    return view;
  }

  /// Anything [_decodeOnce] could decode.
  static final RegExp _encoded = RegExp(r'[\\%&<]');

  /// [inner], a view of this view's text, as a view of the original.
  _ZhView _then(_ZhView inner) {
    final s = <int>[];
    final e = <int>[];
    for (var k = 0; k < inner.runes.length; k++) {
      s.add(starts[_runeAt(inner.starts[k])]);
      e.add(ends[_runeAt(inner.ends[k]) - 1]);
    }
    return _ZhView._(inner.runes, s, e, inner._text, inner._offsets);
  }

  static _ZhView _decodeOnce(
      String text, bool pinyinColon, bool letterEscapes) {
    final runes = <int>[];
    final starts = <int>[];
    final ends = <int>[];
    void add(int r, int s, int e) {
      if (_ignored(r)) {
        if (ends.isNotEmpty) ends[ends.length - 1] = e;
        return;
      }
      if (pinyinColon &&
          r == 0x3A &&
          runes.isNotEmpty &&
          (runes.last == 0x75 || runes.last == 0x55)) {
        r = 0x0308;
      }
      runes.add(zhCompatibilityIdeographs[r] ?? r);
      starts.add(s);
      ends.add(e);
    }

    var i = 0;
    while (i < text.length) {
      final unit = text.codeUnitAt(i);
      if (unit == 0x5C) {
        // A run of backslashes, read once: an escape escaped again
        // (`\\n`, `\\u516b`) is still one escape, and a long run costs
        // one pass, not one per backslash.
        var j = i;
        while (j < text.length && text.codeUnitAt(j) == 0x5C) {
          j++;
        }
        final escape = _backslashEscape(text, j, letterEscapes);
        if (escape != null) {
          add(escape.$1, i, escape.$2);
          i = escape.$2;
        } else {
          for (var k = i; k < j; k++) {
            add(0x5C, k, k + 1);
          }
          i = j;
        }
        continue;
      }
      if (unit == 0x26) {
        final entity = _entity(text, i);
        if (entity != null) {
          add(entity.$1, i, entity.$2);
          i = entity.$2;
          continue;
        }
      } else if (unit == 0x3C) {
        final tag = _tag.matchAsPrefix(text, i);
        if (tag != null) {
          // Inline tags glue ("aba<wbr>ndon", "<b>aba</b>ndon"); any
          // other tag separates, as a line break would.
          final inline = _inlineTags.contains(tag[1]!.toLowerCase());
          add(inline ? 0x200B : 0x0A, i, tag.end);
          i = tag.end;
          continue;
        }
      } else if (unit == 0x25) {
        final percent = _percentEscapes(text, i);
        if (percent.isNotEmpty) {
          for (final (r, s, e) in percent) {
            add(r, s, e);
          }
          i = percent.last.$3;
          continue;
        }
      } else if (unit >= 0xFB00 && unit <= 0xFB06) {
        for (final r in _ligatures[String.fromCharCode(unit)]!.runes) {
          add(r, i, i + 1);
        }
        i++;
        continue;
      }
      if (unit >= 0xD800 &&
          unit <= 0xDBFF &&
          i + 1 < text.length &&
          (text.codeUnitAt(i + 1) & 0xFC00) == 0xDC00) {
        add(0x10000 + ((unit - 0xD800) << 10) + (text.codeUnitAt(i + 1) - 0xDC00),
            i, i + 2);
        i += 2;
        continue;
      }
      add(unit, i, i + 1);
      i++;
    }
    final decoded = String.fromCharCodes(runes);
    final offsets = List<int>.filled(runes.length + 1, 0);
    for (var k = 0; k < runes.length; k++) {
      offsets[k + 1] = offsets[k] + (runes[k] > 0xFFFF ? 2 : 1);
    }
    return _ZhView._(runes, starts, ends, decoded, offsets);
  }

  /// The escape after a run of backslashes ending at [j]: `\uXXXX` (a
  /// surrogate pair as two), `\u{X...}`, `\UXXXXXXXX`, `\xXX`, octal
  /// `\012`, and with [letterEscapes] `\n \t \r \f \v \b \0`. The code
  /// point and the offset after the escape, or null.
  static (int, int)? _backslashEscape(String text, int j, bool letterEscapes) {
    if (j >= text.length) return null;
    final c = text[j];
    int? within(int? v) => v == null || v > 0x10FFFF ? null : v;
    switch (c) {
      case 'u':
        if (j + 1 < text.length && text[j + 1] == '{') {
          // At most 6 digits: never search the rest of the text for the
          // brace, which was quadratic on a long run of "\u{".
          var close = j + 2;
          while (close < text.length &&
              close - (j + 2) <= 6 &&
              text[close] != '}') {
            close++;
          }
          if (close >= text.length || text[close] != '}' || close == j + 2) {
            return null;
          }
          final value = within(_hex(text, j + 2, close - (j + 2)));
          return value == null ? null : (value, close + 1);
        }
        final unit = _hex(text, j + 1, 4);
        if (unit == null) return null;
        if (unit >= 0xD800 &&
            unit <= 0xDBFF &&
            text.startsWith(r'\u', j + 5)) {
          final low = _hex(text, j + 7, 4);
          if (low != null && low >= 0xDC00 && low <= 0xDFFF) {
            return (0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00), j + 11);
          }
        }
        return (unit, j + 5);
      case 'U':
        final value = within(_hex(text, j + 1, 8));
        return value == null ? null : (value, j + 9);
      case 'x':
        final value = _hex(text, j + 1, 2);
        return value == null ? null : (value, j + 3);
    }
    final digit = c.codeUnitAt(0) - 0x30;
    if (digit >= 0 && digit <= 7) {
      var end = j + 1;
      var value = digit;
      while (end < text.length && end - j < 3) {
        final d = text.codeUnitAt(end) - 0x30;
        if (d < 0 || d > 7) break;
        value = value * 8 + d;
        end++;
      }
      // "\0" alone is a NUL: read it as a space.
      return (end == j + 1 && value == 0 ? 0x20 : value, end);
    }
    if (!letterEscapes) return null;
    final value = switch (c) {
      'n' => 0x0A,
      't' => 0x09,
      'r' => 0x0D,
      'f' || 'v' || 'b' => 0x20,
      _ => null,
    };
    return value == null ? null : (value, j + 1);
  }

  /// An HTML tag, with up to 200 characters of attributes.
  static final RegExp _tag =
      RegExp(r'</?([A-Za-z][A-Za-z0-9]*)(?:\s[^<>]{0,200})?/?>');

  /// Tags that sit inside a word rather than between words.
  static const Set<String> _inlineTags = <String>{
    'a', 'abbr', 'b', 'em', 'font', 'i', 'mark', 's', 'small', 'span',
    'strong', 'sub', 'sup', 'u', 'wbr',
  };

  /// HTML entities that stand for a letter (Latin-1 and the French œ).
  static const Map<String, int> _letterEntities = {
    'Agrave': 0xC0, 'Aacute': 0xC1, 'Acirc': 0xC2, 'Atilde': 0xC3,
    'Auml': 0xC4, 'Aring': 0xC5, 'AElig': 0xC6, 'Ccedil': 0xC7,
    'Egrave': 0xC8, 'Eacute': 0xC9, 'Ecirc': 0xCA, 'Euml': 0xCB,
    'Igrave': 0xCC, 'Iacute': 0xCD, 'Icirc': 0xCE, 'Iuml': 0xCF, 'ETH': 0xD0,
    'Ntilde': 0xD1, 'Ograve': 0xD2, 'Oacute': 0xD3, 'Ocirc': 0xD4,
    'Otilde': 0xD5, 'Ouml': 0xD6, 'Oslash': 0xD8, 'Ugrave': 0xD9,
    'Uacute': 0xDA, 'Ucirc': 0xDB, 'Uuml': 0xDC, 'Yacute': 0xDD,
    'THORN': 0xDE, 'szlig': 0xDF, 'agrave': 0xE0, 'aacute': 0xE1,
    'acirc': 0xE2, 'atilde': 0xE3, 'auml': 0xE4, 'aring': 0xE5, 'aelig': 0xE6,
    'ccedil': 0xE7, 'egrave': 0xE8, 'eacute': 0xE9, 'ecirc': 0xEA,
    'euml': 0xEB, 'igrave': 0xEC, 'iacute': 0xED, 'icirc': 0xEE, 'iuml': 0xEF,
    'eth': 0xF0, 'ntilde': 0xF1, 'ograve': 0xF2, 'oacute': 0xF3,
    'ocirc': 0xF4, 'otilde': 0xF5, 'ouml': 0xF6, 'oslash': 0xF8,
    'ugrave': 0xF9, 'uacute': 0xFA, 'ucirc': 0xFB, 'uuml': 0xFC,
    'yacute': 0xFD, 'thorn': 0xFE, 'yuml': 0xFF, 'OElig': 0x152,
    'oelig': 0x153,
  };

  /// HTML entities for characters that sit invisibly inside a word.
  static const Set<String> _invisibleEntities = <String>{
    'shy', 'zwj', 'zwnj', 'ZeroWidthSpace', 'lrm', 'rlm', 'NoBreak',
  };

  /// Entities that browsers read without their semicolon.
  static const Map<String, int> _bareEntities = {
    'nbsp': 0x20, 'amp': 0x26, 'lt': 0x3C, 'gt': 0x3E, 'quot': 0x22,
  };

  static final RegExp _namedEntity =
      RegExp(r'&([A-Za-z][A-Za-z0-9]{1,31})(;?)');
  static final RegExp _numericEntity =
      RegExp(r'&#(?:[xX]([0-9a-fA-F]{1,6})|([0-9]{1,7}));?');

  /// An HTML entity at [i]: what it stands for and the offset after it.
  /// A letter's entity is the letter, an invisible one is dropped, any
  /// other named one separates words.
  static (int, int)? _entity(String text, int i) {
    final numeric = _numericEntity.matchAsPrefix(text, i);
    if (numeric != null) {
      final value = numeric[1] != null
          ? int.parse(numeric[1]!, radix: 16)
          : int.parse(numeric[2]!);
      return value > 0x10FFFF ? null : (value, numeric.end);
    }
    final named = _namedEntity.matchAsPrefix(text, i);
    if (named == null) return null;
    final name = named[1]!;
    if (named[2]!.isEmpty) {
      // No semicolon: only the few names browsers read bare, which the
      // next word may follow directly ("&nbspability").
      final lower = name.toLowerCase();
      for (final MapEntry(key: bare, value: value) in _bareEntities.entries) {
        if (lower.startsWith(bare)) return (value, i + 1 + bare.length);
      }
      return null;
    }
    final letter = _letterEntities[name];
    if (letter != null) return (letter, named.end);
    if (_invisibleEntities.contains(name)) return (0x200B, named.end);
    return switch (name.toLowerCase()) {
      'amp' => (0x26, named.end),
      'lt' => (0x3C, named.end),
      'gt' => (0x3E, named.end),
      'quot' => (0x22, named.end),
      'apos' => (0x27, named.end),
      'newline' => (0x0A, named.end),
      _ => (0x20, named.end),
    };
  }

  static bool _ignored(int r) =>
      r == 0x034F || // combining grapheme joiner
      r == 0x180E || // Mongolian vowel separator
      (r >= 0x200B && r <= 0x200F) ||
      r == 0x2060 ||
      r == 0xFEFF ||
      r == 0x00AD ||
      (r >= 0xFE00 && r <= 0xFE0F) ||
      (r >= 0xE0100 && r <= 0xE01EF);

  static int? _hex(String text, int from, int count) {
    if (from + count > text.length) return null;
    final s = text.substring(from, from + count);
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(s)) return null;
    return int.parse(s, radix: 16);
  }

  static const Map<String, String> _ligatures = {
    '\uFB00': 'ff', '\uFB01': 'fi', '\uFB02': 'fl', '\uFB03': 'ffi',
    '\uFB04': 'ffl', '\uFB05': 'st', '\uFB06': 'st',
  };

  /// Consecutive `%XX` escapes at [i] decoded as UTF-8: each code point
  /// with its range. Empty when there is none, and the decoding stops at
  /// the first byte that is not valid UTF-8.
  static List<(int, int, int)> _percentEscapes(String text, int i) {
    final out = <(int, int, int)>[];
    // `%u516B`, as JavaScript's escape() writes non-ASCII.
    if (i + 1 < text.length && (text[i + 1] == 'u' || text[i + 1] == 'U')) {
      final unit = _hex(text, i + 2, 4);
      if (unit != null) return [(unit, i, i + 6)];
    }
    var at = i;
    int? byteAt(int k) =>
        k < text.length && text.codeUnitAt(k) == 0x25 ? _hex(text, k + 1, 2) : null;
    while (true) {
      final lead = byteAt(at);
      if (lead == null) break;
      final int length;
      int value;
      if (lead < 0x80) {
        length = 1;
        value = lead;
      } else if (lead >= 0xC2 && lead <= 0xDF) {
        length = 2;
        value = lead & 0x1F;
      } else if (lead >= 0xE0 && lead <= 0xEF) {
        length = 3;
        value = lead & 0x0F;
      } else if (lead >= 0xF0 && lead <= 0xF4) {
        length = 4;
        value = lead & 0x07;
      } else {
        break;
      }
      var ok = true;
      for (var k = 1; k < length; k++) {
        final b = byteAt(at + 3 * k);
        if (b == null || (b & 0xC0) != 0x80) {
          ok = false;
          break;
        }
        value = (value << 6) | (b & 0x3F);
      }
      // Well-formed UTF-8 only: no overlong forms, surrogates or values
      // past U+10FFFF (%F4%90%80%80 once made String.fromCharCodes throw).
      const minimum = <int>[0, 0, 0x80, 0x800, 0x10000];
      if (!ok ||
          value < minimum[length] ||
          value > 0x10FFFF ||
          (value >= 0xD800 && value <= 0xDFFF)) {
        break;
      }
      out.add((value, at, at + 3 * length));
      at += 3 * length;
    }
    return out;
  }
}
