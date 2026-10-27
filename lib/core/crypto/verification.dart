import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:meta/meta.dart' show visibleForTesting;

import 'wordlists.dart';

/// Argon2id cost for the in-person phrase (pairing-commitment spike, option
/// E: defence in depth on top of commit-then-reveal).
class PhraseKdfParams {
  const PhraseKdfParams({
    required this.memoryKiB,
    required this.iterations,
    this.parallelism = 1,
  });

  final int memoryKiB;
  final int iterations;
  final int parallelism;
}

/// Deterministic short-phrase derivation used during pairing to let both
/// devices visually confirm they derived the same shared secret. Given
/// identical inputs, both devices produce identical phrases; any mismatch
/// means a pairing failure or a man-in-the-middle.
///
/// Three derivations, domain-separated so one can never be replayed as
/// another:
///
///   - [derivePhrase] (v1): 4 words from the shared secret alone. Pairing
///     will no longer show it once the v2 flows land (plan Task 1.7e/1.7g);
///     the binding-phrase re-check keeps it, because it only needs both
///     phones' stored secrets to agree.
///   - [deriveInPersonPhrase] (v2, QR): 4 words, transcript-bound, through
///     Argon2id. Its MITM resistance comes from commit-then-reveal
///     ([PairingCommitment]); Argon2id multiplies the cost of any search.
///   - [deriveLongDistancePhrase] (v2, long distance): 8 words (88 bits,
///     the PAKE secret's strength), transcript-bound.
///
/// None of these can be used as the TOTP secret: HKDF info strings differ.
class PairingVerification {
  const PairingVerification._();

  static const int defaultWordCount = 4;
  static const int longDistanceWordCount = 8;
  static const int _bitsPerWord = 11;
  static const int _publicKeyLength = 32;
  static const int _nonceLength = 16;
  static const String _hkdfInfo = 'signet/v1/verification-phrase';
  static const String _inPersonInfo = 'signet/v2/verification-phrase/qr';
  static const String _longDistanceInfo = 'signet/v2/verification-phrase/ldp';
  static const String _transcriptDomain = 'signet/v2/transcript';

  /// Production Argon2id cost for the in-person phrase. OWASP's minimum
  /// Argon2id setting (19 MiB, 2 passes, 1 lane); about 0.1 s on a desktop
  /// and a target of about 0.5 s on a low-end phone (Task 1.7c measures).
  /// Changing it changes every in-person phrase: both phones must agree,
  /// so it is part of the wire protocol.
  static const PhraseKdfParams inPersonKdf =
      PhraseKdfParams(memoryKiB: 19456, iterations: 2);

  static Future<List<String>> derivePhrase({
    required List<int> sharedSecret,
    int wordCount = defaultWordCount,
    WordList? list,
  }) async {
    _checkSecret(sharedSecret);
    if (wordCount <= 0) {
      throw ArgumentError.value(
        wordCount,
        'wordCount',
        'Word count must be positive.',
      );
    }
    final bytes = await _hkdf(
      sharedSecret,
      salt: const <int>[],
      info: _hkdfInfo,
      length: _bytesFor(wordCount),
    );
    return _render(bytes, wordCount, list);
  }

  /// `SHA-256("signet/v2/transcript" || pub_low || pub_high || nonce)`: the
  /// two keys in byte order, so both phones compute the same value whichever
  /// key is theirs. [nonce] is Start's 16-byte commitment nonce in person and
  /// empty for long distance. Fixed field lengths make the layout
  /// unambiguous; the domain prefix keeps it apart from the commitment hash.
  static Future<Uint8List> transcriptSalt(
    List<int> keyX,
    List<int> keyY, [
    List<int> nonce = const <int>[],
  ]) async {
    _checkKey(keyX, 'keyX');
    _checkKey(keyY, 'keyY');
    if (nonce.isNotEmpty && nonce.length != _nonceLength) {
      throw ArgumentError.value(
        nonce.length,
        'nonce.length',
        'The transcript nonce must be empty or $_nonceLength bytes.',
      );
    }
    final xFirst = _compareBytes(keyX, keyY) <= 0;
    final hash = await Sha256().hash(<int>[
      ..._transcriptDomain.codeUnits,
      ...(xFirst ? keyX : keyY),
      ...(xFirst ? keyY : keyX),
      ...nonce,
    ]);
    return Uint8List.fromList(hash.bytes);
  }

