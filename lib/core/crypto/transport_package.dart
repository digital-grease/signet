import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart' show visibleForTesting;

import 'pair_role.dart';
import 'wordlists.dart';

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
/// Version 1 packages (every backup made before 0.4.0) keep decoding
/// exactly as before. Everything 0.4.0 writes is version 2
/// ([TransportPackage.currentEncodeVersion]). Long-distance pairing
/// requests and responses also carry the strong-phrase tag
/// ([TransportPackage.encodeLdpRequest]); version 1 LDP is refused by
/// [TransportPackage.decodeLdpStrict].
///
/// `W_bytes` is the UTF-8 lowercased concatenation of the 8 BIP-39 words
/// separated by spaces, the same normalization applied on input, so the
/// same words always produce the same key regardless of whitespace or case.
///
/// See `transport_package_test.dart` for deterministic test vectors.
class TransportPackage {
  const TransportPackage._();

  static const String _prefix = 'signet:tp1:';

  /// Any transport-package scheme, this one or a later one
  /// (`signet:tp2:` and up, canonical decimal). A later scheme is from a
  /// newer Signet: decoders say "update Signet" instead of "not a Signet
  /// package" (plan Task 1.7j).
  static final RegExp _anySchemePrefix =
      RegExp(r'^signet:tp[1-9][0-9]*:');

  /// Whether [text] starts like a transport package of this or a later
  /// scheme. For finding packages in files, QR codes and pasted text.
  static bool isTransportWire(String text) =>
      _anySchemePrefix.hasMatch(text);

  /// Throws [UnsupportedPackageVersionException] when [wire] uses a later
  /// scheme than `signet:tp1:`.
  static void _refuseLaterScheme(String wire) {
    if (!wire.startsWith(_prefix) && isTransportWire(wire)) {
      throw const UnsupportedPackageVersionException();
    }
  }
  static const int _versionV1 = 0x01;
  static const int _versionV2 = 0x02;

  /// Version written by the encoders: 2 from 0.4.0, for backups (LPR,
  /// BLK) as for long-distance pairing. Decoders accept 1 and 2, so
  /// backups made by 0.3.6 and older still restore; a 0.4.0 backup needs
  /// 0.4.0 or later.
  static const int currentEncodeVersion = _versionV2;

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

  /// The longest LDP label hint, in UTF-8 bytes.
  static const int maxLabelHintBytes = _maxLabelBytes;
  static const int _maxSubLabelBytes = 64;
  static const int _blkCountPrefixLength = 2;
  static const int _blkMaxRecords = 255;
  static const int _extLenLength = 2;
  static const int _tlvHeaderLength = 3;
  static const int _maxExtBytes = 0xFFFF;

  /// Tag bit marking a must-understand extension.
  static const int criticalTagBit = 0x80;

  /// Critical: long-distance pairing uses the strong (8-word) phrase
  /// (plan Task 1.7g). Value: one byte, the phrase scheme; 0x01 is the
  /// 8-word transcript-bound phrase (`PairingVerification
  /// .deriveLongDistancePhrase`). Every request and response carries it,
  /// and both sides refuse a package without it, so it cannot be stripped
  /// to force the weak phrase. Registered in docs/WIRE_FORMAT.md.
  static const int ldpStrongPhraseTag = 0x81;
  static const int _ldpStrongPhraseScheme = 0x01;
  static const TransportExtension _ldpStrongPhrase = TransportExtension(
    ldpStrongPhraseTag,
    <int>[_ldpStrongPhraseScheme],
  );

  /// Non-critical: the word-list id a contact's words use (`en`, `fr`;
  /// [WordList.id]), as UTF-8, in each LPR and BLK record (older builds
  /// ignore it and restore the contact as English) and as a display-only
  /// hint in LDP requests and responses. Registered in
  /// docs/WIRE_FORMAT.md.
  static const int wordListTag = 0x01;

  /// The [wordListTag] extension for word-list [id].
  static TransportExtension wordListExtension(String id) =>
      TransportExtension(wordListTag, utf8.encode(id));

