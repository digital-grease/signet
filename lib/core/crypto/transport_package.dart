import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart' show visibleForTesting;

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
/// Wire format (see `.devloop/spikes/transport-package.md` and
/// `docs/WIRE_FORMAT.md`):
///
/// ```
/// signet:tp1:<base64url(body)>
///
/// body:
///   [1]   version                  0x01 or 0x02
///   [1]   payload-type             0x01 LDP, 0x02 LPR, 0x03 BLK
///   [8]   timestamp                unix seconds, big-endian
///   [12]  AEAD nonce
///   [N]   AES-256-GCM ciphertext
///   [16]  AES-256-GCM tag
/// ```
///
/// AEAD key `K` is derived as:
/// `HKDF-SHA-256(secretKey = W_bytes, info = <domain>, salt = nonce, len = 32)`
/// with domain `signet/v<version>/tp1/<ldp|lpr|blk>`, so flipping the
/// payload-type or version byte makes the ciphertext undecryptable.
///
/// **Version 2** also passes the 10 header bytes (version, payload type,
/// timestamp) to AES-GCM as associated data, so the header cannot be
/// altered, and appends a length-delimited extension area to the LDP and
/// LPR payloads and to every BLK record:
///
/// ```
/// [2]    ext_len                   big-endian u16
/// [ext_len] TLVs, each: [1] tag, [2] big-endian length, [length] value
/// ```
///
/// Tag bit 0x80 marks a must-understand ("critical") field. A decoder that
/// does not know a critical tag rejects the package (LDP, LPR) or skips
/// that record (BLK) with an "update Signet" error; unknown non-critical
/// tags are ignored. Extensions may only add fields, never override the
/// fixed ones. A structurally broken extension area (overrun, truncated
/// field, repeated tag) rejects the whole package.
///
/// Version 1 packages (every backup made before the switch) keep decoding
/// exactly as before. This release still *encodes* version 1
/// ([TransportPackage.currentEncodeVersion]); the next release switches the
/// encoder to version 2 once decoders that read it are in the field. An
/// LDP response mirrors the version of the request it answers.
///
/// `W_bytes` is the UTF-8 lowercased concatenation of the 8 BIP-39 words
/// separated by spaces, the same normalization applied on input, so the
/// same words always produce the same key regardless of whitespace or case.
///
/// See `transport_package_test.dart` for deterministic test vectors.
class TransportPackage {
  const TransportPackage._();

  static const String _prefix = 'signet:tp1:';
  static const int _versionV1 = 0x01;
  static const int _versionV2 = 0x02;

  /// Version written by the encoders. Decoders accept 1 and 2. Switch to 2
  /// in v0.3.8, one release after decoders that understand it ship (plan
  /// Task 1.6 part B).
  static const int currentEncodeVersion = _versionV1;

  static const int _typeLdp = 0x01;
  static const int _typeLpr = 0x02;
  static const int _typeBlk = 0x03;
  static const int _headerLength = 2 + _timestampLength;
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
  static const int _extLenLength = 2;
  static const int _tlvHeaderLength = 3;
  static const int _maxExtBytes = 0xFFFF;

  /// Tag bit marking a must-understand extension.
  static const int criticalTagBit = 0x80;

  /// Critical tags this build understands. None yet: any critical tag is
  /// from a newer Signet.
  static const Set<int> _knownCriticalTags = <int>{};

  /// Never valid on the wire (see `docs/WIRE_FORMAT.md`).
  static const Set<int> _reservedTags = <int>{0x00, 0x80};

  /// Latest representable unix second (9999-12-31T23:59:59Z).
  static const int _maxUnixSeconds = 253402300799;

  static final Set<String> _wordlistSet = bip39EnglishWordlist.toSet();

  // ========================================================================
  // Payload-type peek (for import dispatch)
  // ========================================================================

