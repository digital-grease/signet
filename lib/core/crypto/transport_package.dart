import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'bip39_english_wordlist.dart';
import 'pair_role.dart';

/// Wire format + crypto for Signet's Phase-10 transport package. One
/// primitive, three payload types:
///
/// - **LDP — long-distance pairing** (0x01). Carries an ephemeral X25519
///   public key + label hint from sender to receiver. Unlocked with an
///   out-of-band 8-word PAKE secret communicated on a channel the parties
///   already trust. Used in both directions of the pairing round-trip.
///
/// - **LPR — lost-phone recovery** (0x02). Carries the full existing
///   shared secret + relationship metadata from the user's old phone to
///   their new one. The recovery case where sender and receiver are the
///   same human.
///
/// - **BLK — bulk backup** (0x03). Carries a count-prefixed vector of
///   LPR-shaped records behind a single AEAD tag + single 8-word PAKE.
///   The phone-switch case where a user wants every paired relationship
///   to migrate in one step instead of N separate exports. See
///   `.devloop/spikes/bulk-backup.md` for the full rationale.
///
/// Wire format (see `.devloop/spikes/transport-package.md` for the full
/// rationale — this implementation matches Option B with 8-word HKDF):
///
/// ```
/// signet:tp1:<base64url(body)>
///
/// body:
///   [1]   version                  0x01
///   [1]   payload-type             0x01 LDP, 0x02 LPR, 0x03 BLK
///   [8]   timestamp                unix seconds, big-endian
///   [12]  AEAD nonce
///   [N]   AES-256-GCM ciphertext
///   [16]  AES-256-GCM tag
/// ```
///
/// AEAD key `K` is derived as:
/// `HKDF-SHA-256(secretKey = W_bytes, info = <domain>, salt = nonce, len = 32)`.
/// The domain string is `signet/v1/tp1/ldp`, `signet/v1/tp1/lpr`, or
/// `signet/v1/tp1/blk` per payload, so even if an attacker flips the
/// payload-type byte the ciphertext won't decrypt.
///
/// `W_bytes` is the UTF-8 lowercased concatenation of the 8 BIP-39 words
/// separated by spaces — the same normalization we apply on input so the
/// same words always produce the same key regardless of whitespace /
/// case.
///
/// See `transport_package_test.dart` for deterministic test vectors.
class TransportPackage {
  const TransportPackage._();

  static const String _prefix = 'signet:tp1:';
  static const int _version = 0x01;
  static const int _typeLdp = 0x01;
  static const int _typeLpr = 0x02;
  static const int _typeBlk = 0x03;
  static const int _pakeWordCount = 8;
  static const int _nonceLength = 12;
  static const int _tagLength = 16;
  static const int _timestampLength = 8;
  static const int _x25519KeyLength = 32;
  static const int _sharedSecretLength = 32;
  static const int _maxLabelBytes = 32;
  static const int _maxSubLabelBytes = 64;
  static const int _blkCountPrefixLength = 2;
  static const int _blkMaxRecords = 255;

  static final Set<String> _wordlistSet = bip39EnglishWordlist.toSet();

  // ========================================================================
  // Payload-type peek (for import dispatch)
  // ========================================================================

  /// Inspect a wire string's payload-type byte without attempting
  /// decryption. Returns `null` if the wire is structurally malformed
  /// (wrong scheme, wrong version, unparseable base64, too short).
  ///
  /// The version + payload-type bytes are plaintext (they precede the
  /// AEAD-sealed body), so this peek is safe without the PAKE secret.
  /// Used by the import screen to dispatch between LPR and BLK flows
  /// before asking the user for their PAKE words.
  static TransportPayloadType? peekPayloadType(String wire) {
    if (!wire.startsWith(_prefix)) return null;
    final encoded = wire.substring(_prefix.length);
    final List<int> body;
    try {
      body = _base64UrlDecode(encoded);
    } on InvalidPackageException {
      return null;
    }
    if (body.length < 2) return null;
    if (body[0] != _version) return null;
    return switch (body[1]) {
      _typeLdp => TransportPayloadType.ldp,
      _typeLpr => TransportPayloadType.lpr,
      _typeBlk => TransportPayloadType.blk,
      _ => null,
    };
  }