  /// The word-list id in [extensions], or null when there is none (a
  /// package from v0.4.0 or earlier). A well-formed id this version does
  /// not know is returned as it is, so a re-export carries it on. Anything
  /// else (not UTF-8, wrong characters, too long) is a damaged tag and
  /// comes back as [damagedWordListId]: short, so a hostile 64 KB value
  /// cannot later make every backup too long, and never a real id, so the
  /// contact's words are not shown in a wrong list. Never throws: a bad
  /// tag must not cost the user the secret.
  static String? wordListIdOf(Map<int, List<int>> extensions) {
    final value = extensions[wordListTag];
    if (value == null) return null;
    final String text;
    try {
      text = utf8.decode(value);
    } on FormatException {
      return damagedWordListId;
    }
    return _wordListIdPattern.hasMatch(text) ? text : damagedWordListId;
  }

  /// What [wordListIdOf] returns for a damaged tag. It breaks the id
  /// grammar on purpose, so no list can ever have it.
  static const String damagedWordListId = '!';

  /// A registered word-list id (docs/WIRE_FORMAT.md).
  static final RegExp _wordListIdPattern = RegExp(r'^[a-z0-9-]{2,16}$');

  /// Critical tags this build understands, per payload type; any other
  /// critical tag is refused with an "update Signet" error. Per type so a
  /// tag understood in one payload is never silently ignored in another.
  static const Set<int> _ldpKnownCriticalTags = <int>{ldpStrongPhraseTag};
  static const Set<int> _recordKnownCriticalTags = <int>{};

  /// Never valid on the wire (see `docs/WIRE_FORMAT.md`).
  static const Set<int> _reservedTags = <int>{0x00, 0x80};

  /// Latest representable unix second (9999-12-31T23:59:59Z).
  static const int _maxUnixSeconds = 253402300799;

  // ========================================================================
  // Payload-type peek (for import dispatch)
  // ========================================================================