  /// Inspect a wire string's payload-type byte without attempting
  /// decryption. Returns `null` if the wire is structurally malformed
  /// (wrong scheme, unparseable base64, too short, unknown payload type in
  /// a version this build reads). Throws [UnsupportedPackageVersionException]
  /// for a package written by a newer Signet (a version above 2), so the
  /// UI can say "update the app" instead of "not a valid backup".
  ///
  /// The version + payload-type bytes precede the AEAD-sealed body, so
  /// this peek is safe without the PAKE secret.
  static TransportPayloadType? peekPayloadType(String wire) {
    if (!wire.startsWith(_prefix)) return null;
    final encoded = wire.substring(_prefix.length);
    final List<int> body;
    try {
      body = _base64UrlDecode(encoded);
    } on InvalidPackageException {
      return null;
    }
    if (body.isEmpty) return null;
    // Version before length, matching _decode, so peek and decode agree
    // even on a truncated package.
    final version = body[0];
    if (version > _versionV2) throw const UnsupportedPackageVersionException();
    if (version != _versionV1 && version != _versionV2) return null;
    if (body.length < 2) return null;
    final type = _payloadTypeOf(body[1]);
    // A payload type this build does not know, inside a version that can
    // grow new types, means a newer Signet wrote it.
    if (type == null && version == _versionV2) {
      throw const UnsupportedPackageVersionException();
    }
    return type;
  }

  static TransportPayloadType? _payloadTypeOf(int byte) => switch (byte) {
        _typeLdp => TransportPayloadType.ldp,
        _typeLpr => TransportPayloadType.lpr,
        _typeBlk => TransportPayloadType.blk,
        _ => null,
      };

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
  ///
  /// A response to a received request passes that request's
  /// [LdpPackage.version] as [version], so peers on an older build that
  /// only reads version 1 can still pair. [extensions] are version 2 only.
  static Future<String> encodeLdp({
    required List<int> publicKey,
    required String labelHint,
    required List<String> pakeWords,
    DateTime? now,
    Random? nonceRandom,
    int version = currentEncodeVersion,
    List<TransportExtension> extensions = const <TransportExtension>[],
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
      ..._encodeExtensions(version, extensions),
    ];
    return _encode(
      version: version,
      payloadType: _typeLdp,
      plaintext: plaintext,
      pakeWords: pakeWords,
      now: now,
      nonceRandom: nonceRandom,
    );
  }

  /// Decode an LDP wire string with the receiver-entered [pakeWords].
  /// Throws [InvalidPakeException] on a wrong PAKE secret,
  /// [UnsupportedPackageVersionException] for a package that needs a newer
  /// Signet, and [InvalidPackageException] on anything else malformed.
  static Future<LdpPackage> decodeLdp(
    String wire, {
    required List<String> pakeWords,
  }) async {
    final opened = await _decode(
      wire: wire,
      expectedPayloadType: _typeLdp,
      pakeWords: pakeWords,
    );
    final plaintext = opened.plaintext;
    if (plaintext.length < _x25519KeyLength + 1) {
      throw const InvalidPackageException(
        'LDP payload too short to contain the public key.',
      );
    }
    final publicKey = plaintext.sublist(0, _x25519KeyLength);
    final labelLen = plaintext[_x25519KeyLength];
    var cursor = _x25519KeyLength + 1;
    if (plaintext.length < cursor + labelLen) {
      throw const InvalidPackageException(
        'LDP payload length inconsistent with its label-length byte.',
      );
    }
    // The hint only pre-fills a name field the user confirms, so a repair
    // here is not flagged.
    final label = _decodeLabel(
      plaintext.sublist(cursor, cursor + labelLen),
      maxBytes: _maxLabelBytes,
    );
    cursor += labelLen;
    var extensions = const <int, Uint8List>{};
    if (opened.version == _versionV1) {
      if (cursor != plaintext.length) {
        throw const InvalidPackageException(
          'LDP payload length inconsistent with its label-length byte.',
        );
      }
    } else {
      final ext = _parseExtensions(plaintext, cursor);
      if (ext.unknownCritical) {
        throw const UnsupportedPackageVersionException(authenticated: true);
      }
      if (ext.end != plaintext.length) {
        throw const InvalidPackageException('LDP payload has trailing bytes.');
      }
      extensions = ext.fields;
    }
    return LdpPackage(
      publicKey: Uint8List.fromList(publicKey),
      labelHint: label.text,
      timestamp: opened.timestamp,
      version: opened.version,
      extensions: extensions,
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
    int version = currentEncodeVersion,
    List<TransportExtension> extensions = const <TransportExtension>[],
  }) async {
    final plaintext = <int>[
      ..._encodeRecord(
        sharedSecret: sharedSecret,
        role: role,
        label: label,
        pairedAt: pairedAt,
        silentHaptics: silentHaptics,
        argPrefix: '',
      ),
      ..._encodeExtensions(version, extensions),
    ];
    return _encode(
      version: version,
      payloadType: _typeLpr,
      plaintext: plaintext,
      pakeWords: pakeWords,
      now: now,
      nonceRandom: nonceRandom,
    );
  }