  // ========================================================================
  // PAKE words
  // ========================================================================

  /// Mint a fresh 8-word PAKE secret from a cryptographically-secure RNG.
  /// Each call returns a new list.
  static List<String> mintPakeWords({Random? random, int wordCount = _pakeWordCount}) {
    final rng = random ?? Random.secure();
    return List<String>.generate(
      wordCount,
      (_) => bip39EnglishWordlist[rng.nextInt(bip39EnglishWordlist.length)],
    );
  }

  /// Normalize + validate a user-entered PAKE word list. Throws
  /// [InvalidPakeException] on the wrong count or non-wordlist tokens.
  static List<String> normalizePakeWords(List<String> words) {
    if (words.length != _pakeWordCount) {
      throw InvalidPakeException(
        'PAKE secret must be exactly $_pakeWordCount words; got ${words.length}.',
      );
    }
    final out = <String>[];
    for (final w in words) {
      final normalized = w.trim().toLowerCase();
      if (!_wordlistSet.contains(normalized)) {
        throw InvalidPakeException(
          'Word "$normalized" is not in the BIP-39 English wordlist.',
        );
      }
      out.add(normalized);
    }
    return out;
  }

  // ========================================================================
  // LDP — long-distance pairing
  // ========================================================================

  /// Encode an LDP package carrying [publicKey] (32 bytes X25519) and a
  /// short [labelHint] (≤32 UTF-8 bytes). The caller chooses [pakeWords]
  /// via [mintPakeWords] and communicates them to the receiver OOB.
  static Future<String> encodeLdp({
    required List<int> publicKey,
    required String labelHint,
    required List<String> pakeWords,
    DateTime? now,
    Random? nonceRandom,
  }) async {
    if (publicKey.length != _x25519KeyLength) {
      throw ArgumentError.value(
        publicKey.length,
        'publicKey.length',
        'X25519 public keys must be exactly $_x25519KeyLength bytes.',
      );
    }
    final labelBytes = utf8.encode(labelHint);
    if (labelBytes.length > _maxLabelBytes) {
      throw ArgumentError.value(
        labelBytes.length,
        'labelHint',
        'Label hint must be ≤$_maxLabelBytes UTF-8 bytes.',
      );
    }
    final plaintext = <int>[
      ...publicKey,
      labelBytes.length,
      ...labelBytes,
    ];
    return _encode(
      payloadType: _typeLdp,
      plaintext: plaintext,
      pakeWords: pakeWords,
      now: now,
      nonceRandom: nonceRandom,
    );
  }

  /// Decode an LDP wire string with the receiver-entered [pakeWords].
  /// Throws [InvalidPackageException] on a malformed wire string and
  /// [InvalidPakeException] on a wrong PAKE secret.
  static Future<LdpPackage> decodeLdp(
    String wire, {
    required List<String> pakeWords,
  }) async {
    final (plaintext, timestamp) = await _decode(
      wire: wire,
      expectedPayloadType: _typeLdp,
      pakeWords: pakeWords,
    );
    if (plaintext.length < _x25519KeyLength + 1) {
      throw const InvalidPackageException(
        'LDP payload too short to contain the public key.',
      );
    }
    final publicKey = plaintext.sublist(0, _x25519KeyLength);
    final labelLen = plaintext[_x25519KeyLength];
    if (plaintext.length != _x25519KeyLength + 1 + labelLen) {
      throw const InvalidPackageException(
        'LDP payload length inconsistent with its label-length byte.',
      );
    }
    final labelBytes =
        plaintext.sublist(_x25519KeyLength + 1, _x25519KeyLength + 1 + labelLen);
    final labelHint = utf8.decode(labelBytes);
    return LdpPackage(
      publicKey: Uint8List.fromList(publicKey),
      labelHint: labelHint,
      timestamp: timestamp,
    );
  }

