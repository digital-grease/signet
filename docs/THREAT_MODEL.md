# Signet threat model

This document is the authoritative summary of what Signet defends
against, what it explicitly does not, and what it assumes about the
platforms it runs on. It is written for reviewers — an external
auditor should be able to read this file alone and understand the
security posture without chasing references.

Cross-references point to: source code (`lib/...`), test suites
(`test/...`), and design spikes (`.devloop/spikes/...`). The spikes
document the *history* of each decision; this file documents the
current state.

---

## 1. What Signet is, in threat-model terms

Signet is a per-pair symmetric shared-secret primitive. Two devices
exchange X25519 public keys either in person (QR) or at distance
(transport package), derive a shared secret via ECDH, and subsequently
prove liveness to each other via:

- A **rotating 4-word verification code** derived HKDF-from-secret +
  a time window + a role byte. Each side of the pair emits different
  words per window.
- A one-time **pair-time 4-word confirmation phrase** derived from
  the same secret, used at pair commitment and later re-check.
- A deterministic **challenge-response grid** derived from the same
  secret, used as a paper fallback when a responder has no phone.

Signet is **not** a messaging app, a VPN, or an account-MFA system.
Its single purpose is to let two humans, over any communication
channel, prove to each other that they are who they claim to be —
specifically against an attacker who can impersonate voice or video
in real time.

## 2. Adversary model

### 2.1 Canonical adversary A₁ — the real-time deepfake caller

**Capabilities:** can produce a real-time synthetic voice that sounds
like a specific target. May additionally produce real-time video
puppetry. Has scraped biographical information about the target from
social media / data brokers. Possesses the target's phone number
(or has spoofed it).

**Does NOT have:** physical access to the target's unlocked paired
device. Does not have Signet's shared secret.

**What Signet proves:** the rotating 4-word verification code cannot
be produced without the shared secret. A₁ cannot produce valid words.
The verifier types what A₁ claims, Signet returns ❌ "Not verified —
be suspicious" with haptic + live-region semantics.

**Relevant code:**
- `lib/core/crypto/totp_words.dart` — derivation + constant-time compare
- `lib/features/verify/verify_screen.dart` — UI + banner
- `test/crypto/totp_words_test.dart` — 28 tests incl. RFC-vector-based
  HKDF + per-role asymmetry

### 2.2 Reflection attacker A₂ — "read me your words first"

**Capabilities:** during a call, says to the verifier "grandma,
before we talk, read me your words so I know it's really you." Hopes
to receive the current code from the verifier's screen and echo it
back to pass.

**What Signet proves:** the rotating code is **role-asymmetric**.
Each device derives its role (`a` or `b`) at pair commit time from
the byte-lexicographic ordering of the two X25519 public keys; HKDF
info string is role-suffixed (`signet/v1/totp-words-from-a` vs
`-from-b`). A reflected candidate fails immediately because A→B
words ≠ B→A words for any given window.

**Relevant code:**
- `lib/core/crypto/pair_role.dart` — byte-lex role assignment
- `lib/features/pairing/pair_confirm_screen.dart` — role commit
- `test/crypto/totp_words_test.dart` — `per-role asymmetry
  (reflection-attack defense)` group

### 2.3 AI-capable, secret-less video attacker A₃

**Capabilities:** real-time voice + video deepfake of the target
(ElevenLabs-class audio + commodity face-reenactment pipelines). Can
respond in ~500ms to any spoken challenge. Knows biographical details
about the target. **Does NOT possess** the paired device, the shared
secret, or the target's Signet installation.

**What Signet proves:** the verify screen's "video mode" toggle folds
a secret-derived physical action into the rotating-word check. When
enabled, passing requires BOTH (a) the counterparty speaks the
role-asymmetric 4-word code for the current window (~44 bits, defeats
A₁-class attackers without the secret), AND (b) the counterparty
performs a specific physical action (one of 8, derived from the same
secret via HKDF info `signet/v2/liveness-action-from-{role}`) which
the verifier visually confirms on video. Combined attack probability
for a secret-less A₃ = 1/2⁴⁷ per 30-second window — order-of-magnitude
hardening over the pre-v0.3-Phase-14 prompt-only flow, which offered
no cryptographic defense against a realtime-deepfake A₃ (the prompt
itself was minted with local `Random.secure()` on the verifier's
device).

