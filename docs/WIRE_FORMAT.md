# Signet wire formats

This document specifies the byte layouts Signet exchanges between devices or
with the user. It is the reference for the extension tag registry and for
anyone writing an independent implementation. Code: `lib/core/crypto/`
and `lib/features/pairing/pairing_code_v2.dart`. Test vectors:
`test/crypto/transport_package_test.dart` (compatibility fixtures and the
version 2 golden vector), `test/crypto/verification_v2_test.dart`
(pair-time phrases, including a pinned Argon2id vector) and
`test/features/pairing_code_v2_test.dart`.

## In-person pairing codes: `signet:p2:`

In-person pairing (and in-person rekey) is a commit-then-reveal exchange
of three codes, after ZRTP (RFC 6189 section 4.4.1.1). One phone taps
Start, the other Join.

```
signet:p2:<kind>:<base64url, no padding, of body>

kind  body                                  shown by
C     commitment, 32 bytes                  Start, step 1
K     X25519 public key, 32 bytes           Join, step 2
R     public key (32) || nonce (16)         Start, step 3

commitment = SHA-256("signet/v2/commit" || public key || nonce)
```

The domain string is ASCII with no terminator; every field has a fixed
length, so the hash input needs no length prefixes.

1. Start mints a key pair and a 16-byte random nonce and shows `C`.
2. Join, only after accepting a `C`, mints its key pair and shows `K`.
3. Start, after accepting exactly one `K`, shows `R`. Join checks that
   `R` opens the commitment; if not, the attempt ends with a tamper
   message.
4. Both phones derive the in-person pair-time phrase (below) and the two
   people compare it side by side.

A man-in-the-middle must hand Join a commitment before Join's key exists,
and hand Start a substitute key before Start's key is revealed, so it has
one blind guess at a 44-bit phrase per attempt.

Rules:

- Keys and the nonce are single-use: every abort, timeout, restart,
  tamper error or wrong-role code ends the attempt and discards them.
  Going back to show one's own code again re-shows the same code and
  reveals nothing new.
- A second, different code of a kind already accepted ends the attempt.
  The identical code scanned again is ignored, and a damaged or foreign
  code is reported and changes nothing.
- There is no fallback to the old protocol. A `signet:p1:` code (Signet
  0.3.6 and older) is refused with "the other phone needs to update
  Signet".

Decoding:

- Whitespace (including no-break space and line breaks) and zero-width
  characters are removed from the input first; messaging apps insert
  them, and a real code never contains them.
- The body must be canonical unpadded base64url: no `+`, `/` or `=`, and
  re-encoding the decoded bytes must give back the same text, so each
  code has exactly one spelling.
- Public keys must have the top bit (bit 7 of the last byte) clear.
  X25519 ignores that bit while the phrase transcript hashes the raw
  bytes, so this removes the cheapest way to give the two phones
  different transcripts for one shared secret.
- The receiving phone also applies the low-order and reflected-key
  checks described in `docs/THREAT_MODEL.md` section 3.1.
- `signet:pN:` with N above 2 (canonical decimal, no leading zero), or a
  `signet:p2:` code with an unknown upper-case kind letter, means "this
  phone needs to update Signet". Any other damage is "incomplete or
  damaged, try again". More than one `signet:` code in one paste is
  refused.

## Pair-time phrases

Both phones derive the phrase they compare from the X25519 output (the
32-byte shared secret) and a transcript salt that binds both public keys:

```
transcript = SHA-256("signet/v2/transcript" || key_low || key_high || nonce)
```

`key_low` and `key_high` are the two 32-byte public keys in byte order,
so both phones compute the same value whichever key is theirs. `nonce` is
Start's 16-byte commitment nonce in person, and empty for long distance.

Words are taken from the derived bytes 11 bits at a time, most
significant bit first, as indexes into the BIP-39 English wordlist.

**In person (4 words):**

