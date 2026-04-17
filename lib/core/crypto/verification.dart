import 'package:cryptography/cryptography.dart';

import 'bip39_english_wordlist.dart';

/// Deterministic short-phrase derivation used during pairing to let both
/// devices visually confirm they derived the same shared secret. Given
/// identical shared secrets, both devices produce identical phrases;
/// any mismatch means a pairing failure or a man-in-the-middle.
///
/// The phrase is distinct from — and cannot be used as — the TOTP secret,
/// thanks to HKDF domain separation via [_hkdfInfo].
class PairingVerification {
  const PairingVerification._();

  static const int defaultWordCount = 4;
  static const int _bitsPerWord = 11;
  static const int _wordlistSize = 2048; // 2^11
  static const String _hkdfInfo = 'signet/v1/verification-phrase';

  static Future<List<String>> derivePhrase({
    required List<int> sharedSecret,
    int wordCount = defaultWordCount,
  }) async {
    if (sharedSecret.isEmpty) {
      throw ArgumentError.value(
        sharedSecret,
        'sharedSecret',
        'Shared secret must not be empty.',
      );
    }
    if (wordCount <= 0) {
      throw ArgumentError.value(
        wordCount,
        'wordCount',
        'Word count must be positive.',
      );
    }

    final totalBits = wordCount * _bitsPerWord;
    final outputBytes = (totalBits + 7) ~/ 8;

    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: outputBytes);
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(sharedSecret),
      nonce: const <int>[],
      info: _hkdfInfo.codeUnits,
    );
    final bytes = await derived.extractBytes();

    return _bytesToWords(bytes, wordCount);
  }

  static List<String> _bytesToWords(List<int> bytes, int wordCount) {
    final words = <String>[];
    var buffer = 0;
    var bits = 0;
    var cursor = 0;

    while (words.length < wordCount) {
      while (bits < _bitsPerWord && cursor < bytes.length) {
        buffer = (buffer << 8) | (bytes[cursor] & 0xFF);
        bits += 8;
        cursor++;
      }
      if (bits < _bitsPerWord) {
        // Defensive: HKDF output length is chosen above to always satisfy
        // the bit budget, so this branch should be unreachable.
        throw StateError('Insufficient entropy extracted for phrase.');
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