**What this does NOT defend against:** paired-device compromise
(A₇), co-located accomplice watching the counterparty's screen
during the active window (a physical co-location attack, out of
scope). Camera-integrated automated action grading is explicitly
deferred to a later plan.

**Relevant code:**
- `lib/core/crypto/totp_words.dart` — `deriveLivenessAction` +
  `verifyLivenessAction` + role-asymmetric HKDF info string
- `lib/core/crypto/liveness_challenge.dart` — `LivenessAction`
  enum (accessibility-curated corpus); `mint()` deprecated
- `lib/features/verify/verify_screen.dart` — "VIDEO CALL //" toggle,
  "WATCH FOR //" expected-action row, "ACTION //" judgment panel,
  combined ✅/❌ banner logic in `_VerifyResult`
- `test/crypto/totp_words_liveness_test.dart` — 24 tests incl.
  fixture vectors, role asymmetry, ±1 window tolerance
- `test/features/verify_screen_test.dart` — "VerifyScreen video
  mode" group: toggle UI, deep-link `?video=1`, ✅✅/✅❌/❌_
  outcomes, mid-attempt invalidation, haptic timing
- `.devloop/spikes/secret-derived-liveness.md` — design history
  (Option A/B/C comparison; C chosen)

### 2.4 Voice-channel dictionary attacker A₄ — OOB pairing interception

**Capabilities:** for long-distance pairing (transport package), can
observe the ciphertext delivered on the chosen channel. May be a
state-level adversary with substantial offline compute.

**What Signet proves:** the transport package is AES-256-GCM
encrypted with a key derived via HKDF-SHA-256 of an 8-word BIP-39
PAKE secret (88 bits of entropy). Offline dictionary attack at 10¹²
attempts/sec requires ~9.8 million years. The PAKE secret is
communicated on a *different* trusted channel, not spoken over a
fresh voice call (the exact channel A₁ owns).

**Explicit rationale for not using a full PAKE** (OPAQUE / CPace /
SPAKE2+): no mature Dart implementation exists as of 2026-04; FFI to
C PAKE libraries is a multi-week integration with its own audit
surface. 8-word symmetric unlock achieves state-level-resistant
margin with ~200 LOC. See `.devloop/spikes/transport-package.md`
"Option comparison" table.

**Relevant code:**
- `lib/core/crypto/transport_package.dart` — AEAD + HKDF + wire format
- `test/crypto/transport_package_test.dart` — 21 tests incl. domain
  separation, wrong-PAKE rejection, bit-flip rejection

### 2.5 Paper-leak attacker A₅

**Capabilities:** finds the user's printed challenge-response grid
card (8×8 table of 3-word answers).

**What Signet proves:** A₅ can pass challenge-response queries
correctly for the affected pair. They cannot produce the rotating
4-word verification code (the rotating code is derived from the
shared secret; the paper only reveals one specific HKDF projection).

**Downgrade severity:** acknowledged. The card is a fallback mode;
primary verification (rotating code) is still intact. User copy on
the printed card reads "Treat this card like a safe combination"
and instructs an unpair + re-pair in person if the card is lost.

**Relevant code:**
- `lib/core/crypto/challenge_response_grid.dart`
- `lib/features/inspect/cr_grid_pdf.dart` — paper card with warning
- `.devloop/spikes/challenge-response.md` — design decision log

### 2.6 Same-channel eavesdropper A₆ — lost-phone backup recovery

**Capabilities:** intercepts BOTH the LPR transport package AND the
8-word PAKE secret during a lost-phone recovery operation.