```
ikm    = HKDF-SHA-256(ikm = shared secret, salt = transcript,
                      info = "signet/v2/verification-phrase/qr", length = 32)
output = Argon2id(password = ikm, salt = transcript, no secret, no
                  associated data, memory = 19456 KiB, iterations = 2,
                  parallelism = 1, version 0x13, length = 6)
words  = top 44 bits of output
```

The Argon2id parameters are part of the protocol: both phones must use
the same ones.

**Long distance (8 words):**

```
bytes = HKDF-SHA-256(ikm = shared secret, salt = transcript,
                     info = "signet/v2/verification-phrase/ldp", length = 11)
words = all 88 bits
```

**Re-check (4 words):** the "check the pairing phrase again" screen shows
the older phrase, `HKDF-SHA-256(ikm = shared secret, salt = empty, info =
"signet/v1/verification-phrase", length = 6)`, because the transcript is
not stored. It can differ from the words shown at pairing time.

## Transport package: `signet:tp1:`

One envelope carries three payload types: LDP (long-distance pairing), LPR
(single-relationship backup) and BLK (bulk backup).

A later scheme prefix (`signet:tpN:` with N of 2 or more, canonical
decimal) is from a newer Signet: decoders report "needs a newer version of
Signet" rather than "not a Signet package", and the backup file reader and
QR scanner accept it so that message can be shown.

```
signet:tp1:<base64url, no padding, of body>

body:
  [1]   version        0x01 or 0x02
  [1]   payload type   0x01 LDP, 0x02 LPR, 0x03 BLK
  [8]   timestamp      unix seconds, big-endian
  [12]  AEAD nonce
  [N]   AES-256-GCM ciphertext
  [16]  AES-256-GCM tag
```

Key: `HKDF-SHA-256(ikm = UTF-8 of the 8 lowercased BIP-39 PAKE words joined
by single spaces, salt = nonce, info = "signet/v<version>/tp1/<ldp|lpr|blk>",
length = 32)`.

The words in `ikm` are always the **English** rendering of the words'
11-bit indices. From 0.4.0 a decoder also accepts the 8 words in any list
it ships (English and French), accented or not, and composed (NFC) or
decomposed (NFD): each word is folded (lowercase, zero-width and
soft-hyphen characters removed, accents removed), looked up, and all 8 must
come from one list. The indices are then rendered in English for `ikm`, so
the key, and every byte on the wire, is the same whichever language the
words were typed in. If the 8 words are valid in more than one list (each
reading is different indices), the decoder tries each reading, English
first, until the tag verifies, and a long-distance response is encoded
with the reading that verified. Encoders in 0.4.0 still mint and show
English words.

### Version 1

The header (version, payload type, timestamp) is **not** authenticated. The
payload type is bound indirectly through the HKDF info string; the
timestamp can be altered without detection. No decoder logic depends on the
timestamp. Signet 0.4.0 and later no longer write version 1, but decode
it indefinitely so older backups still restore. Long-distance pairing is
the exception: a version 1 LDP package is refused (below).

### Version 2

- The 10 header bytes are passed to AES-GCM as associated data: changing
  any of them fails authentication.
- The version number is part of the HKDF info string, so relabelling a
  version 2 package as version 1 (or the reverse) also fails.
- Each LDP and LPR payload, and each BLK record, ends with an extension
  area (below).

Rollout (0.4.0):

- **Long-distance pairing** requests and responses are version 2 and
  carry the critical strong-phrase tag `0x81` (registry below). Both
  sides decode strictly: a version 1 package, or a version 2 package
  without the tag, is refused as "made by an older version of Signet",
  never answered with the old 4-word phrase. Someone holding the 8 PAKE
  words could re-encrypt a package without the tag; refusing it closes
  that downgrade. Signet 0.3.6 cannot read version 2, so long-distance
  pairing needs both phones on 0.4.0 or later.
- **Backups** (LPR, BLK) are encoded as version 2; decoders read
  versions 1 and 2. A backup made with 0.4.0 needs Signet 0.4.0 or later
  to restore; 0.3.6 and older report it as not a valid package.

