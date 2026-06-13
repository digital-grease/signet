import '../models/relationship.dart';
import 'log_scrubber.dart';

/// Export-time scrubber for opt-in debug-session logs that are about to leave
/// the device for a **public** destination — the `debug_report.yml` GitHub
/// issue form, the OS share sheet, or the clipboard.
///
/// It does two jobs the at-rest [LogScrubber] does not:
///
///   1. **Pseudonymizes paired contacts.** The app knows its own relationship
///      ids and labels, so it redacts them by exact (escaped, word-bounded,
///      case-insensitive) match — far stronger than guessing at names. A
///      relationship's id and label collapse to the SAME stable `<peer-N>`
///      token, so the maintainer can still follow one contact through the log
///      ("`<peer-1>`'s verify failed 3 times then succeeded") without learning
///      who it is.
///   2. **Sweeps generic PII** (email / phone) as defense in depth.
///
/// **Pipeline order is load-bearing** (see `.devloop/spikes/debug-log-export.md`,
/// "Why this exact order"). Each step's position prevents a leak the Phase-8
/// red-team found:
///
///   1. **map IDS** — 32-hex [Relationship.id] → `<peer-N>`. Done FIRST so the
///      hex id is mapped before [LogScrubber] would redact it as a ≥16-char hex
///      run (which would erase `<peer-N>` correlation). Ids are full-length and
///      hex-bounded, so mapping them can never fragment an adjacent secret.
///   2. **secret scrub** — [LogScrubber.scrub]. Real secrets are `[redacted:N]`
///      after this, so the label sweep that follows cannot fragment one.
///   3. **label sweep** — labels → the same `<peer-N>`. Runs on already
///      secret-free text, so a label that is a BIP-39 word, a `tp1`-ish string,
///      or a base64 substring can't break secret detection.
///   4. **PII sweep** — email + phone.
///
/// Reversing any adjacent pair re-introduces a leak; the ordering test in
/// `test/logging/debug_log_export_scrubber_test.dart` pins it.
///
/// Pure function — no I/O, no Flutter dependency. Unit-testable in isolation.
class DebugLogExportScrubber {
  const DebugLogExportScrubber._();

  /// Scrub [rawLog] for public export. [relationships] is the full paired set,
  /// used to build the id/label → `<peer-N>` pseudonym map.
  static String scrub(String rawLog, List<Relationship> relationships) {
    if (rawLog.isEmpty) return rawLog;

    // Stable, deterministic peer index: order by id so the same input always
    // yields the same tokens regardless of store iteration order.
    final ordered = <Relationship>[...relationships]
      ..sort((a, b) => a.id.compareTo(b.id));
    final tokenById = <String, String>{};
    for (var i = 0; i < ordered.length; i++) {
      tokenById[ordered[i].id] = '<peer-${i + 1}>';
    }

    var out = rawLog;
    out = _mapIds(out, ordered, tokenById); // 1
    out = LogScrubber.scrub(out); // 2
    out = _sweepLabels(out, ordered, tokenById); // 3
    out = _sweepPii(out); // 4
    return out;
  }

  // ===========================================================================
  // Step 1 — map ids (hex-bounded, before the secret scrub)
  // ===========================================================================

  static String _mapIds(
    String input,
    List<Relationship> ordered,
    Map<String, String> tokenById,
  ) {
    var out = input;
    // Longest id first (defensive; ids are a fixed 32 chars today, so this is a
    // no-op ordering — but it keeps the contract explicit if id length ever
    // changes).
    final byLenDesc = <Relationship>[...ordered]
      ..sort((a, b) => b.id.length.compareTo(a.id.length));
    for (final rel in byLenDesc) {
      if (rel.id.isEmpty) continue;
      // Hex-bounded so we only match a STANDALONE id, never a slice of a longer
      // hex run (which would carve a hole in a secret).
      final pattern = RegExp(
        '(?<![0-9a-fA-F])${_escape(rel.id)}(?![0-9a-fA-F])',
        caseSensitive: false,
      );
      out = out.replaceAll(pattern, tokenById[rel.id]!);
    }
    return out;
  }

  // ===========================================================================
  // Step 3 — label backstop sweep (on already secret-free text)
  // ===========================================================================

  static String _sweepLabels(
    String input,
    List<Relationship> ordered,
    Map<String, String> tokenById,
  ) {
    var out = input;
    // Unique labels, longest first, so "Mom Smith" is consumed before "Mom"
    // and a shorter label can't partially eat a longer one.
    final seen = <String>{};
    final byLenDesc = <Relationship>[...ordered]
      ..sort((a, b) => b.label.length.compareTo(a.label.length));
    for (final rel in byLenDesc) {
      final label = rel.label;
      if (label.trim().isEmpty || !seen.add(label)) continue;
      out = out.replaceAll(_labelPattern(label), tokenById[rel.id]!);
    }
    return out;
  }

  /// Build a leak-proof matcher for a user-chosen [label]:
  ///   - regex metacharacters escaped (labels are free text: `Mom (primary)`)
  ///   - internal whitespace compiled as `\s+`, so a wrapped `Finance\nTeam`
  ///     still matches
  ///   - word-boundary lookarounds on alphanumerics, so `Mom's` / `Mom,` redact
  ///     but `MomCare` does not over-match
  ///   - case-insensitive + unicode, so `José` / `JOSÉ` (precomposed) collapse
  static RegExp _labelPattern(String label) {
    final tokens = label.trim().split(RegExp(r'\s+'));
    final body = tokens.map(_escape).join(r'\s+');
    return RegExp(
      '(?<![A-Za-z0-9])$body(?![A-Za-z0-9])',
      caseSensitive: false,
      unicode: true,
    );
  }

  // ===========================================================================
  // Step 4 — PII sweep (defense in depth)
  // ===========================================================================

  static final RegExp _emailPattern =
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b');

  // Optional leading +, then a run of digits and common separators. Bounded by
  // non-digits so it doesn't bite into a longer number. A post-match digit
  // count (7–15) decides whether it's actually a phone — keeps "1 2 3" and
  // long decimal ids out of the redactor (long decimal runs are already caught
  // by LogScrubber's base64≥16 pass in step 2).
  static final RegExp _phonePattern =
      RegExp(r'(?<!\d)\+?\d[\d\s().-]{5,15}\d(?!\d)');

  static String _sweepPii(String input) {
    var out = input.replaceAll(_emailPattern, '[redacted-email]');
    out = out.replaceAllMapped(_phonePattern, (m) {
      final digits = m.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 7 || digits.length > 15) return m.group(0)!;
      return '[redacted-phone]';
    });
    return out;
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  /// Escape the 12 regex metacharacters so a label/id is matched as a literal.
  /// (`RegExp.escape` is not available across our whole SDK toolchain, so we
  /// hand-roll per the spike.) Deliberately excludes `-` and `/`: neither is a
  /// metacharacter outside a character class, and `\-` is an *invalid* identity
  /// escape under `unicode: true` — escaping it would throw on a hyphenated
  /// label like `co-op`.
  static final RegExp _metachars = RegExp(r'[.?*+^$()\[\]{}|\\]');
  static String _escape(String s) =>
      s.replaceAllMapped(_metachars, (m) => '\\${m.group(0)}');
}
