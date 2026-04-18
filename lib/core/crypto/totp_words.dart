import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'bip39_english_wordlist.dart';
import 'pair_role.dart';

/// Rotating 4-word verification code derived from the pairing shared secret.
///
/// Signet's defining UX is a stressed human comparing cryptographic material
/// over a voice channel. BIP-39 words (phonetically distinct by design)
/// survive that channel dramatically better than 8 decimal digits, and 4
/// words encode ~44 bits vs. ~27 for 8 digits — safer against blind-bluff
/// attacks on a rate-limitless protocol.
///
/// Derivation: HKDF-SHA-256 keyed by the shared TOTP secret, with
///   - `nonce` = the 8-byte big-endian TOTP window counter (floor(unix/30))
///   - `info`  = role-suffixed domain tag (`signet/v1/totp-words-from-a`
///     or `...-from-b`) so A's code and B's code differ for the same
///     window. This binds each rotating code to a direction: the caller
///     (Bob) emits codes using his role; the verifier (Alice) checks
///     against the *other* role. An attacker reflecting the verifier's
///     own displayed words back at her fails immediately.
///   - All info strings are domain-separated from the pair-time
///     verification phrase (see `verification.dart`, which uses
///     `signet/v1/verification-phrase`), so the 4 pair-time words are
///     never reproduced as a TOTP-words window.
///
/// Pure function. No Flutter imports. Unit-testable.
class TotpWords {
  const TotpWords._();

  static const int defaultTimeStepSeconds = 30;
  static const int defaultWordCount = 4;
  static const int defaultWindowTolerance = 1;

  static const int _bitsPerWord = 11;
  static const int _wordlistSize = 2048;

  static String _hkdfInfoFor(PairRole role) =>
      'signet/v1/totp-words-from-${role.wireName}';

  /// Derive the 4-word code that [senderRole] should read aloud in the
  /// window containing [unixTimeSeconds]. Each role has a distinct code
  /// for any given window — see class docs for why.
  static Future<List<String>> generate({
    required List<int> secret,
    required int unixTimeSeconds,
    required PairRole senderRole,
    int timeStepSeconds = defaultTimeStepSeconds,
    int wordCount = defaultWordCount,
  }) async {
    _validateInputs(
      secret: secret,
      wordCount: wordCount,
      timeStepSeconds: timeStepSeconds,
    );
    final counter = unixTimeSeconds ~/ timeStepSeconds;
    return _derive(
      secret: secret,
      counter: counter,
      wordCount: wordCount,
      senderRole: senderRole,
    );
  }

  /// Verify [candidate] as the words the caller (who holds role
  /// [senderRole]) should be reading this window. Walks ±[windowTolerance]
  /// windows. Case-insensitive; any candidate word not in the BIP-39
  /// wordlist is an automatic fail. Constant-time per-window compare over
  /// word indexes.
  ///
  /// Reflection-attack note: callers MUST pass their counterparty's role
  /// here, not their own. `Alice.verify(..., senderRole: bobRole)` checks
  /// that the spoken candidate matches what Bob *should* have said.
  /// Passing her OWN role would accept the words she just displayed — the
  /// exact failure mode we're preventing.
  static Future<bool> verify({
    required List<int> secret,
    required List<String> candidate,
    required int unixTimeSeconds,
    required PairRole senderRole,
    int timeStepSeconds = defaultTimeStepSeconds,
    int wordCount = defaultWordCount,
    int windowTolerance = defaultWindowTolerance,
  }) async {
    _validateInputs(
      secret: secret,
      wordCount: wordCount,
      timeStepSeconds: timeStepSeconds,
    );
    if (windowTolerance < 0) {
      throw ArgumentError.value(
        windowTolerance,
        'windowTolerance',
        'must not be negative',
      );
    }
    if (candidate.length != wordCount) return false;

    final candidateIndexes = <int>[];
    for (final word in candidate) {
      final idx = _wordIndex[word.trim().toLowerCase()];
      if (idx == null) return false;
      candidateIndexes.add(idx);
    }

    final baseCounter = unixTimeSeconds ~/ timeStepSeconds;
    for (var offset = -windowTolerance; offset <= windowTolerance; offset++) {
      final expected = await _derive(
        secret: secret,
        counter: baseCounter + offset,
        wordCount: wordCount,
        senderRole: senderRole,
      );
      final expectedIndexes = <int>[
        for (final w in expected) _wordIndex[w]!,
      ];
      if (_constantTimeEqualsInts(candidateIndexes, expectedIndexes)) {
        return true;
      }
    }
    return false;
  }

  static void _validateInputs({
    required List<int> secret,
    required int wordCount,
    required int timeStepSeconds,
  }) {
    if (secret.isEmpty) {
      throw ArgumentError.value(secret, 'secret', 'must not be empty');
    }
    if (wordCount <= 0) {
      throw ArgumentError.value(wordCount, 'wordCount', 'must be positive');
    }
    if (timeStepSeconds <= 0) {
      throw ArgumentError.value(
        timeStepSeconds,
        'timeStepSeconds',
        'must be positive',
      );
    }
  }

  static Future<List<String>> _derive({
    required List<int> secret,
    required int counter,
    required int wordCount,
    required PairRole senderRole,
  }) async {
    final counterBytes = _encodeCounter(counter);
    final totalBits = wordCount * _bitsPerWord;
    final outputBytes = (totalBits + 7) ~/ 8;
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: outputBytes);
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(secret),
      nonce: counterBytes,
      info: _hkdfInfoFor(senderRole).codeUnits,
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
        throw StateError('Insufficient entropy extracted for TOTP words.');
      }
      final shift = bits - _bitsPerWord;
      final index = (buffer >> shift) & (_wordlistSize - 1);
      words.add(bip39EnglishWordlist[index]);
      buffer &= (1 << shift) - 1;
      bits = shift;
    }
    return words;
  }

  static Uint8List _encodeCounter(int counter) {
    final bytes = Uint8List(8);
    var value = counter;
    for (var i = 7; i >= 0; i--) {
      bytes[i] = value & 0xFF;
      value >>= 8;
    }
    return bytes;
  }

  static bool _constantTimeEqualsInts(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static final Map<String, int> _wordIndex = <String, int>{
    for (var i = 0; i < bip39EnglishWordlist.length; i++)
      bip39EnglishWordlist[i]: i,
  };
}
