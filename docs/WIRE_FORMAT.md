# Signet wire formats

This document specifies the byte layouts Signet exchanges between devices or
with the user. It is the reference for the extension tag registry and for
anyone writing an independent implementation. Code: `lib/core/crypto/`.
Test vectors: `test/crypto/transport_package_test.dart` (compatibility
fixtures and the version 2 golden vector).

## Pairing QR: `signet:p1:`

```
signet:p1:<base64url, no padding, of the 32-byte X25519 public key>
```

The receiving device rejects a key whose X25519 output with its own private
key is all zeros (a low-order point) or equals the output of its own public
key (a reflected key). See `docs/THREAT_MODEL.md` §3.1.

## Transport package: `signet:tp1:`

One envelope carries three payload types: LDP (long-distance pairing), LPR
(single-relationship backup) and BLK (bulk backup).

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

### Version 1

The header (version, payload type, timestamp) is **not** authenticated. The
payload type is bound indirectly through the HKDF info string; the
timestamp can be altered without detection. No decoder logic depends on the
timestamp. Version 1 is still produced by this release's encoders and is
decoded indefinitely.

### Version 2

- The 10 header bytes are passed to AES-GCM as associated data: changing
  any of them fails authentication.
- The version number is part of the HKDF info string, so relabelling a
  version 2 package as version 1 (or the reverse) also fails.
- Each LDP and LPR payload, and each BLK record, ends with an extension
  area (below).
- An LDP response is encoded with the version of the request it answers,
  so a peer on an older build can always open it.

Rollout:

- v0.3.7 decodes versions 1 and 2 and still encodes version 1 everywhere.
- From the next release, **backups** (LPR, BLK) are encoded as version 2.
  A version 2 backup needs Signet 0.3.7 or later to restore; older builds
  report it as "not a Signet backup". The release notes must say so.
- **LDP requests** stay at version 1 until a version 2 field is actually
  needed. Mirroring only protects an *older initiator*: a newer initiator
  sending a version 2 request to a pre-0.3.7 peer would fail. LDP
  responses always mirror the request.

A verdict of "needs a newer Signet" can come from two places. From the
plaintext version or type byte it is unauthenticated (anyone can set those
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
| (none yet) | | | | | |

Allocate tags here before using them. Non-critical tags use `0x01`-`0x7F`;
critical tags use `0x81`-`0xFF`. Tags `0x00` and `0x80` are reserved:
encoders refuse them and decoders reject a package that contains them.