  /// Decode an LPR wire string. A damaged pairing date or label (possible
  /// only from a buggy encoder, since the payload is authenticated) is
  /// repaired rather than rejected, and [LprPackage.repaired] is set so the
  /// UI can say so.
  static Future<LprPackage> decodeLpr(
    String wire, {
    required List<String> pakeWords,
    DateTime? now,
  }) async {
    final opened = await _decode(
      wire: wire,
      expectedPayloadType: _typeLpr,
      pakeWords: pakeWords,
    );
    final plaintext = opened.plaintext;
    final record = _decodeRecord(
      plaintext,
      0,
      version: opened.version,
      now: now,
      where: 'LPR',
    );
    if (record.unknownCritical) {
      throw const UnsupportedPackageVersionException(authenticated: true);
    }
    if (record.end != plaintext.length) {
      throw const InvalidPackageException('LPR payload has trailing bytes.');
    }
    return LprPackage(
      sharedSecret: record.sharedSecret,
      label: record.label,
      role: record.role!,
      pairedAt: record.pairedAt,
      silentHaptics: record.silentHaptics,
      timestamp: opened.timestamp,
      version: opened.version,
      pairedAtRepaired: record.pairedAtRepaired,
      labelRepaired: record.labelRepaired,
      extensions: record.extensions,
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
  ///   v2 only:
  ///   [2]    ext_len, then ext_len bytes of TLVs
  /// ```
  ///
  /// Rejects [records] with more than 255 entries or any label >64
  /// UTF-8 bytes.
  static Future<String> encodeBlk({
    required List<BlkRelationshipRecord> records,
    required List<String> pakeWords,
    DateTime? now,
    Random? nonceRandom,
    int version = currentEncodeVersion,
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
      plaintext
        ..addAll(_encodeRecord(
          sharedSecret: r.sharedSecret,
          role: r.role,
          label: r.label,
          pairedAt: r.pairedAt,
          silentHaptics: r.silentHaptics,
          argPrefix: 'record.',
        ))
        ..addAll(_encodeExtensions(version, <TransportExtension>[
          for (final e in r.extensions.entries) TransportExtension(e.key, e.value),
        ]));
    }
    return _encode(
      version: version,
      payloadType: _typeBlk,
      plaintext: plaintext,
      pakeWords: pakeWords,
      now: now,
      nonceRandom: nonceRandom,
    );
  }

  /// Decode a BLK wire string with the receiver-entered [pakeWords].
  ///
  /// The whole bundle is under one AEAD tag, so a malformed record came
  /// from whoever holds the PAKE words (a buggy encoder or a newer build),
  /// not an attacker. Structural errors reject the whole package; semantic
  /// problems are handled per record: a damaged date or label is repaired
  /// and flagged, and a record with an unknown must-understand extension
  /// is skipped and counted in [BlkPackage.skippedNeedsNewerVersion].
  static Future<BlkPackage> decodeBlk(
    String wire, {
    required List<String> pakeWords,
    DateTime? now,
  }) async {
    final opened = await _decode(
      wire: wire,
      expectedPayloadType: _typeBlk,
      pakeWords: pakeWords,
    );
    final plaintext = opened.plaintext;
    if (plaintext.length < _blkCountPrefixLength) {
      throw const InvalidPackageException(
        'BLK payload too short to contain a count prefix.',
      );
    }
    final count = (plaintext[0] << 8) | plaintext[1];
    var cursor = _blkCountPrefixLength;
    final records = <BlkRelationshipRecord>[];
    var skipped = 0;
    for (var i = 0; i < count; i++) {
      final record = _decodeRecord(
        plaintext,
        cursor,
        version: opened.version,
        now: now,
        where: 'BLK record',
      );
      cursor = record.end;
      if (record.unknownCritical) {
        skipped++;
        continue;
      }
      records.add(BlkRelationshipRecord(
        sharedSecret: record.sharedSecret,
        role: record.role!,
        label: record.label,
        pairedAt: record.pairedAt,
        silentHaptics: record.silentHaptics,
        repaired: record.pairedAtRepaired || record.labelRepaired,
        extensions: record.extensions,
      ));
    }
    if (cursor != plaintext.length) {
      throw const InvalidPackageException(
        'BLK payload length inconsistent with its record count.',
      );
    }
    return BlkPackage(
      records: records,
      timestamp: opened.timestamp,
      version: opened.version,
      skippedNeedsNewerVersion: skipped,
    );
  }

  // ========================================================================
  // Records and extensions
  // ========================================================================

  static List<int> _encodeRecord({
    required List<int> sharedSecret,
    required PairRole role,
    required String label,
    required DateTime pairedAt,
    required bool silentHaptics,
    required String argPrefix,
  }) {
    if (sharedSecret.length != _sharedSecretLength) {
      throw ArgumentError.value(
        sharedSecret.length,
        '${argPrefix}sharedSecret.length',
        'Shared secret must be exactly $_sharedSecretLength bytes.',
      );
    }
    final labelBytes = utf8.encode(label);
    if (labelBytes.length > _maxSubLabelBytes) {
      throw ArgumentError.value(
        labelBytes.length,
        '${argPrefix}label',
        'Label must be ≤$_maxSubLabelBytes UTF-8 bytes.',
      );
    }
    final roleByte = switch (role) {
      PairRole.a => 0x01,
      PairRole.b => 0x02,
    };
    final pairedAtSecs = pairedAt.toUtc().millisecondsSinceEpoch ~/ 1000;
    if (!_inRange(pairedAtSecs)) {
      // Fail loudly here instead of having the receiver silently repair it.
      throw ArgumentError.value(
        pairedAt,
        '${argPrefix}pairedAt',
        'Pairing date must be between 1970 and 9999.',
      );
    }
    return <int>[
      ...sharedSecret,
      roleByte,
      labelBytes.length,
      ...labelBytes,
      ..._uint64BE(pairedAtSecs),
      silentHaptics ? 0x01 : 0x00,
    ];
  }

  static _DecodedRecord _decodeRecord(
    List<int> plaintext,
    int start, {
    required int version,
    required DateTime? now,
    required String where,
  }) {
    var cursor = start;
    // Fixed fields: 32 secret + 1 role + 1 label_len (+ label + 8 + 1).
    if (plaintext.length < cursor + _sharedSecretLength + 1 + 1) {
      throw InvalidPackageException('$where truncated: missing header.');
    }
    final sharedSecret = Uint8List.fromList(
        plaintext.sublist(cursor, cursor + _sharedSecretLength));
    cursor += _sharedSecretLength;
    // Validated after the extension area: a record a newer build marked
    // must-understand is skipped, whatever its fixed fields hold.
    final roleByte = plaintext[cursor++];
    final labelLen = plaintext[cursor++];
    if (plaintext.length < cursor + labelLen + _timestampLength + 1) {
      throw InvalidPackageException('$where truncated: body does not fit.');
    }
    final label = _decodeLabel(
      plaintext.sublist(cursor, cursor + labelLen),
      maxBytes: _maxSubLabelBytes,
    );
    cursor += labelLen;
    final pairedAtSecs =
        _uint64FromBE(plaintext.sublist(cursor, cursor + _timestampLength));
    cursor += _timestampLength;
    final silentHaptics = plaintext[cursor++] != 0;

    final DateTime pairedAt;
    final bool pairedAtRepaired;
    if (_inRange(pairedAtSecs)) {
      pairedAt =
          DateTime.fromMillisecondsSinceEpoch(pairedAtSecs * 1000, isUtc: true);
      pairedAtRepaired = false;
    } else {
      pairedAt = (now ?? DateTime.now()).toUtc();
      pairedAtRepaired = true;
    }

    var extensions = const <int, Uint8List>{};
    var unknownCritical = false;
    if (version != _versionV1) {
      final ext = _parseExtensions(plaintext, cursor);
      cursor = ext.end;
      extensions = ext.fields;
      unknownCritical = ext.unknownCritical;
    }
    final PairRole? role = switch (roleByte) {
      0x01 => PairRole.a,
      0x02 => PairRole.b,
      _ => null,
    };
    if (role == null && !unknownCritical) {
      throw InvalidPackageException(
        '$where has unknown role byte 0x${roleByte.toRadixString(16)}.',
      );
    }
    return _DecodedRecord(
      sharedSecret: sharedSecret,
      role: role,
      label: label.text,
      pairedAt: pairedAt,
      silentHaptics: silentHaptics,
      pairedAtRepaired: pairedAtRepaired,
      labelRepaired: label.repaired,
      extensions: extensions,
      unknownCritical: unknownCritical,
      end: cursor,
    );
  }

  /// Decode a label, repairing instead of failing: bytes beyond [maxBytes]
  /// (the encoder's own limit) are dropped and invalid UTF-8 is replaced
  /// with U+FFFD. Labels are display-only; a damaged one must not cost the
  /// user a secret. Only reachable after authentication, so only a buggy
  /// encoder that held the PAKE words can trigger it.
  static ({String text, bool repaired}) _decodeLabel(
    List<int> bytes, {
    required int maxBytes,
  }) {
    final truncated = bytes.length > maxBytes;
    final kept = truncated ? bytes.sublist(0, maxBytes) : bytes;
    try {
      return (text: utf8.decode(kept), repaired: truncated);
    } on FormatException {
      return (text: utf8.decode(kept, allowMalformed: true), repaired: true);
    }
  }

  static List<int> _encodeExtensions(
    int version,
    List<TransportExtension> extensions,
  ) {
    if (version == _versionV1) {
      if (extensions.isNotEmpty) {
        throw ArgumentError.value(
          extensions,
          'extensions',
          'Extensions require transport-package version 2.',
        );
      }
      return const <int>[];
    }
    final seen = <int>{};
    final body = <int>[];
    for (final e in extensions) {
      if (e.tag < 0 || e.tag > 0xFF) {
        throw ArgumentError.value(e.tag, 'extension.tag', 'Tag must be one byte.');
      }
      if (_reservedTags.contains(e.tag)) {
        throw ArgumentError.value(e.tag, 'extension.tag', 'Reserved tag.');
      }
      if (!seen.add(e.tag)) {
        throw ArgumentError.value(e.tag, 'extension.tag', 'Repeated tag.');
      }
      if (e.value.length > _maxExtBytes) {
        throw ArgumentError.value(
            e.value.length, 'extension.value.length', 'Too long.');
      }
      body
        ..add(e.tag)
        ..add((e.value.length >> 8) & 0xFF)
        ..add(e.value.length & 0xFF)
        ..addAll(e.value);
    }
    if (body.length > _maxExtBytes) {
      throw ArgumentError.value(body.length, 'extensions', 'Too long.');
    }
    return <int>[(body.length >> 8) & 0xFF, body.length & 0xFF, ...body];
  }

  static ({Map<int, Uint8List> fields, bool unknownCritical, int end})
      _parseExtensions(List<int> plaintext, int start) {
    if (plaintext.length < start + _extLenLength) {
      throw const InvalidPackageException(
          'Extension area truncated: missing length.');
    }
    final extLen = (plaintext[start] << 8) | plaintext[start + 1];
    final areaStart = start + _extLenLength;
    final areaEnd = areaStart + extLen;
    if (areaEnd > plaintext.length) {
      throw const InvalidPackageException('Extension area overruns payload.');
    }
    final fields = <int, Uint8List>{};
    var unknownCritical = false;
    var cursor = areaStart;
    while (cursor < areaEnd) {
      if (areaEnd - cursor < _tlvHeaderLength) {
        throw const InvalidPackageException('Extension field truncated.');
      }
      final tag = plaintext[cursor];
      if (_reservedTags.contains(tag)) {
        throw const InvalidPackageException('Extension uses a reserved tag.');
      }
      final len = (plaintext[cursor + 1] << 8) | plaintext[cursor + 2];
      cursor += _tlvHeaderLength;
      if (cursor + len > areaEnd) {
        throw const InvalidPackageException(
            'Extension field overruns its area.');
      }
      if (fields.containsKey(tag)) {
        throw const InvalidPackageException('Extension tag repeated.');
      }
      fields[tag] = Uint8List.fromList(plaintext.sublist(cursor, cursor + len));
      cursor += len;
      if (tag & criticalTagBit != 0 && !_knownCriticalTags.contains(tag)) {
        unknownCritical = true;
      }
    }
    return (
      fields: Map<int, Uint8List>.unmodifiable(fields),
      unknownCritical: unknownCritical,
      end: areaEnd,
    );
  }

  /// Encrypt an arbitrary [plaintext] as a package. Tests only: lets them
  /// build structurally malformed but correctly sealed packages (damaged
  /// dates, invalid labels, broken extension areas) that the public
  /// encoders refuse to produce.
  @visibleForTesting
  static Future<String> debugEncodeRaw({
    required int version,
    required TransportPayloadType payloadType,
    required List<int> plaintext,
    required List<String> pakeWords,
    DateTime? now,
  }) =>
      _encode(
        version: version,
        payloadType: switch (payloadType) {
          TransportPayloadType.ldp => _typeLdp,
          TransportPayloadType.lpr => _typeLpr,
          TransportPayloadType.blk => _typeBlk,
        },
        plaintext: plaintext,
        pakeWords: pakeWords,
        now: now,
      );

  static bool _inRange(int unixSeconds) =>
      unixSeconds >= 0 && unixSeconds <= _maxUnixSeconds;

  // ========================================================================
  // Internal encode/decode
  // ========================================================================

  static Future<String> _encode({
    required int version,
    required int payloadType,
    required List<int> plaintext,
    required List<String> pakeWords,
    DateTime? now,
    Random? nonceRandom,
  }) async {
    if (version != _versionV1 && version != _versionV2) {
      throw ArgumentError.value(version, 'version', 'Unsupported version.');
    }
    final normalized = normalizePakeWords(pakeWords);
    final nonce = _mintNonce(nonceRandom);
    final key = await _deriveKey(
      version: version,
      pakeWords: normalized,
      payloadType: payloadType,
      nonce: nonce,
    );
    final timestamp = now ?? DateTime.now();
    final header = <int>[
      version,
      payloadType,
      ..._uint64BE(timestamp.toUtc().millisecondsSinceEpoch ~/ 1000),
    ];
    final cipher = AesGcm.with256bits();
    final secretBox = await cipher.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: version == _versionV1 ? const <int>[] : header,
    );
    final body = <int>[
      ...header,
      ...nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ];
    return '$_prefix${_base64UrlNoPad(body)}';
  }

  static Future<_Opened> _decode({
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
    if (body.isEmpty) {
      throw const InvalidPackageException('Transport package body too short.');
    }
    // Version first, so even a truncated package from a newer Signet gets
    // the "update" message rather than a length error.
    final version = body[0];
    if (version > _versionV2) throw const UnsupportedPackageVersionException();
    if (version != _versionV1 && version != _versionV2) {
      throw InvalidPackageException(
        'Unsupported transport-package version 0x${version.toRadixString(16)}.',
      );
    }
    if (body.length < _headerLength + _nonceLength + _tagLength) {
      throw const InvalidPackageException('Transport package body too short.');
    }
    if (version == _versionV2 && _payloadTypeOf(body[1]) == null) {
      throw const UnsupportedPackageVersionException();
    }
    if (body[1] != expectedPayloadType) {
      throw InvalidPackageException(
        'Wrong payload type: expected 0x${expectedPayloadType.toRadixString(16)}, '
        'got 0x${body[1].toRadixString(16)}.',
      );
    }
    final header = body.sublist(0, _headerLength);
    final timestampSecs = _uint64FromBE(body.sublist(2, _headerLength));
    const nonceStart = _headerLength;
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
      version: version,
      pakeWords: normalized,
      payloadType: expectedPayloadType,
      nonce: nonce,
    );
    final cipher = AesGcm.with256bits();
    final List<int> plaintext;
    try {
      plaintext = await cipher.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(tag)),
        secretKey: SecretKey(key),
        aad: version == _versionV1 ? const <int>[] : header,
      );
    } on SecretBoxAuthenticationError {
      throw const InvalidPakeException(
        'PAKE secret is wrong (authentication tag did not verify).',
      );
    }
    // Checked after authentication: for version 2 the header is
    // authenticated; for version 1 it is not, and an out-of-range value
    // must surface as a malformed package rather than a RangeError.
    if (!_inRange(timestampSecs)) {
      throw const InvalidPackageException(
        'Transport package timestamp is out of range.',
      );
    }
    return _Opened(
      version: version,
      plaintext: plaintext,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        timestampSecs * 1000,
        isUtc: true,
      ),
    );
  }

  // ========================================================================
  // Helpers
  // ========================================================================

  static Future<List<int>> _deriveKey({
    required int version,
    required List<String> pakeWords,
    required int payloadType,
    required List<int> nonce,
  }) async {
    final kind = switch (payloadType) {
      _typeLdp => 'ldp',
      _typeLpr => 'lpr',
      _typeBlk => 'blk',
      _ => throw ArgumentError.value(
          payloadType,
          'payloadType',
          'Unknown transport-package payload type.',
        ),
    };
    final info = 'signet/v$version/tp1/$kind';
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

  /// Reads 8 big-endian bytes into a Dart int. A set high bit yields a
  /// negative value, which [_inRange] rejects.
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

class _Opened {
  const _Opened({
    required this.version,
    required this.plaintext,
    required this.timestamp,
  });

  final int version;
  final List<int> plaintext;
  final DateTime timestamp;
}

class _DecodedRecord {
  const _DecodedRecord({
    required this.sharedSecret,
    required this.role,
    required this.label,
    required this.pairedAt,
    required this.silentHaptics,
    required this.pairedAtRepaired,
    required this.labelRepaired,
    required this.extensions,
    required this.unknownCritical,
    required this.end,
  });

  final Uint8List sharedSecret;

  /// Null only when [unknownCritical] is set (the record will be skipped).
  final PairRole? role;
  final String label;
  final DateTime pairedAt;
  final bool silentHaptics;
  final bool pairedAtRepaired;
  final bool labelRepaired;
  final Map<int, Uint8List> extensions;
  final bool unknownCritical;
  final int end;
}

/// One extension field to write into a version 2 package. Set
/// [TransportPackage.criticalTagBit] in [tag] for must-understand fields.
/// Tags are registered in `docs/WIRE_FORMAT.md`.
class TransportExtension {
  const TransportExtension(this.tag, this.value);

  final int tag;
  final List<int> value;
}

// ============================================================================
// Result types
// ============================================================================

class LdpPackage {
  const LdpPackage({
    required this.publicKey,
    required this.labelHint,
    required this.timestamp,
    this.version = 1,
    this.extensions = const <int, Uint8List>{},
  });

  final Uint8List publicKey;
  final String labelHint;
  final DateTime timestamp;

  /// Wire version of this package. A response must be encoded with the
  /// same version so an older peer can read it.
  final int version;

  /// Non-critical extension fields (version 2), by tag.
  final Map<int, Uint8List> extensions;
}

class LprPackage {
  const LprPackage({
    required this.sharedSecret,
    required this.label,
    required this.role,
    required this.pairedAt,
    required this.silentHaptics,
    required this.timestamp,
    this.version = 1,
    this.pairedAtRepaired = false,
    this.labelRepaired = false,
    this.extensions = const <int, Uint8List>{},
  });

  final Uint8List sharedSecret;
  final String label;
  final PairRole role;
  final DateTime pairedAt;
  final bool silentHaptics;
  final DateTime timestamp;
  final int version;

  /// An invalid pairing date was reset to the import time.
  final bool pairedAtRepaired;

  /// An invalid label had characters replaced with U+FFFD.
  final bool labelRepaired;

  bool get repaired => pairedAtRepaired || labelRepaired;
  final Map<int, Uint8List> extensions;
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
    this.repaired = false,
    this.extensions = const <int, List<int>>{},
  });

  final Uint8List sharedSecret;
  final PairRole role;
  final String label;
  final DateTime pairedAt;
  final bool silentHaptics;

  /// Set on decode when the pairing date or label had to be repaired.
  final bool repaired;

  /// Extension fields by tag: populated on decode (version 2), written on
  /// encode (version 2 only). Nothing persists them, so they are not
  /// carried through a restore and re-export; a future field that must
  /// survive needs storage support of its own.
  final Map<int, List<int>> extensions;
}

