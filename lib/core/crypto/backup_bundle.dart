import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart' show visibleForTesting;

import 'bip39_english_wordlist.dart';

/// Decode the bytes of a backup file as UTF-8 text. Dart's UTF-8 decoder
/// drops a leading byte order mark (some editors add one), and invalid
/// sequences are replaced rather than failing: the parser only needs the
/// ASCII wire and the BIP-39 words, so stray bytes elsewhere must not
/// block a restore. (Decoding as Latin-1, as before, turned a BOM into
/// three junk characters glued to the first line.)
String decodeBackupText(List<int> bytes) =>
    utf8.decode(bytes, allowMalformed: true);

// ==========================================================================
// Two-file backup (plan Phase 2): the package and its 8 words never travel
// in, or sit together in, one artifact.
// ==========================================================================

/// Formats for the two separate backup files. Headers are English on
/// purpose: the files must read the same whatever language the exporting
/// phone uses, and they carry no contact name (the package file will live
/// in the less-trusted place).
///
/// PACKAGE file:
/// ```
/// # Signet backup PACKAGE · 2026-10-08T12:00:00Z
/// # Fingerprint: 123 456
/// # This file does NOT contain the 8 words. ...
/// signet:tp1:<base64url>
/// # end of package
/// ```
///
/// WORDS file:
/// ```
/// # Signet backup WORDS · 2026-10-08T12:00:00Z
/// # Fingerprint: 123 456
/// # Keep this apart from the PACKAGE file. ...
/// word1 word2 word3 word4 word5 word6 word7 word8
/// ```
///
/// The fingerprint lets someone holding several backups match a words file
/// to its package. It is derived from the package's decoded bytes (already
/// ciphertext), never from the words, so it reveals nothing about either.
class BackupFiles {
  const BackupFiles._();

  static const String endOfPackageMarker = '# end of package';
  static const String _wirePrefix = 'signet:tp1:';

  static String formatPackage({
    required String wire,
    required String fingerprint,
    required DateTime generatedAt,
  }) =>
      '# Signet backup PACKAGE · ${_timestamp(generatedAt)}\n'
      '# Fingerprint: $fingerprint\n'
      '# This file does NOT contain the 8 words. You need both to restore.\n'
      '# Keep it somewhere different from the words.\n'
      '$wire\n'
      '$endOfPackageMarker\n';

  static String formatWords({
    required List<String> pakeWords,
    required String fingerprint,
    required DateTime generatedAt,
  }) =>
      '# Signet backup WORDS · ${_timestamp(generatedAt)}\n'
      '# Fingerprint: $fingerprint\n'
      '# Keep this apart from the PACKAGE file. Anyone who has both can\n'
      '# restore your pairings. Paper in a safe place is best.\n'
      '${pakeWords.join(' ')}\n';

  /// File names: date and fingerprint only, never a contact name.
  static String packageFileName(DateTime generatedAt, String fingerprint) =>
      'signet-backup-${_date(generatedAt)}-${fingerprint.replaceAll(' ', '')}'
      '-PACKAGE.txt';

  static String wordsFileName(DateTime generatedAt, String fingerprint) =>
      'signet-backup-${_date(generatedAt)}-${fingerprint.replaceAll(' ', '')}'
      '-WORDS.txt';

  /// Six-digit fingerprint ("123 456") of a `signet:tp1:` wire, computed
  /// over its decoded body bytes so line wrapping or padding in the text
  /// form never changes it. Returns null for a wire that is not valid
  /// base64url.
  static Future<String?> fingerprint(String wire) async {
    final List<int> body;
    try {
      body = _decodeBody(wire);
    } on FormatException {
      return null;
    }
    final hash = await Sha256().hash(body);
    final b = hash.bytes;
    final n = ((b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]) % 1000000;
    final digits = n.toString().padLeft(6, '0');
    return '${digits.substring(0, 3)} ${digits.substring(3)}';
  }

  static List<int> _decodeBody(String wire) {
    if (!wire.startsWith(_wirePrefix)) {
      throw const FormatException('Not a signet:tp1: wire.');
    }
    final encoded = wire.substring(_wirePrefix.length);
    final padding = (4 - encoded.length % 4) % 4;
    return base64Url.decode(encoded + '=' * padding);
  }

  static String _timestamp(DateTime t) =>
      '${t.toUtc().toIso8601String().split('.').first}Z';

  static String _date(DateTime t) =>
      t.toUtc().toIso8601String().substring(0, 10);
}

