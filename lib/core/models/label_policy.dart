import 'dart:convert';

import 'package:characters/characters.dart';

/// Why a label was refused. The UI turns this into localized text (see
/// `lib/shared/label_text.dart`).
enum LabelRejection {
  /// Nothing but whitespace (or invisible characters).
  empty,

  /// Contains a `signet:tp1:` package fragment.
  looksLikeData,

  /// A pure hex string of 16+ characters, shaped like a key.
  looksLikeKey,

  /// Longer than [LabelPolicy.maxBytes] UTF-8 bytes.
  tooLong,
}

/// Policy for user-chosen relationship labels (Phase-8 decision #17, plan
/// Task 3.6).
///
/// Rejects labels that would defeat the debug-log export scrubber's correlation
/// guarantee: a label that is itself secret-shaped — a `signet:tp1:` wire
/// fragment, or a pure ≥16-char hex string — would be caught by the export
/// scrubber's secret-scrub pass and redacted to `[redacted:N]` instead of
/// mapped to a stable `<peer-N>` token. That never *leaks* the name, but it
/// loses correlation. Rejecting such labels at input keeps every label on the
/// pseudonymization path.
///
/// Also caps labels at [maxBytes] UTF-8 bytes, the most a backup can carry,
/// so every saved contact can be backed up.
///
/// This is a thin, UI-facing validator. It is deliberately NOT enforced inside
/// `Relationship.fresh`, because that factory is also used to mint throwaway
/// ids (see `bulk_backup_import_screen`) and to rehydrate restored
/// relationships, neither of which should be policed here.
class LabelPolicy {
  const LabelPolicy._();

  /// The longest label a backup (LPR/BLK record) can carry, in UTF-8 bytes.
  static const int maxBytes = 64;

  static final RegExp _pureHex16Plus = RegExp(r'^[0-9a-fA-F]{16,}$');

  /// Control characters (C0, DEL, C1), the bidirectional formatting
  /// characters that can reorder how a name displays (LRE..RLO, LRI..PDI,
  /// LRM/RLM, ALM), zero-width space and no-break characters, line and
  /// paragraph separators, characters that render as nothing (soft hyphen,
  /// combining grapheme joiner, Mongolian vowel separator, Hangul fillers)
  /// and Unicode tag characters (which also turns a subdivision flag such as
  /// England's into a plain black flag; accepted). U+115F/U+1160 are
  /// archaic Hangul fillers, removed because they render as nothing in a
  /// modern name. ZWNJ and ZWJ (U+200C, U+200D) are handled separately:
  /// see [_strayJoiner].
  static final RegExp _invisible = RegExp(
    '[\u0000-\u001F\u007F-\u009F\u00AD\u034F\u061C\u115F\u1160'
    '\u180E\u200B\u200E\u200F\u2028-\u202E\u2060-\u2069\u3164'
    '\uFEFF\uFFA0\u{E0000}-\u{E007F}]',
    unicode: true,
  );

  /// [raw] with invisible and direction-changing characters removed, runs
  /// of whitespace collapsed to one space, and the ends trimmed. Apply to
  /// any label that came from outside: typed, pasted, or received in a
  /// long-distance pairing package.
  /// ZWNJ/ZWJ next to an ASCII character or at either end. Between two
  /// non-ASCII characters they shape Persian and join emoji and stay; next
  /// to ASCII they only make "Mom" and "Mom" + ZWJ look identical.
  static final RegExp _strayJoiner = RegExp(
    '^[\u200C\u200D]+|[\u200C\u200D]+\$'
    '|(?<=[\u0000-\u007F])[\u200C\u200D]+'
    '|[\u200C\u200D]+(?=[\u0000-\u007F])',
  );

  static String clean(String raw) => raw
      // Line breaks and tabs separate words: keep them as spaces.
      .replaceAll(RegExp('[\t\n\r\u2028\u2029]'), ' ')
      .replaceAll(_invisible, '')
      .replaceAll(_strayJoiner, '')
      .replaceAll(RegExp(' {2,}'), ' ')
      .trim();

  /// Why [label] cannot be used, or null if it is allowed. Checks the
  /// [clean]ed label.
  static LabelRejection? check(String label) {
    final cleaned = clean(label);
    if (cleaned.isEmpty) return LabelRejection.empty;
    if (cleaned.toLowerCase().contains('signet:tp1:')) {
      return LabelRejection.looksLikeData;
    }
    if (_pureHex16Plus.hasMatch(cleaned)) return LabelRejection.looksLikeKey;
    if (utf8.encode(cleaned).length > maxBytes) return LabelRejection.tooLong;
    return null;
  }

  /// A label restored from a backup: [clean]ed, or [fallback] when the
  /// saved one is unusable (empty, data-shaped, or from a version before
  /// these rules).
  static String forRestore(String raw, String fallback) {
    final cleaned = clean(raw);
    return check(cleaned) == null ? cleaned : fallback;
  }

  /// [label] followed by [suffix], with [label] shortened so the result
  /// stays within [maxBytes].
  static String withSuffix(String label, String suffix) =>
      '${truncateToBytes(label, maxBytes - utf8.encode(suffix).length).trimRight()}'
      '$suffix';

  /// [text] cut to at most [bytes] UTF-8 bytes, at a whole user-visible
  /// character (grapheme cluster), so an emoji, flag or accented letter is
  /// never split.
  static String truncateToBytes(String text, int bytes) {
    if (utf8.encode(text).length <= bytes) return text;
    final out = StringBuffer();
    var used = 0;
    for (final grapheme in text.characters) {
      final size = utf8.encode(grapheme).length;
      if (used + size > bytes) break;
      out.write(grapheme);
      used += size;
    }
    return out.toString();
  }

  /// Whether [label] is allowed as a relationship label.
  static bool isValid(String label) => check(label) == null;
}