class BlkPackage {
  const BlkPackage({
    required this.records,
    required this.timestamp,
    this.version = 1,
    this.skippedNeedsNewerVersion = 0,
  });

  final List<BlkRelationshipRecord> records;
  final DateTime timestamp;
  final int version;

  /// Records left out because they carry a must-understand field this
  /// build does not know. The user needs to update Signet to restore them.
  final int skippedNeedsNewerVersion;

  /// Records whose pairing date or label was repaired on decode.
  int get repairedCount => records.where((r) => r.repaired).length;
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

/// Thrown for a package written by a newer Signet: a wire version above
/// the ones this build reads, or a must-understand extension it does not
/// know. The UI should ask the user to update the app rather than calling
/// the package invalid.
///
/// [authenticated] is false when the verdict comes from the plaintext
/// version or payload-type byte, which anyone can set without the PAKE
/// words: the UI must then use cautious copy (a scammer could send such a
/// package and follow up with a fake "update"). It is true only when the
/// verdict comes from inside the authenticated payload (an unknown
/// must-understand extension), which only the PAKE holder can produce.
class UnsupportedPackageVersionException extends InvalidPackageException {
  const UnsupportedPackageVersionException({this.authenticated = false})
      : super('This package was made by a newer version of Signet.');

  final bool authenticated;

  @override
  String toString() => 'UnsupportedPackageVersionException: $message';
}