  /// The 4-word phrase both phones compare after an in-person (QR) pairing
  /// or rekey: HKDF with the `qr` domain and the transcript salt (32 bytes,
  /// used as the Argon2id password), then Argon2id with the transcript salt
  /// as its salt and no secret or associated data, 6 output bytes, of which
  /// the top 44 bits (most significant first) pick the words. The cost is
  /// always [inPersonKdf]: both phones must use the same parameters, so
  /// production callers cannot override them.
  static Future<List<String>> deriveInPersonPhrase({
    required List<int> sharedSecret,
    required List<int> ownPublicKey,
    required List<int> peerPublicKey,
    required List<int> nonce,
    WordList? list,
  }) =>
      _deriveInPerson(
        sharedSecret: sharedSecret,
        ownPublicKey: ownPublicKey,
        peerPublicKey: peerPublicKey,
        nonce: nonce,
        params: inPersonKdf,
        list: list,
      );

  /// [deriveInPersonPhrase] with cheap Argon2id parameters, for tests that
  /// check properties rather than pinned vectors.
  @visibleForTesting
  static Future<List<String>> deriveInPersonPhraseWithParams({
    required List<int> sharedSecret,
    required List<int> ownPublicKey,
    required List<int> peerPublicKey,
    required List<int> nonce,
    required PhraseKdfParams params,
    WordList? list,
  }) =>
      _deriveInPerson(
        sharedSecret: sharedSecret,
        ownPublicKey: ownPublicKey,
        peerPublicKey: peerPublicKey,
        nonce: nonce,
        params: params,
        list: list,
      );

  static Future<List<String>> _deriveInPerson({
    required List<int> sharedSecret,
    required List<int> ownPublicKey,
    required List<int> peerPublicKey,
    required List<int> nonce,
    required PhraseKdfParams params,
    WordList? list,
  }) async {
    _checkSecret(sharedSecret);
    if (nonce.length != _nonceLength) {
      throw ArgumentError.value(
        nonce.length,
        'nonce.length',
        'The commitment nonce must be exactly $_nonceLength bytes.',
      );
    }
    final salt = await transcriptSalt(ownPublicKey, peerPublicKey, nonce);
    final ikm = await _hkdf(
      sharedSecret,
      salt: salt,
      info: _inPersonInfo,
      length: 32,
    );
    // Pure Dart on purpose (project convention; no platform crypto). One
    // helper isolate, pinned rather than left to the library default, keeps
    // the ~19 MiB computation off the UI isolate.
    final argon = DartArgon2id(
      parallelism: params.parallelism,
      memory: params.memoryKiB,
      iterations: params.iterations,
      hashLength: _bytesFor(defaultWordCount),
      maxIsolates: 1,
    );
    final out = await (await argon.deriveKey(
      secretKey: SecretKey(ikm),
      nonce: salt,
    ))
        .extractBytes();
    return _render(out, defaultWordCount, list);
  }

  /// The 8-word phrase both phones compare after a long-distance pairing.
  static Future<List<String>> deriveLongDistancePhrase({
    required List<int> sharedSecret,
    required List<int> ownPublicKey,
    required List<int> peerPublicKey,
    WordList? list,
  }) async {
    _checkSecret(sharedSecret);
    final salt = await transcriptSalt(ownPublicKey, peerPublicKey);
    final bytes = await _hkdf(
      sharedSecret,
      salt: salt,
      info: _longDistanceInfo,
      length: _bytesFor(longDistanceWordCount),
    );
    return _render(bytes, longDistanceWordCount, list);
  }

  static int _bytesFor(int wordCount) => (wordCount * _bitsPerWord + 7) ~/ 8;

  static Future<List<int>> _hkdf(
    List<int> secret, {
    required List<int> salt,
    required String info,
    required int length,
  }) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: length);
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(secret),
      nonce: salt,
      info: info.codeUnits,
    );
    return derived.extractBytes();
  }

  static void _checkSecret(List<int> sharedSecret) {
    if (sharedSecret.isEmpty) {
      throw ArgumentError.value(
        sharedSecret,
        'sharedSecret',
        'Shared secret must not be empty.',
      );
    }
  }

  static void _checkKey(List<int> key, String name) {
    if (key.length != _publicKeyLength) {
      throw ArgumentError.value(
        key.length,
        '$name.length',
        'X25519 public keys must be exactly $_publicKeyLength bytes.',
      );
    }
  }

  static int _compareBytes(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return 0;
  }

  /// The words [bytes] pick, spelled in [list] (English when null).
  static List<String> _render(List<int> bytes, int wordCount, WordList? list) =>
      (list ?? WordList.english).render(_bytesToIndices(bytes, wordCount));

  static List<int> _bytesToIndices(List<int> bytes, int wordCount) {
    final words = <int>[];
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
        // Defensive: output lengths are chosen above to always satisfy
        // the bit budget, so this branch should be unreachable.
        throw StateError('Insufficient entropy extracted for phrase.');
      }
      final shift = bits - _bitsPerWord;
      words.add((buffer >> shift) & (WordList.size - 1));
      buffer &= (1 << shift) - 1;
      bits = shift;
    }
    return words;
  }
}
