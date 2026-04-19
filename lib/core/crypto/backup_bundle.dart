import 'bip39_english_wordlist.dart';

/// Serialization wrapper for a backup export — pairs the LPR wire (the
/// encrypted package) and the 8 PAKE words in a single plain-text blob
/// suitable for sharing via platform share-sheets and re-importing via
/// the file-picker flow.
///
/// Format (strict minimum, extra lines ignored):
/// ```
/// # Signet backup · ${peerLabel} · ${generatedAt}
/// signet:tp1:<base64url>
/// <word1> <word2> <word3> <word4> <word5> <word6> <word7> <word8>
/// ```
///
/// - Lines starting with `#` are comments (ignored on parse).
/// - Blank lines are ignored.
/// - The first non-comment line starting with `signet:tp1:` is taken as
///   the wire; extra such lines are ignored.
/// - The first non-comment line that tokenizes to exactly 8 BIP-39
///   English wordlist entries (whitespace-separated) is taken as the PAKE.
///
/// Keeping the grammar this loose means a user who edits the file in a
/// text editor and accidentally adds a title line or a blank line
/// doesn't break the re-import.
class BackupBundle {
  const BackupBundle({required this.wire, required this.pakeWords});

  final String wire;
  final List<String> pakeWords;

  /// Format a bundle for export. Both artifacts appear on separate
  /// lines; a header comment carries the peer label + timestamp for
  /// human readability.
  static String format({
    required String peerLabel,
    required String wire,
    required List<String> pakeWords,
    required DateTime generatedAt,
  }) {
    final ts = '${generatedAt.toUtc().toIso8601String().split('.').first}Z';
    final header =
        '# Signet backup · $peerLabel · $ts\n'
        '# Keep the PAKE words on a different physical artifact '
        'than this package.\n';
    return '$header'
        '$wire\n'
        '${pakeWords.join(' ')}\n';
  }

  /// Parse a bundle from its serialized form. Throws [FormatException]
  /// if either the wire line or the PAKE-word line cannot be found.
  static BackupBundle parse(String text) {
    String? wire;
    List<String>? pake;
    final wordSet = bip39EnglishWordlist.toSet();

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) continue;
      if (wire == null && line.startsWith('signet:tp1:')) {
        wire = line;
        continue;
      }
      if (pake == null) {
        final tokens = line
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty)
            .toList();
        if (tokens.length == 8 && tokens.every(wordSet.contains)) {
          pake = tokens;
          continue;
        }
      }
      if (wire != null && pake != null) break;
    }
    if (wire == null) {
      throw const FormatException(
        'Bundle is missing a "signet:tp1:..." wire line.',
      );
    }
    if (pake == null) {
      throw const FormatException(
        'Bundle is missing a line of 8 BIP-39 PAKE words.',
      );
    }
    return BackupBundle(wire: wire, pakeWords: pake);
  }
}