**What Signet proves:** nothing in this case. If the adversary has
both artifacts, they can rehydrate the relationship on their own
device. The user's responsibility is to transport the two artifacts
on *different* physical paths — paper vs. memorized password, two
separate safety deposit boxes, a prior in-person exchange, etc. See
`BackupExportScreen` UI copy and `docs/RELEASE.md`.

### 2.7 Physical-device compromise A₇

**Capabilities:** has the user's unlocked paired device in-hand.

**What Signet proves:** nothing beyond what the OS provides. A₇ can
open Signet, tap the paired contact, observe the current rotating
code, and impersonate the user to the other party for as long as
the device is in hand. Android's StrongBox and iOS's Keychain
protect the secret at rest (so an offline forensic extraction of a
locked device cannot recover the shared secret without also cracking
the device unlock), but do not prevent misuse by a person holding
the unlocked device.

**Platform trust:** see Section 4.

### 2.8 Shoulder-surfing A₈

**Capabilities:** visually observes the rotating 4-word code being
produced on the paired device's screen from behind.

**What Signet does not defend against:** observation in the
±1-window grace period gives the attacker ~1 minute to use those
four words. FLAG_SECURE (Android) / blur-overlay (iOS) blocks
screenshots + screen recording + the app-switcher thumbnail, but
not in-person observation. Acknowledged limitation.

### 2.9 Coercion A₉ — duress code scenario

**Capabilities:** physically coerces the paired user to produce a
valid verification code under threat.

**What Signet does not defend against (v0.2):** nothing. Produced
codes are valid regardless of the emitting user's consent state.

**Deferred feature:** a duress-code mode that emits a second-secret
word set which verifies normally on the challenger's side but
silently flags the verification log. Gated on an abuse-analysis
spike — duress features carry real misuse potential (fabricated
coercion claims) and aren't ship-safe without that analysis.

## 3. Protocol-level defenses

### 3.1 In-person QR pairing

- Each side mints an ephemeral X25519 key pair (`PairingHandshake.generateEphemeralKeyPair`).
- QR payload: `signet:p1:<base64url(32-byte pubkey)>`. Version-prefixed
  so future pair formats can coexist.
- Both sides scan, derive shared secret via X25519 ECDH
  (`PairingHandshake.deriveSharedSecret`), derive a pair-time phrase
  via HKDF (`PairingVerification.derivePhrase`), and display the
  phrase to both users for **visual cross-confirmation over a
  channel they already trust** (each other's faces).
- On match, both commit the relationship + shared secret atomically
  to secure storage; on mismatch, both abort.

**MITM consideration:** a physical MITM who sits between two phones
at pair time could substitute their own pubkey for each side. The
pair-time phrase detects this: both sides would derive different
phrases. This requires the users to actually *read the phrases to
each other* — the UI nudges this but does not enforce it (enforcement
is a copy / social-layer concern).

### 3.2 Role-asymmetric rotating verify code

- Role `{a, b}` derived at pair commit from byte-lex of the two pubkeys.
- HKDF info = `signet/v1/totp-words-from-<role>`.
- Each window's 4 words are different per role; a reflection attempt
  fails by construction.

### 3.3 Transport package (long-distance pairing + lost-phone recovery)

- Wire format: `signet:tp1:<base64url(body)>`.
- `body = version | payload-type | timestamp | nonce | AEAD-ciphertext | AEAD-tag`.
- AEAD = AES-256-GCM; key = HKDF-SHA-256 of the 8-word PAKE secret
  (UTF-8-joined), info-string domain-separated per payload type
  (`signet/v1/tp1/ldp` vs `signet/v1/tp1/lpr`).
- Payload types: LDP (ephemeral pubkey + label hint — long-distance
  pairing) or LPR (shared secret + full relationship metadata —
  lost-phone recovery).

### 3.4 Storage

- Android: Keystore-wrapped AES key + AES-GCM storage cipher.
  StrongBox requested; falls back to TEE-backed Keystore on devices
  without StrongBox. No Keystore biometrics in v0.2 (grandma-test
  constraint; see `lib/core/storage/secure_store.dart` docstring).
- iOS: Keychain generic password items with
  `kSecAttrAccessibleAfterFirstUnlock`. See
  `docs/IOS_STORAGE_AUDIT.md` for what's verifiable and what isn't.
- No `INTERNET` permission on Android. No network-dependent APIs
  invoked anywhere in the code path.

### 3.5 Screen-capture blocking

- Android: `WindowManager.LayoutParams.FLAG_SECURE` on all sensitive
  screens (Verify — incl. video-mode expected-action, Show-my-words,
  pair QR-show, binding-phrase re-check, backup export, CR grid).
- iOS: blurred `UIVisualEffectView` swapped in on
  `applicationWillResignActive`, removed on
  `applicationDidBecomeActive`. Does not block active AirPlay /
  HDMI mirror sessions (acknowledged limit; iOS offers no user-space
  override).

## 4. Platform trust assumptions

Signet's security properties assume the following from the OS:

- **Android Keystore** correctly enforces the `RSA/OAEP` key-wrap +
  `AES-GCM` storage cipher; the master key is confined to the secure
  processor (TEE or StrongBox); `run-as`-style access by another
  app on the same device does not reveal plaintext values. Verified
  sentinel scan against Android 14 emulator in Phase 3.4 (see
  `.devloop/archive/plan-2026-04-16-v0.1.md`).
- **iOS Keychain daemon** correctly enforces
  `kSecAttrAccessibleAfterFirstUnlock` — values are not retrievable
  by app-sandbox filesystem scan while the device is locked; app
  uninstall removes the items. Unable to directly verify the
  Keychain database's format without jailbreak (documented in
  `docs/IOS_STORAGE_AUDIT.md`).