  // ========================================================================
  // LPR — lost-phone recovery
  // ========================================================================

  /// Encode an LPR package carrying the full shared secret + metadata for
  /// an existing relationship. Consumed by the new device in a transport-
  /// to-self recovery flow.
  static Future<String> encodeLpr({
    required String label,
    required PairRole role,
    required DateTime pairedAt,
    required bool silentHaptics,
    required List<int> sharedSecret,
    required List<String> pakeWords,
    DateTime? now,
    Random? nonceRandom,
  }) async {
    if (sharedSecret.length != _sharedSecretLength) {
      throw ArgumentError.value(
        sharedSecret.length,
        'sharedSecret.length',
        'Shared secret must be exactly $_sharedSecretLength bytes.',
      );
    }
    final labelBytes = utf8.encode(label);
    if (labelBytes.length > _maxSubLabelBytes) {
      throw ArgumentError.value(
        labelBytes.length,
        'label',
        'Label must be ≤$_maxSubLabelBytes UTF-8 bytes.',
      );
    }
    final roleByte = switch (role) {
      PairRole.a => 0x01,
      PairRole.b => 0x02,
    };
    final pairedAtSecs = pairedAt.toUtc().millisecondsSinceEpoch ~/ 1000;
    final plaintext = <int>[
      ...sharedSecret,
      roleByte,
      labelBytes.length,
      ...labelBytes,
      ..._uint64BE(pairedAtSecs),
      silentHaptics ? 0x01 : 0x00,
    ];
    return _encode(
      payloadType: _typeLpr,
      plaintext: plaintext,
      pakeWords: pakeWords,
      now: now,
      nonceRandom: nonceRandom,
    );
  }

  static Future<LprPackage> decodeLpr(
    String wire, {
    required List<String> pakeWords,
  }) async {
    final (plaintext, timestamp) = await _decode(
      wire: wire,
      expectedPayloadType: _typeLpr,
      pakeWords: pakeWords,
    );
    // Required: 32 secret + 1 role + 1 label-len + ≥0 label + 8 pairedAt + 1 silent.
    if (plaintext.length < _sharedSecretLength + 1 + 1 + _timestampLength + 1) {
      throw const InvalidPackageException('LPR payload too short.');
    }
    var cursor = 0;
    final sharedSecret =
        plaintext.sublist(cursor, cursor + _sharedSecretLength);
    cursor += _sharedSecretLength;
    final roleByte = plaintext[cursor++];
    final role = switch (roleByte) {
      0x01 => PairRole.a,
      0x02 => PairRole.b,
      _ => throw InvalidPackageException(
          'LPR payload has unknown role byte 0x${roleByte.toRadixString(16)}.',
        ),
    };
    final labelLen = plaintext[cursor++];
    if (plaintext.length <
        cursor + labelLen + _timestampLength + 1) {
      throw const InvalidPackageException(
        'LPR payload length inconsistent with its label-length byte.',
      );
    }
    final label = utf8.decode(plaintext.sublist(cursor, cursor + labelLen));
    cursor += labelLen;
    final pairedAtSecs =
        _uint64FromBE(plaintext.sublist(cursor, cursor + _timestampLength));
    cursor += _timestampLength;
    final silentHaptics = plaintext[cursor++] != 0;
    return LprPackage(
      sharedSecret: Uint8List.fromList(sharedSecret),
      label: label,
      role: role,
      pairedAt: DateTime.fromMillisecondsSinceEpoch(
        pairedAtSecs * 1000,
        isUtc: true,
      ),
      silentHaptics: silentHaptics,
      timestamp: timestamp,
    );
  }

  // ========================================================================
  // BLK — bulk backup
  // ========================================================================

