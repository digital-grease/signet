import '../crypto/bip39_english_wordlist.dart';

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
///   - Base64-like strings ≥ 16 chars (transport-package bodies).
///   - The literal `signet:tp1:` transport-wire prefix.
///   - 4-tuple and 8-tuple clusters of BIP-39 words (verify codes and
///     PAKE words). Single BIP-39 words pass through — "above", "abandon",
///     "able" are common English and a 1-word match doesn't carry secret bits.
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
    return input.split('\n').map(_scrubLine).join('\n');
  }

  // ===========================================================================
  // Per-line pipeline
  // ===========================================================================

  static String _scrubLine(String line) {
    if (line.isEmpty) return line;
    line = _forcedRedactMechanical(line);
    line = _redactBip39Clusters(line);
    line = _redactQuotedContent(line);
    line = _tokenLevelRedact(line);
    return line;
  }

  // ===========================================================================
  // Mechanical redact patterns (100% bar)
  // ===========================================================================

  // signet:tp1: + base64url body — catastrophic if leaked. Order matters:
  // run this before the base64 regex so the prefix and body are redacted as
  // one unit with the recognizable length.
  static final _wirePrefixPattern =
      RegExp(r'signet:tp1:[A-Za-z0-9+/_-]+={0,2}');

  // Hex run ≥ 16 chars — covers shared secrets, AEAD tags, HKDF outputs.
  static final _hexRunPattern = RegExp(r'\b[0-9a-fA-F]{16,}\b');

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

  static String _forcedRedactMechanical(String line) {
    line = line.replaceAllMapped(
      _wirePrefixPattern,
      (Match m) => _redactToken(m.group(0)!.length),
    );
    line = line.replaceAllMapped(
      _hexRunPattern,
      (Match m) => _redactToken(m.group(0)!.length),
    );
    line = line.replaceAllMapped(
      _base64RunPattern,
      (Match m) {
        final s = m.group(0)!;
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

  static final Set<String> _bip39Set = bip39EnglishWordlist.toSet();
  // Word: sequence of lowercase letters (BIP-39 words are all lowercase).
  // Word separator: whitespace or hyphen runs. The cluster detector treats
  // each match as a candidate word and checks ranges of ≥ 4 consecutive
  // BIP-39 matches separated only by whitespace/hyphen.
  static final RegExp _candidateWordPattern = RegExp(r'[A-Za-z]+');
  static final RegExp _bip39SeparatorPattern = RegExp(r'^[\s\-]+$');

  /// Find runs of ≥ 4 consecutive BIP-39 words separated by whitespace or
  /// hyphens; redact each word in any qualifying run. Single, double, or
  /// triple BIP-39 words are NOT redacted — they're common English and
  /// don't carry enough entropy to fingerprint a verify code or PAKE.
  static String _redactBip39Clusters(String line) {
    final matches = _candidateWordPattern.allMatches(line).toList();
    if (matches.length < 4) return line;

    // Mark each candidate word as BIP-39-or-not.
    final isBip39 = matches
        .map((m) => _bip39Set.contains(m.group(0)!.toLowerCase()))
        .toList();

    // Walk and find runs of BIP-39 words where adjacent words are separated
    // only by whitespace/hyphens (no other punctuation).
    final ranges = <List<int>>[]; // [startMatchIdx, endMatchIdxExclusive]
    var i = 0;
    while (i < matches.length) {
      if (!isBip39[i]) {
        i++;
        continue;
      }
      var runEnd = i + 1;
      while (runEnd < matches.length && isBip39[runEnd]) {
        final between = line.substring(
          matches[runEnd - 1].end,
          matches[runEnd].start,
        );
        if (!_bip39SeparatorPattern.hasMatch(between)) break;
        runEnd++;
      }
      if (runEnd - i >= 4) ranges.add(<int>[i, runEnd]);
      i = runEnd;
    }

    if (ranges.isEmpty) return line;

    // Rebuild line, redacting each ranged match.
    final buf = StringBuffer();
    var cursor = 0;
    for (final r in ranges) {
      for (var k = r[0]; k < r[1]; k++) {
        final m = matches[k];
        buf.write(line.substring(cursor, m.start));
        buf.write(_redactToken(m.end - m.start));
        cursor = m.end;
      }
    }
    buf.write(line.substring(cursor));
    return buf.toString();
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
    r'(?:package:[A-Za-z_][\w/\.]*|dart:[A-Za-z_][\w\.]*)',
  );

  static String _tokenLevelRedact(String line) {
    // Pre-compute the ranges of package/dart paths — identifiers inside
    // them get kept verbatim.
    final pathRanges = _packagePathRegionPattern
        .allMatches(line)
        .map((m) => <int>[m.start, m.end])
        .toList();

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