  /// Inspect a wire string's payload-type byte without attempting
  /// decryption. Returns `null` if the wire is structurally malformed
  /// (wrong scheme, unparseable base64, too short, unknown payload type in
  /// a version this build reads). Throws [UnsupportedPackageVersionException]
  /// for a package written by a newer Signet (a later scheme prefix, a
  /// version above 2, or an unknown payload type in version 2), so the
  /// UI can say "update the app" instead of "not a valid backup".
  ///
  /// The version + payload-type bytes precede the AEAD-sealed body, so
  /// this peek is safe without the PAKE secret.
  static TransportPayloadType? peekPayloadType(String wire) {
    _refuseLaterScheme(wire);
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

  /// Mint a fresh 8-word PAKE secret from a cryptographically-secure RNG,
  /// spelled in [list] (English when null). Each call returns a new list.
  /// The encoders take the words in any shipped list and key on their
  /// English rendering ([normalizePakeWords]), so the list changes only
  /// what the user sees and types.
  static List<String> mintPakeWords({
    Random? random,
    int wordCount = _pakeWordCount,
    WordList? list,
  }) {
    final rng = random ?? Random.secure();
    return (list ?? WordList.english).render(
      List<int>.generate(wordCount, (_) => rng.nextInt(WordList.size)),
    );
  }

  /// Every reading of a user-entered PAKE phrase, each as the English
  /// rendering of its indices (the form the key is derived from). The
  /// words may come from any shipped list ([WordList.shipped]), accented or
  /// not, but all 8 from the same list; there is one reading per list in
  /// which all 8 are valid, English first, so English input reads exactly
  /// as before. More than one reading only when every word is in two
  /// lists, about 2^-32 for random French words.
  ///
  /// Throws [InvalidPakeException] on the wrong count, an unknown word or
  /// a phrase mixing lists. Messages name the position, never the word:
  /// they reach the screen and debug logs.
  static List<List<String>> pakeCandidates(List<String> words) {
    if (words.length != _pakeWordCount) {
      throw InvalidPakeException(
        'PAKE secret must be exactly $_pakeWordCount words; got ${words.length}.',
      );
    }
    final trimmed = [for (final w in words) w.trim()];
    final readings = <List<String>>[];
    for (final list in WordList.shipped) {
      final indices = [for (final w in trimmed) list.indexOf(w)];
      if (indices.contains(null)) continue;
      readings.add([for (final i in indices) WordList.english.wordAt(i!)]);
    }
    if (readings.isNotEmpty) return readings;
    // Seven words of one list and one that is not: that one is a typo,
    // even when it happens to be a word of another list (a pinyin reading
    // of zh-1, say). Point at it rather than at "mixed languages".
    for (final list in WordList.shipped) {
      final outside = [
        for (var i = 0; i < trimmed.length; i++)
          if (!list.contains(trimmed[i])) i,
      ];
      if (outside.length == 1) {
        throw InvalidPakeException(
          'Word ${outside.single + 1} is not in a supported BIP-39 wordlist.',
          reason: InvalidPakeReason.unknownWord,
          slot: outside.single + 1,
        );
      }
    }
    for (var i = 0; i < trimmed.length; i++) {
      if (!WordList.shipped.any((l) => l.contains(trimmed[i]))) {
        throw InvalidPakeException(
          'Word ${i + 1} is not in a supported BIP-39 wordlist.',
          reason: InvalidPakeReason.unknownWord,
          slot: i + 1,
        );
      }
    }
    throw const InvalidPakeException(
      'The words mix languages; all $_pakeWordCount must be in one language.',
      reason: InvalidPakeReason.mixedLanguages,
    );
  }

  /// The reading encoders key on: the first of [pakeCandidates], so
  /// English words are used exactly as given and French words become their
  /// English rendering.
  static List<String> normalizePakeWords(List<String> words) =>
      pakeCandidates(words).first;

  // ========================================================================
  // LDP — long-distance pairing
  // ========================================================================

  /// Encode an LDP package carrying [publicKey] (32 bytes X25519) and a
  /// short [labelHint] (≤32 UTF-8 bytes). The caller chooses [pakeWords]
  /// via [mintPakeWords] and communicates them to the receiver OOB.
  ///
  /// The pairing screens use [encodeLdpRequest] and [encodeLdpResponse],
  /// which fix version 2 and the strong-phrase tag; this general form is
  /// for tests and fixtures. [extensions] are version 2 only.
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
      final ext = _parseExtensions(
        plaintext,
        cursor,
        known: _ldpKnownCriticalTags,
      );
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
      verifiedPakeWords: opened.pakeWords,
    );
  }

  /// A long-distance pairing request: tp1 version 2 with the critical
  /// strong-phrase tag. A receiver on Signet 0.3.6 or older cannot read
  /// version 2 (its generic error); one that reads version 2 but not this
  /// tag refuses it as needing a newer Signet.
  ///
  /// [wordListId]: the sender's word language for this pair, carried as
  /// [wordListTag] to preselect the receiver's language row. Display
  /// only: a stripped or forged hint can only make the phrases differ.
  static Future<String> encodeLdpRequest({
    required List<int> publicKey,
    required String labelHint,
    required List<String> pakeWords,
    String? wordListId,
    DateTime? now,
    Random? nonceRandom,
  }) => encodeLdp(
    publicKey: publicKey,
    labelHint: labelHint,
    pakeWords: pakeWords,
    now: now,
    nonceRandom: nonceRandom,
    version: _versionV2,
    extensions: <TransportExtension>[
      _ldpStrongPhrase,
      if (wordListId != null) wordListExtension(wordListId),
    ],
  );

  /// The response to a request accepted by [decodeLdpStrict]: same
  /// version and tag. The receiver's own label is never sent.
  /// [wordListId] is the receiver's final word language, a display-only
  /// hint as in [encodeLdpRequest].
  static Future<String> encodeLdpResponse({
    required List<int> publicKey,
    required List<String> pakeWords,
    String? wordListId,
    DateTime? now,
    Random? nonceRandom,
  }) => encodeLdp(
    publicKey: publicKey,
    labelHint: '',
    pakeWords: pakeWords,
    now: now,
    nonceRandom: nonceRandom,
    version: _versionV2,
    extensions: <TransportExtension>[
      _ldpStrongPhrase,
      if (wordListId != null) wordListExtension(wordListId),
    ],
  );

  /// [decodeLdp], then require the strong-phrase tag. Without it the
  /// package came from an older Signet (or someone holding the 8 words
  /// stripped it): [OutdatedPeerPackageException], never a fallback to the
  /// weak 4-word phrase. An unknown scheme value means a newer Signet; a
  /// value that is not exactly one byte is malformed.
  static Future<LdpPackage> decodeLdpStrict(
    String wire, {
    required List<String> pakeWords,
  }) async {
    final ldp = await decodeLdp(wire, pakeWords: pakeWords);
    final scheme = ldp.extensions[ldpStrongPhraseTag];
    if (ldp.version < _versionV2 || scheme == null) {
      throw const OutdatedPeerPackageException();
    }
    if (scheme.length != 1) {
      // Malformed, not newer: an update would not help.
      throw const InvalidPackageException(
        'Strong-phrase extension has a malformed value.',
      );
    }
    if (scheme[0] != _ldpStrongPhraseScheme) {
      throw const UnsupportedPackageVersionException(authenticated: true);
    }
    return ldp;
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
      final ext = _parseExtensions(
        plaintext,
        cursor,
        known: _recordKnownCriticalTags,
      );
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
      _parseExtensions(List<int> plaintext, int start,
          {required Set<int> known}) {
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
      if (tag & criticalTagBit != 0 && !known.contains(tag)) {
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
    _refuseLaterScheme(wire);
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

    // Each reading of the words (normally one) until the tag verifies.
    final cipher = AesGcm.with256bits();
    List<int>? plaintext;
    late List<String> verifiedWords;
    for (final reading in pakeCandidates(pakeWords)) {
      final key = await _deriveKey(
        version: version,
        pakeWords: reading,
        payloadType: expectedPayloadType,
        nonce: nonce,
      );
      try {
        plaintext = await cipher.decrypt(
          SecretBox(ciphertext, nonce: nonce, mac: Mac(tag)),
          secretKey: SecretKey(key),
          aad: version == _versionV1 ? const <int>[] : header,
        );
        verifiedWords = reading;
        break;
      } on SecretBoxAuthenticationError {
        continue;
      }
    }
    if (plaintext == null) {
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
      pakeWords: verifiedWords,
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
    required this.pakeWords,
    required this.timestamp,
  });

  final int version;
  final List<int> plaintext;

  /// The reading of the user's words that verified, in English.
  final List<String> pakeWords;
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
    required this.verifiedPakeWords,
  });

  final Uint8List publicKey;
  final String labelHint;
  final DateTime timestamp;

  /// The words that opened this package, as the English rendering of their
  /// indices. The response must be encoded with these, never with the
  /// receiver's typed words, so it is keyed on the reading that verified.
  final List<String> verifiedPakeWords;

  /// Wire version of this package. A response must be encoded with the
  /// same version so an older peer can read it.
  final int version;

  /// Extension fields (version 2), by tag.
  final Map<int, Uint8List> extensions;

  /// Carries the strong-phrase tag (see [TransportPackage.ldpStrongPhraseTag]).
  bool get hasStrongPhrase =>
      extensions.containsKey(TransportPackage.ldpStrongPhraseTag);
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
/// Why the 8 words were refused, for screens that explain it in the
/// user's language. Null for wrong count and wrong words, whose message the
/// screens show as before.
enum InvalidPakeReason {
  /// [InvalidPakeException.slot] (1-based) is not a word of any list.
  unknownWord,

  /// Every word is a list word, but not all 8 from the same list.
  mixedLanguages,
}

class InvalidPakeException implements Exception {
  const InvalidPakeException(this.message, {this.reason, this.slot});
  final String message;
  final InvalidPakeReason? reason;

  /// 1-based position of the word for [InvalidPakeReason.unknownWord].
  final int? slot;

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

/// Thrown for a long-distance pairing package from an older Signet: no
/// strong-phrase tag (version 1, or version 2 without it). Long-distance
/// pairing needs both phones on Signet 0.4.0 or later. Authenticated (only
/// the 8-word holder can make such a package), but it may also be a
/// downgrade attempt by someone who has the words, so the UI must not offer
/// any way to continue.
class OutdatedPeerPackageException extends InvalidPackageException {
  const OutdatedPeerPackageException()
    : super('This package was made by an older version of Signet.');

  @override
  String toString() => 'OutdatedPeerPackageException: $message';
}