  /// Encode a BLK package carrying every relationship on the old phone
  /// in a single AEAD-sealed payload. Plaintext layout (inside the
  /// outer body, once AEAD opens):
  ///
  /// ```
  /// [2]    count                    big-endian u16 (max 255 on encode)
  /// repeat count times:
  ///   [32]   shared_secret
  ///   [1]    role                   0x01 A, 0x02 B
  ///   [1]    label_len              ≤ 64
  ///   [...]  label (UTF-8)
  ///   [8]    pairedAt               unix seconds, big-endian
  ///   [1]    silentHaptics          0x01 / 0x00
  /// ```
  ///
  /// Each record is structurally identical to a [LprPackage] payload
  /// minus its own timestamp (the outer body timestamp is shared).
  /// Rejects [records] with more than 255 entries or any label >64
  /// UTF-8 bytes.
  static Future<String> encodeBlk({
    required List<BlkRelationshipRecord> records,
    required List<String> pakeWords,
    DateTime? now,
    Random? nonceRandom,
  }) async {
    if (records.length > _blkMaxRecords) {
      throw ArgumentError.value(
        records.length,
        'records.length',
        'BLK can hold at most $_blkMaxRecords records.',
      );
    }
    final plaintext = <int>[
      (records.length >> 8) & 0xFF,
      records.length & 0xFF,
    ];
    for (final r in records) {
      if (r.sharedSecret.length != _sharedSecretLength) {
        throw ArgumentError.value(
          r.sharedSecret.length,
          'record.sharedSecret.length',
          'Shared secret must be exactly $_sharedSecretLength bytes.',
        );
      }
      final labelBytes = utf8.encode(r.label);
      if (labelBytes.length > _maxSubLabelBytes) {
        throw ArgumentError.value(
          labelBytes.length,
          'record.label',
          'Label must be ≤$_maxSubLabelBytes UTF-8 bytes.',
        );
      }
      final roleByte = switch (r.role) {
        PairRole.a => 0x01,
        PairRole.b => 0x02,
      };
      final pairedAtSecs = r.pairedAt.toUtc().millisecondsSinceEpoch ~/ 1000;
      plaintext
        ..addAll(r.sharedSecret)
        ..add(roleByte)
        ..add(labelBytes.length)
        ..addAll(labelBytes)
        ..addAll(_uint64BE(pairedAtSecs))
        ..add(r.silentHaptics ? 0x01 : 0x00);
    }
    return _encode(
      payloadType: _typeBlk,
      plaintext: plaintext,
      pakeWords: pakeWords,
      now: now,
      nonceRandom: nonceRandom,
    );
  }

  /// Decode a BLK wire string with the receiver-entered [pakeWords].
  /// Throws [InvalidPackageException] on a malformed wire / inconsistent
  /// record count, and [InvalidPakeException] on wrong PAKE.
  static Future<BlkPackage> decodeBlk(
    String wire, {
    required List<String> pakeWords,
  }) async {
    final (plaintext, timestamp) = await _decode(
      wire: wire,
      expectedPayloadType: _typeBlk,
      pakeWords: pakeWords,
    );
    if (plaintext.length < _blkCountPrefixLength) {
      throw const InvalidPackageException(
        'BLK payload too short to contain a count prefix.',
      );
    }
    final count = (plaintext[0] << 8) | plaintext[1];
    var cursor = _blkCountPrefixLength;
    final records = <BlkRelationshipRecord>[];
    for (var i = 0; i < count; i++) {
      // Required per record: 32 secret + 1 role + 1 label_len + label + 8 pairedAt + 1 silent.
      if (plaintext.length < cursor + _sharedSecretLength + 1 + 1) {
        throw const InvalidPackageException(
          'BLK payload truncated — missing record header.',
        );
      }
      final sharedSecret =
          plaintext.sublist(cursor, cursor + _sharedSecretLength);
      cursor += _sharedSecretLength;
      final roleByte = plaintext[cursor++];
      final role = switch (roleByte) {
        0x01 => PairRole.a,
        0x02 => PairRole.b,
        _ => throw InvalidPackageException(
            'BLK record has unknown role byte 0x${roleByte.toRadixString(16)}.',
          ),
      };
      final labelLen = plaintext[cursor++];
      if (plaintext.length < cursor + labelLen + _timestampLength + 1) {
        throw const InvalidPackageException(
          'BLK payload truncated — record body does not fit.',
        );
      }
      final label = utf8.decode(plaintext.sublist(cursor, cursor + labelLen));
      cursor += labelLen;
      final pairedAtSecs =
          _uint64FromBE(plaintext.sublist(cursor, cursor + _timestampLength));
      cursor += _timestampLength;
      final silentHaptics = plaintext[cursor++] != 0;
      records.add(BlkRelationshipRecord(
        sharedSecret: Uint8List.fromList(sharedSecret),
        role: role,
        label: label,
        pairedAt: DateTime.fromMillisecondsSinceEpoch(
          pairedAtSecs * 1000,
          isUtc: true,
        ),
        silentHaptics: silentHaptics,
      ));
    }
    if (cursor != plaintext.length) {
      throw const InvalidPackageException(
        'BLK payload length inconsistent with its record count.',
      );
    }
    return BlkPackage(records: records, timestamp: timestamp);
  }