- **Android `FLAG_SECURE`** correctly blocks screenshots, screen
  recording, the app-switcher thumbnail, and most remote-access
  trojans that screenshot via accessibility APIs. Does NOT block
  root-level screenshot tools or a physical camera pointed at the
  device.
- **Device-level biometric unlock and screen lock** are assumed
  correctly implemented. Once the device is unlocked and in the
  holder's hands, Signet extends no additional user-presence checks
  (grandma-test constraint: re-auth per verify would be too high
  friction).
- **BIP-39 English wordlist** — phonetic distinctness is an
  assumed property of the list itself. Signet uses the standard
  2048-word list as published by BIP-0039 and embedded in-tree
  (`lib/core/crypto/bip39_english_wordlist.dart`); the list is not
  modified.
- **Dart `cryptography` package** (pinned; audited via pub.dev
  reputation) correctly implements HKDF-SHA-256, HMAC-SHA-256,
  AES-256-GCM, and X25519 ECDH. Primary crypto primitives are
  validated against RFC vectors — see `docs/TEST_VECTORS.md`.

## 5. Out-of-scope threats

The following are explicitly not defended against, and should not be
interpreted as bugs:

| Threat | Rationale |
|--------|-----------|
| Compromised / rooted / jailbroken host | Trust is transitive to the OS. |
| Physical capture of unlocked paired device | Section 2.7. |
| Shoulder-surfing / in-person screen observation | Section 2.8. |
| Coercion of the legitimate user | Section 2.9; duress mode deferred. |
| Pairing to a malicious counterparty at pair time | If the user paired with the attacker to start, Signet has no way to know. User-responsibility. |
| Same-channel compromise of BOTH transport package AND PAKE secret | Section 2.6; user's job to split channels. |
| Platform-level backups / migrations that exfiltrate the secret | Current iOS config allows iCloud backup inclusion; see `docs/IOS_STORAGE_AUDIT.md` open questions. v1.0 may tighten to `*ThisDeviceOnly`. |
| Quantum-capable adversary (CRQC) | X25519 is not PQ-resistant. Symmetric primitives are. Forward investigation at `.devloop/backlog.md`. |
| Supply-chain compromise of Dart/Flutter/plugin packages | Rely on pub.dev's integrity + explicit version pinning in `pubspec.yaml`. Not additionally hardened. |
| Reproducible-build drift | v0.2 does not yet produce bit-identical APKs across machines; lands in Phase 12.15. |

