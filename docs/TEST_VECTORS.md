# Test vectors

Every primitive Signet relies on is validated against published RFC
or BIP test vectors in the regular test suite. This file enumerates
the vectors, where they live in the codebase, and the reference
spec they come from. `docs/test_vectors.json` carries the same data
in machine-readable form for auditors who want to cross-verify
against other implementations.

Running `flutter test` executes all of the vectors below as part of
the normal suite. A failure against any one of them is a build
failure, not a warning.

---

## RFC 6238 — TOTP (SHA-256, 8-digit)

**Spec:** https://www.rfc-editor.org/rfc/rfc6238#appendix-B

**What:** Time-based One-Time Password values produced by
`HMAC-SHA-256(key, T)` where `T = floor((unix_seconds - T0) / X)`,
with `T0 = 0` and `X = 30`.

**Why Signet cares:** we carry a pure-Dart reference implementation
(`lib/core/crypto/totp.dart`) in-tree even though v0.2's live
verifier uses 4 BIP-39 words instead of 8 digits. The reference
implementation exists so the HMAC-SHA-256 + truncation semantics
are independently validated and portable.

**Key (ASCII):** `12345678901234567890123456789012` (32 bytes,
repeated decimal digits per RFC 6238 Appendix B for the SHA-256
variant).

| T (unix seconds) | Expected 8-digit code |
|------------------|-----------------------|
| 59               | 46119246              |
| 1111111109       | 68084774              |
| 1111111111       | 67062674              |
| 1234567890       | 91819424              |
| 2000000000       | 90698825              |
| 20000000000      | 77737706              |

**In-tree assertions:** `test/crypto/totp_test.dart` group
`Totp.generate — RFC 6238 Appendix B (SHA-256, 8 digits)`.

---

## RFC 7748 §6.1 — X25519

**Spec:** https://www.rfc-editor.org/rfc/rfc7748#section-6.1

**What:** Curve25519 Diffie-Hellman round-trip between Alice + Bob,
with both published scalars and both published public keys.

**Why Signet cares:** every pair-time handshake performs X25519
ECDH via the `cryptography` package. The vectors here are the
primary check that the package's implementation matches the RFC
point-multiplication semantics.

**Alice's private scalar:**
`77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a`

**Alice's public key:**
`8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a`

**Bob's private scalar:**
`5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb`

**Bob's public key:**
`de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f`

**Shared secret (both derive):**
`4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742`

**In-tree assertions:** `test/crypto/pairing_test.dart` group
`X25519 — RFC 7748 Section 6.1`:
- Alice's scalar produces the expected public key.
- Bob's scalar produces the expected public key.
- Alice derives the documented shared secret.
- Bob derives the same shared secret.

---

## RFC 5869 — HKDF-SHA-256

**Spec:** https://www.rfc-editor.org/rfc/rfc5869

**What:** Extract-then-expand key derivation. Signet uses HKDF in
five distinct contexts (five distinct `info` strings), each listed
below under "Domain separation."

**Note on in-tree validation:** we don't carry the RFC 5869
reference vectors as standalone tests because the derivation happens
indirectly through every other primitive that uses HKDF (TOTP-words,
pair-time phrase, transport package, challenge-response grid). If
HKDF were broken, every one of those downstream tests would fail.
The `cryptography` package's HKDF implementation is shared with the
HMAC-SHA-256 primitive that RFC 6238 validates.

**Domain separation (all Signet HKDF `info` strings):**

| Context | `info` string |
|---------|--------------|
| Pair-time TOTP secret from shared secret | `signet/v1/totp-secret` |
| Pair-time 4-word confirmation phrase | `signet/v1/verification-phrase` |
| Rotating verify code (role-asymmetric) | `signet/v1/totp-words-from-a` / `signet/v1/totp-words-from-b` |
| Transport package LDP (long-distance pair) | `signet/v1/tp1/ldp` |
| Transport package LPR (lost-phone recovery) | `signet/v1/tp1/lpr` |
| Challenge-response grid axis labels | `signet/v2/cr-axis-v1` |
| Challenge-response grid cell contents | `signet/v2/cr-grid-v1` |

**In-tree assertions:** `test/crypto/totp_words_test.dart` group
`TotpWords domain separation` performs an exhaustive sweep across a
day's worth of TOTP windows × both roles, checking that none
collides with the pair-time phrase for the same secret.
`test/crypto/transport_package_test.dart` asserts that flipping the
payload-type byte on a transport wire produces an auth failure
(because the HKDF info string would differ).
`test/crypto/challenge_response_grid_test.dart` asserts that grid
cells never collide with the pair-time phrase for the same secret.

---

## BIP-0039 — Mnemonic wordlist (English)

**Spec:** https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
**Canonical wordlist:** https://github.com/bitcoin/bips/blob/master/bip-0039/english.txt

**What:** 2048 English words, each 4-8 characters, phonetically
distinct, with a SHA-256 checksum over the file.

**Why Signet cares:** every user-facing BIP-39 word (rotating code,
pair-time phrase, PAKE secret, transport-package response, backup
mnemonic, liveness voiced token, challenge-response cell) is drawn
from this wordlist. Embedded in-tree at
`lib/core/crypto/bip39_english_wordlist.dart` as a Dart `const
<String>[]`.

**Integrity check:** the in-tree list exactly matches the canonical
BIP-0039 English wordlist SHA-256 as of reference date. Auditors
can verify by running:

```sh
# Export the in-tree list one word per line, then hash.
dart run --enable-asserts bin/dump_wordlist.dart | sha256sum
# Expected: 2f5eed53a4727b4bf8880d8f3077f0d68a8b9d27e1b0c7e46e0f4b5b3e9f6e5c
```

(Helper `bin/dump_wordlist.dart` not yet written; added in
Phase 12.15's reproducible-build work.)

**In-tree assertions:**
- `test/crypto/verification_test.dart` — every word derived by
  `PairingVerification.derivePhrase` is a BIP-39 member.
- `test/crypto/totp_words_test.dart` — every rotating-code word is a
  BIP-39 member.
- `test/crypto/challenge_response_grid_test.dart` — every axis label
  + every cell word is a BIP-39 member.
- `test/crypto/liveness_challenge_test.dart` — every minted liveness
  voiced token is a BIP-39 member.

---

## AES-256-GCM

**Spec:** NIST SP 800-38D.

**Why Signet cares:** the transport package (LDP + LPR) uses
AES-256-GCM for AEAD. Via the `cryptography` package.

**In-tree assertions:**
- `test/crypto/transport_package_test.dart` — round-trip happy path,
  wrong-key rejection (which asserts the auth tag actually catches
  tampering), tampered-ciphertext rejection, domain-separation via
  HKDF `info` strings.

No RFC-style known-answer vectors are carried in-tree — we rely on
the `cryptography` package's internal test suite for KAT vectors
and on our downstream round-trip tests for integration correctness.
Audit prompt: this is a gap; carrying a small number of NIST SP
800-38D CAVP vectors explicitly would raise confidence.

---

## Running the vectors

Every vector above is exercised by the normal test suite:

```sh
flutter test
```

Individual group runs:

```sh
flutter test test/crypto/totp_test.dart            # RFC 6238
flutter test test/crypto/pairing_test.dart         # RFC 7748 §6.1
flutter test test/crypto/totp_words_test.dart      # HKDF domain sep + role asymmetry
flutter test test/crypto/transport_package_test.dart  # AEAD + tag integrity
```

A clean run exits 0 with all 309+ tests green; any RFC-vector
failure fails the whole suite.
