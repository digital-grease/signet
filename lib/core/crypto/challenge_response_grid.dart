import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'bip39_english_wordlist.dart';

/// Deterministic 8×8 challenge-response grid derived from a pair's
/// shared secret. Used as a fallback verification mode for when the
/// responder has no phone but can speak — the responder carries a
/// pre-printed paper copy of this grid; the challenger asks "what's
/// the answer for {row_label} × {col_label}?"; the responder reads
/// the 3-word cell content aloud; the challenger's phone independently
/// computes the same grid and compares.
///
/// Design decisions captured in `.devloop/spikes/challenge-response.md`
/// (Option B): 8 rows × 8 cols = 64 distinct challenges, 3 BIP-39 words
/// per answer cell (33 bits of entropy per query — blind-guess odds of
/// 1 in 8.5 billion), axis labels are all distinct BIP-39 words.
///
/// Derivation: HKDF-SHA-256 with two domain-separated info strings:
/// - `signet/v2/cr-axis-v1` — picks the 16 axis labels (8 row, 8 col)
///   with de-duplication. Each draw uses a fresh one-byte salt; if the
///   drawn word already collided, we advance the salt counter until we
///   get a new word. In practice collisions are rare (~6% across 16
///   draws from a 2048-word pool).
/// - `signet/v2/cr-grid-v1` — picks each cell's 3 words, salted by the
///   two-byte row/col coordinates. 5 output bytes per cell = 40 bits;
///   we consume 33 (3×11) for three words.
///
/// Not role-asymmetric — both paired devices derive the same grid. The
/// primary threat for this fallback mode is physical paper leak, which
/// role-asymmetry doesn't help against; reflection of the spoken
/// challenge doesn't gain the attacker anything either because the
/// challenger's app never *speaks* the answer (see spike).
class ChallengeResponseGrid {
  const ChallengeResponseGrid._({
    required this.rowLabels,
    required this.colLabels,
    required this.cells,
  });

  /// 8 distinct BIP-39 words. Challenger says "{rowLabel} × {colLabel}".
  final List<String> rowLabels;

  /// 8 distinct BIP-39 words; disjoint from [rowLabels].
  final List<String> colLabels;

  /// `cells[row][col]` is a `List<String>` of exactly [wordsPerCell]
  /// BIP-39 words — the answer the responder reads aloud.
  final List<List<List<String>>> cells;

  static const int rowCount = 8;
  static const int colCount = 8;
  static const int wordsPerCell = 3;
  static const int _wordlistSize = 2048;
  static const int _bitsPerWord = 11;
  static const int _cellOutputBytes = 5; // ≥ (3 × 11) / 8

  static const String _axisInfo = 'signet/v2/cr-axis-v1';
  static const String _gridInfo = 'signet/v2/cr-grid-v1';

  /// Build the grid deterministically from the pair's shared secret.
  static Future<ChallengeResponseGrid> derive(List<int> sharedSecret) async {
    if (sharedSecret.isEmpty) {
      throw ArgumentError.value(
        sharedSecret,
        'sharedSecret',
        'must not be empty',
      );
    }

    // Draw axis labels first (8 row + 8 col = 16 distinct words).
    final axisLabels = <String>[];
    final seen = <String>{};
    var saltCounter = 0;
    const maxAttempts = 256; // 16 target words × small collision allowance
    while (axisLabels.length < rowCount + colCount &&
        saltCounter < maxAttempts) {
      final raw = await _hkdf(
        sharedSecret: sharedSecret,
        info: _axisInfo,
        salt: <int>[saltCounter],
        outputBytes: 2,
      );
      final index = ((raw[0] << 8) | raw[1]) & (_wordlistSize - 1);
      final word = bip39EnglishWordlist[index];
      if (seen.add(word)) {
        axisLabels.add(word);
      }
      saltCounter++;
    }
    if (axisLabels.length < rowCount + colCount) {
      // Defensive — vanishingly unlikely with a 2048-word pool.
      throw StateError(
        'Could not draw $rowCount+$colCount distinct axis labels after '
        '$saltCounter attempts.',
      );
    }
    final rows = axisLabels.sublist(0, rowCount);
    final cols = axisLabels.sublist(rowCount, rowCount + colCount);

    // Draw cell contents — 8×8 = 64 cells × 3 words each.
    final cellGrid = <List<List<String>>>[];
    for (var row = 0; row < rowCount; row++) {
      final rowCells = <List<String>>[];
      for (var col = 0; col < colCount; col++) {
        final raw = await _hkdf(
          sharedSecret: sharedSecret,
          info: _gridInfo,
          salt: <int>[row, col],
          outputBytes: _cellOutputBytes,
        );
        rowCells.add(_unpackThreeWords(raw));
      }
      cellGrid.add(rowCells);
    }

    return ChallengeResponseGrid._(
      rowLabels: List<String>.unmodifiable(rows),
      colLabels: List<String>.unmodifiable(cols),
      cells: List<List<List<String>>>.unmodifiable(
        cellGrid.map((r) => List<List<String>>.unmodifiable(
              r.map(List<String>.unmodifiable),
            )),
      ),
    );
  }

  /// Return the 3-word answer for the challenge `{rowLabel} × {colLabel}`.
  /// Throws [ArgumentError] if either label isn't in the axis arrays.
  List<String> answerFor({
    required String rowLabel,
    required String colLabel,
  }) {
    final rowIndex = rowLabels.indexOf(rowLabel);
    if (rowIndex < 0) {
      throw ArgumentError.value(
        rowLabel,
        'rowLabel',
        'not in rowLabels',
      );
    }
    final colIndex = colLabels.indexOf(colLabel);
    if (colIndex < 0) {
      throw ArgumentError.value(
        colLabel,
        'colLabel',
        'not in colLabels',
      );
    }
    return cells[rowIndex][colIndex];
  }

  // ------------------------------------------------------------------

  static Future<List<int>> _hkdf({
    required List<int> sharedSecret,
    required String info,
    required List<int> salt,
    required int outputBytes,
  }) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: outputBytes);
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(sharedSecret),
      nonce: Uint8List.fromList(salt),
      info: info.codeUnits,
    );
    return derived.extractBytes();
  }

  /// Consume 33 bits from [raw] (≥ 5 bytes) as 3 × 11-bit BIP-39 indexes.
  /// Bit layout: top bit → bit 0, standard big-endian stream.
  static List<String> _unpackThreeWords(List<int> raw) {
    final words = <String>[];
    var buffer = 0;
    var bits = 0;
    var cursor = 0;
    while (words.length < wordsPerCell) {
      while (bits < _bitsPerWord && cursor < raw.length) {
        buffer = (buffer << 8) | (raw[cursor] & 0xFF);
        bits += 8;
        cursor++;
      }
      if (bits < _bitsPerWord) {
        throw StateError('Insufficient HKDF output for cell words.');
      }
      final shift = bits - _bitsPerWord;
      final index = (buffer >> shift) & (_wordlistSize - 1);
      words.add(bip39EnglishWordlist[index]);
      buffer &= (1 << shift) - 1;
      bits = shift;
    }
    return words;
  }
}