## 6. Non-security properties (out of scope for audit)

These exist for completeness — an auditor should understand they are
not security claims:

- **Grandma-test usability** — single-tap flows, 64dp buttons, BIP-39
  audio-resilient words. Usability is a product constraint, not a
  security property; failing the grandma test hurts adoption, not
  confidentiality.
- **Zero-telemetry posture** — we send no analytics, no crash
  reports, no phone-home of any kind. Not a cryptographic claim —
  just a product-stance claim. Audit can verify by inspecting
  `AndroidManifest.xml` for the absence of `INTERNET`, and by
  source-auditing that no code path invokes `http`, `dart:html`,
  `package:http`, or similar.
- **No server-side component** — there is nothing to subpoena, log,
  or compromise on our side. By design.

## 7. Test vectors + reproducibility

- RFC 6238 / RFC 7748 / RFC 5869 / BIP-39 test vectors are validated
  by the regular test suite (`flutter test`). Full machine-readable
  listing in `docs/TEST_VECTORS.md`.
- Crypto-module unit tests are pure-Dart and run on any platform.
- A third party can rebuild the APK byte-for-byte via the script in
  Phase 12.15 (`docs/REPRODUCIBLE_BUILD.md`).

## 8. What a Signet security audit should verify

Suggested scope for an external audit (Cure53-class firm or similar):

1. **Wire-format parsers** — `PairingCodec`, `TransportPackage` wire
   decoders. Malformed / oversized / bit-flipped inputs must
   produce clean exceptions, never silent corruption.
2. **HKDF info-string separation** — every in-tree `info` string is
   unique and differs in ways the attacker can't induce.
3. **Constant-time compares** — `TotpWords.verify` uses a
   constant-time XOR over word indexes. Audit whether this is
   actually constant-time at the VM level, and audit for any other
   path where early-exit comparisons could leak timing.
4. **Role-assignment correctness** — `PairRole.assign` must produce
   consistent `{a, b}` assignment across both devices from the same
   pubkey pair, and must not depend on which device initiated the
   pair flow. Tests exist but audit the edge cases.
5. **Transport-package AEAD** — 8-word PAKE → HKDF → AES-256-GCM.
   Verify the salt wiring (we use the 12-byte nonce as the HKDF
   salt), verify no nonce reuse across distinct encryptions, verify
   padding / size / replay properties.
6. **Storage** — confirm no plaintext shared-secret path exists. The
   Phase 3.4 sentinel scan is Android-only; audit should exercise
   iOS similarly with the sentinel harness.
7. **Backup / recovery semantics** — verify that an LPR restore on a
   new device is indistinguishable to the peer from the original
   pairing; that the old device's relationship is unaffected; that
   import is idempotent.
8. **Platform-channel boundaries** — the Android Kotlin + iOS Swift
   side of the `dev.digitalgrease.signet/window` method channel. Verify that
   malformed method calls don't crash the activity / app delegate,
   and that the blur-overlay / FLAG_SECURE state can't get stuck
   on after `secureOff`.

## 9. Document freshness

This document is maintained alongside the code. Any phase that adds
or changes a cryptographic primitive, a platform-trust assumption, or
a wire format must update this doc in the same commit range.

Changelog summary (most recent first):

- 2026-04-22 · Phase 14 — A₃ reframed from "pre-recorded video puppet"
  to "AI-capable, secret-less video attacker." Liveness flow is now
  secret-derived via `TotpWords.deriveLivenessAction` (HKDF info
  `signet/v2/liveness-action-from-{role}`), folded into the verify
  screen's video-mode toggle. Combined pass probability for a
  secret-less realtime deepfake dropped from ~100% → 1/2⁴⁷ per 30s
  window. Standalone liveness screen retired; `/liveness/:id` redirects
  to `/verify/:id?video=1` for one release. See
  `.devloop/spikes/secret-derived-liveness.md`.
- 2026-04-19 · initial consolidation (Phase 12.12).