  // ========================================================================
  // Internal encode/decode
  // ========================================================================

  static Future<String> _encode({
    required int payloadType,
    required List<int> plaintext,
    required List<String> pakeWords,
    DateTime? now,
    Random? nonceRandom,
  }) async {
    final normalized = normalizePakeWords(pakeWords);
    final nonce = _mintNonce(nonceRandom);
    final key = await _deriveKey(
      pakeWords: normalized,
      payloadType: payloadType,
      nonce: nonce,
    );
    final cipher = AesGcm.with256bits();
    final secretBox = await cipher.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    final timestamp = now ?? DateTime.now();
    final body = <int>[
      _version,
      payloadType,
      ..._uint64BE(timestamp.toUtc().millisecondsSinceEpoch ~/ 1000),
      ...nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ];
    return '$_prefix${_base64UrlNoPad(body)}';
  }

  static Future<(List<int>, DateTime)> _decode({
    required String wire,
    required int expectedPayloadType,
    required List<String> pakeWords,
  }) async {
    if (!wire.startsWith(_prefix)) {
      throw const InvalidPackageException(
        'Not a Signet transport package (wrong scheme / version).',
      );
    }
    final body = _base64UrlDecode(wire.substring(_prefix.length));
    if (body.length < 2 + _timestampLength + _nonceLength + _tagLength) {
      throw const InvalidPackageException('Transport package body too short.');
    }
    if (body[0] != _version) {
      throw InvalidPackageException(
        'Unsupported transport-package version 0x${body[0].toRadixString(16)}.',
      );
    }
    if (body[1] != expectedPayloadType) {
      throw InvalidPackageException(
        'Wrong payload type: expected 0x${expectedPayloadType.toRadixString(16)}, '
        'got 0x${body[1].toRadixString(16)}.',
      );
    }
    final timestampSecs = _uint64FromBE(body.sublist(2, 2 + _timestampLength));
    const nonceStart = 2 + _timestampLength;
    final nonce = body.sublist(nonceStart, nonceStart + _nonceLength);
    final tagStart = body.length - _tagLength;
    const ciphertextStart = nonceStart + _nonceLength;
    if (ciphertextStart > tagStart) {
      throw const InvalidPackageException(
        'Transport package has no ciphertext between nonce and tag.',
      );
    }
    final ciphertext = body.sublist(ciphertextStart, tagStart);
    final tag = body.sublist(tagStart);

    final normalized = normalizePakeWords(pakeWords);
    final key = await _deriveKey(
      pakeWords: normalized,
      payloadType: expectedPayloadType,
      nonce: nonce,
    );
    final cipher = AesGcm.with256bits();
    try {
      final plaintext = await cipher.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(tag)),
        secretKey: SecretKey(key),
      );
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        timestampSecs * 1000,
        isUtc: true,
      );
      return (plaintext, timestamp);
    } on SecretBoxAuthenticationError {
      throw const InvalidPakeException(
        'PAKE secret is wrong (authentication tag did not verify).',
      );
    }
  }

  // ========================================================================
  // Helpers
  // ========================================================================

  static Future<List<int>> _deriveKey({
    required List<String> pakeWords,
    required int payloadType,
    required List<int> nonce,
  }) async {
    final info = switch (payloadType) {
      _typeLdp => 'signet/v1/tp1/ldp',
      _typeLpr => 'signet/v1/tp1/lpr',
      _typeBlk => 'signet/v1/tp1/blk',
      _ => throw ArgumentError.value(
          payloadType,
          'payloadType',
          'Unknown transport-package payload type.',
        ),
    };
    final wBytes = utf8.encode(pakeWords.join(' '));
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(wBytes),
      nonce: nonce,
      info: info.codeUnits,
    );
    return derived.extractBytes();
  }

  static List<int> _mintNonce(Random? random) {
    final rng = random ?? Random.secure();
    return List<int>.generate(_nonceLength, (_) => rng.nextInt(256));
  }

  static List<int> _uint64BE(int value) {
    final bytes = Uint8List(_timestampLength);
    var v = value;
    for (var i = _timestampLength - 1; i >= 0; i--) {
      bytes[i] = v & 0xFF;
      v >>= 8;
    }
    return bytes;
  }

  static int _uint64FromBE(List<int> bytes) {
    var out = 0;
    for (var i = 0; i < _timestampLength; i++) {
      out = (out << 8) | (bytes[i] & 0xFF);
    }
    return out;
  }

  static String _base64UrlNoPad(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static List<int> _base64UrlDecode(String input) {
    final padding = (4 - input.length % 4) % 4;
    try {
      return base64Url.decode(input + '=' * padding);
    } on FormatException catch (e) {
      throw InvalidPackageException(
        'Transport package body is not valid base64url: ${e.message}',
      );
    }
  }
}