/// Everything recognisable in a piece of backup text: a PACKAGE file, a
/// WORDS file, an old combined bundle, or text pasted from any of those.
class BackupText {
  const BackupText._({
    required this.wireCandidates,
    required this.pakeWords,
    required this.declaredFingerprint,
    required this.hasEndMarker,
  });

  /// Possible package wires, longest first. A package line that an email
  /// client wrapped is rejoined; without the end-of-package marker (old
  /// files) the join can be ambiguous, so shorter joins follow as
  /// fallbacks for the caller to try. Empty when the text has no package.
  final List<String> wireCandidates;

  /// The 8 words: a line of exactly 8 BIP-39 words, or else exactly 8
  /// wordlist words spread over the non-package lines.
  final List<String>? pakeWords;

  /// The fingerprint written in a `# Fingerprint:` header, if any.
  final String? declaredFingerprint;

  /// True for the two-file format's package (and its rejoin is exact).
  final bool hasEndMarker;

  String? get wire => wireCandidates.isEmpty ? null : wireCandidates.first;

  /// An old single-file bundle holding both the package and the words.
  bool get isLegacyCombined => wireCandidates.isNotEmpty && pakeWords != null;

  static final RegExp _base64UrlChunk = RegExp(r'^[A-Za-z0-9_-]+$');
  static final RegExp _fingerprintLine =
      RegExp(r'^#\s*Fingerprint:\s*(\d{3})\s?(\d{3})\s*$');

  static BackupText read(String text) {
    final wordSet = bip39EnglishWordlist.toSet();
    final lines =
        text.split(RegExp(r'\r\n|\r|\n')).map((l) => l.trim()).toList();

    List<String>? pake;
    String? fingerprint;
    var hasMarker = false;
    final candidates = <String>[];
    // Letter-only tokens from every line that is neither a comment nor
    // part of the package, for words kept one per line or numbered.
    final looseTokens = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      final fp = _fingerprintLine.firstMatch(line);
      if (fp != null) {
        fingerprint ??= '${fp.group(1)} ${fp.group(2)}';
        continue;
      }
      if (line.startsWith('#')) continue;
      if (candidates.isEmpty && line.startsWith(BackupFiles._wirePrefix)) {
        // Rejoin continuation lines a mail client may have wrapped.
        final parts = <String>[line];
        var j = i + 1;
        var sawMarker = false;
        for (; j < lines.length; j++) {
          final next = lines[j];
          if (next == BackupFiles.endOfPackageMarker) {
            sawMarker = true;
            break;
          }
          if (next.isEmpty || next.startsWith('#')) break;
          if (!_base64UrlChunk.hasMatch(next)) break;
          // Without the marker, a lone wordlist word may be the start of
          // the words line rather than part of the package.
          parts.add(next);
        }
        hasMarker = sawMarker;
        if (sawMarker) {
          candidates.add(parts.join());
        } else {
          // Old format: offer every prefix join, longest first.
          for (var k = parts.length; k >= 1; k--) {
            candidates.add(parts.sublist(0, k).join());
          }
        }
        i = j - 1;
        continue;
      }
      looseTokens.addAll(line
          .toLowerCase()
          .split(RegExp(r'[^a-z]+'))
          .where((t) => t.isNotEmpty));
      if (pake == null) {
        final tokens = line
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty)
            .toList();
        if (tokens.length == 8 && tokens.every(wordSet.contains)) {
          pake = tokens;
        }
      }
    }
    // No single line held the words: accept them spread over several lines
    // ("1. abandon", one per line, comma-separated) when exactly 8 words
    // turn up and all are wordlist words.
    if (pake == null &&
        looseTokens.length == 8 &&
        looseTokens.every(wordSet.contains)) {
      pake = looseTokens;
    }
    return BackupText._(
      wireCandidates: List.unmodifiable(candidates),
      pakeWords: pake,
      declaredFingerprint: fingerprint,
      hasEndMarker: hasMarker,
    );
  }
}

/// The old single-file backup format (v0.3.6 and earlier): a header, the
/// package wire and the 8 words in one artifact. Signet no longer writes
/// it ([BackupFiles] replaced it, bug S1) and reads it through
/// [BackupText.read]. Kept so tests can build legacy fixtures.
///
/// ```
/// # Signet backup · ${peerLabel} · ${generatedAt}
/// signet:tp1:<base64url>
/// <word1> <word2> <word3> <word4> <word5> <word6> <word7> <word8>
/// ```
abstract final class LegacyBackupBundle {
  @visibleForTesting
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
}