A verdict of "needs a newer Signet" can come from two places. From the
scheme prefix or the plaintext version or type byte it is unauthenticated (anyone can set those
bytes without the PAKE words), so the app shows cautious copy that warns
against update links or files. From an unknown must-understand extension
it comes from inside the authenticated payload, and the app uses plain
copy.

### Payloads

```
LDP:  [32] X25519 public key
      [1]  label hint length L (<= 32)
      [L]  label hint, UTF-8
      v2:  extension area

LPR:  record (below), v2: extension area

BLK:  [2]  record count, big-endian (<= 255 on encode)
      repeat: record, v2: extension area after each record

record:
      [32] shared secret
      [1]  role (0x01 a, 0x02 b)
      [1]  label length L (<= 64)
      [L]  label, UTF-8
      [8]  pairedAt, unix seconds, big-endian
      [1]  silent haptics (0x00 / 0x01)
```

A version 1 LDP or LPR with bytes after the last field is rejected. In
version 2 the extension area must end exactly at the end of the payload
(LDP, LPR) or of the record.

### Extension area (version 2)

```
[2]       ext_len, big-endian
[ext_len] fields, each:
          [1]   tag
          [2]   value length, big-endian
          [len] value
```

Rules:

- Tag bit `0x80` marks a **must-understand** (critical) field. A decoder
  that does not know a critical tag rejects the package (LDP, LPR) or skips
  that record (BLK) and tells the user to update Signet. Unknown
  non-critical tags are ignored and exposed to the caller.
- Extensions only add information; they never override a fixed field.
- A structurally broken area rejects the whole package: `ext_len` running
  past the payload, a field header or value running past the area, a
  repeated tag, a reserved tag (`0x00`, `0x80`), or a missing `ext_len`.
- A BLK record carrying an unknown must-understand field is skipped before
  its fixed fields are validated (a newer build may use them differently).
- Fields that change security behaviour (protocol version, rekey or
  suspension state) must be critical, so an older decoder cannot silently
  drop them.

### Decoding damaged fields

The payload is authenticated, so a malformed field inside it can only come
from whoever holds the PAKE words (a buggy encoder or a newer build), not
from an attacker. Signet repairs rather than rejects:

- a `pairedAt` that is negative or after 9999-12-31 is reset to the import
  time (`pairedAtRepaired`);
- a label longer than the encoder's limit (32 bytes for an LDP hint, 64 for
  a record label) is truncated to it, and invalid UTF-8 is replaced with
  U+FFFD (`labelRepaired`).

The import screens tell the user which repair happened (bulk restore marks
each repaired row FIXED). The secret itself is never altered. LDP hint
repairs are not flagged: the hint only pre-fills a name the user confirms.
An out-of-range **header** timestamp is rejected as a malformed package,
and encoders refuse a `pairedAt` outside 1970-9999 so their own bugs fail
loudly instead of being repaired downstream.

## Extension tag registry

| Tag | Critical | Name | Payloads | Value | Since |
|---|---|---|---|---|---|
| `0x01` | no | Word-list id | LPR, BLK record | UTF-8 registered word-list id: `en` (BIP-39 English), `fr` (BIP-39 French). Ids match `[a-z0-9-]{2,16}`. A missing tag means `en`. A well-formed id the decoder does not know is kept on the contact and written back on re-export; its words cannot be shown until Signet is updated. Any other value (not UTF-8, other characters, wrong length) is a damaged tag: the contact keeps its secret and is marked damaged (stored and re-exported as `!`, which no id can be). | 0.5.0 |
| `0x81` | yes | Strong pair-time phrase | LDP | 1 byte, the phrase scheme: `0x01` = the 8-word long-distance phrase above. A value that is not exactly one byte is a damaged package; another scheme value needs a newer Signet. | 0.4.0 |

Known critical tags are per payload type. `0x81` is understood only in
LDP; in an LPR it rejects the package, and in a BLK record it skips the
record, as any unknown critical tag does.

Allocate tags here before using them. Non-critical tags use `0x01`-`0x7F`;
critical tags use `0x81`-`0xFF`. Tags `0x00` and `0x80` are reserved:
encoders refuse them and decoders reject a package that contains them.