// ============================================================================
// Result types
// ============================================================================

class LdpPackage {
  const LdpPackage({
    required this.publicKey,
    required this.labelHint,
    required this.timestamp,
  });

  final Uint8List publicKey;
  final String labelHint;
  final DateTime timestamp;
}

class LprPackage {
  const LprPackage({
    required this.sharedSecret,
    required this.label,
    required this.role,
    required this.pairedAt,
    required this.silentHaptics,
    required this.timestamp,
  });

  final Uint8List sharedSecret;
  final String label;
  final PairRole role;
  final DateTime pairedAt;
  final bool silentHaptics;
  final DateTime timestamp;
}

/// One relationship's worth of recovery data inside a [BlkPackage].
/// Shape mirrors [LprPackage] minus the outer body's shared timestamp.
class BlkRelationshipRecord {
  const BlkRelationshipRecord({
    required this.sharedSecret,
    required this.role,
    required this.label,
    required this.pairedAt,
    required this.silentHaptics,
  });

  final Uint8List sharedSecret;
  final PairRole role;
  final String label;
  final DateTime pairedAt;
  final bool silentHaptics;
}

class BlkPackage {
  const BlkPackage({required this.records, required this.timestamp});

  final List<BlkRelationshipRecord> records;
  final DateTime timestamp;
}

// ============================================================================
// Exceptions
// ============================================================================

/// Which payload a `signet:tp1:` wire carries. Populated by
/// [TransportPackage.peekPayloadType] without requiring the PAKE secret,
/// since the payload-type byte precedes the AEAD-sealed body.
enum TransportPayloadType {
  /// Long-distance pairing (0x01).
  ldp,

  /// Lost-phone recovery / single-relationship backup (0x02).
  lpr,

  /// Bulk backup — every paired relationship in one payload (0x03).
  blk,
}

/// Thrown when the 8-word PAKE secret is malformed (wrong count, non-wordlist
/// tokens) or does not unlock the package (AEAD authentication failed).
class InvalidPakeException implements Exception {
  const InvalidPakeException(this.message);
  final String message;

  @override
  String toString() => 'InvalidPakeException: $message';
}

/// Thrown when the wire format is structurally malformed — wrong scheme,
/// wrong version, wrong payload type, impossible length, etc.
class InvalidPackageException implements Exception {
  const InvalidPackageException(this.message);
  final String message;

  @override
  String toString() => 'InvalidPackageException: $message';
}
