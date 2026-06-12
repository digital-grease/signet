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

### 2.10 Forensic crash-log + debug-log adversary A₁₀

**Capabilities:** post-incident read access to Signet's on-device
log files — the crash sentinel (`<app-support-dir>/crashes/last.bin`)
and, when present, the opt-in debug session
(`<app-support-dir>/debug/session.bin`). Three realistic shapes:

- **Forensic / law-enforcement extraction** with root + unlocked
  device (FDE has already been bypassed via the screen lock).
  Reads the files; needs to recover plaintext to identify the
  user's paired contacts, recently-displayed verify codes, or
  pasted backup payloads.
- **A second app on the device** with elevated privileges (rooted
  device, OEM-level access) trying to scan Signet's private files.
  Same shape of read; same recovery goal.
- **A device seized while debug logging happens to be active.** The
  debug session file exists *only* while the user has opt-in logging
  turned on (off by default; 24h auto-expiry), so for almost all
  users at almost all times there is nothing to seize.

**Defending property:** neither file contains a paired secret, pair
label, verify code, or transport-package body in plaintext, even
after a forensic extraction. The crash sentinel is enforced by the
four-layer pipeline in §3.6; the debug session is structured
by construction (only enumerated events + opaque relationship ids,
never a label or secret reach it) and encrypted at rest — see §3.7.

**Residual risk:** sustained access to BOTH an on-disk file
AND the Android Keystore / iOS Keychain. The at-rest encryption
key lives in the Keystore; recovering it requires either an
exploitable Keystore weakness or device-side persistence that's
already past the storage trust boundary in §4. This is the same
adversary capability that recovers the paired shared secret —
i.e., a forensic-level compromise of the OS itself.

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
  invoked anywhere in the code path. The in-app "File a GitHub
  Issue" button (§3.6) hands off to the OS browser via
  `url_launcher` — out-of-process navigation by user-explicit
  action, not an in-app network call.

### 3.5 Screen-capture blocking

- Android: `WindowManager.LayoutParams.FLAG_SECURE` on all sensitive
  screens (Verify — incl. video-mode expected-action, Show-my-words,
  pair QR-show, binding-phrase re-check, backup export, CR grid).
- iOS: blurred `UIVisualEffectView` swapped in on
  `applicationWillResignActive`, removed on
  `applicationDidBecomeActive`. Does not block active AirPlay /
  HDMI mirror sessions (acknowledged limit; iOS offers no user-space
  override).

### 3.6 Crash-log shipping (in-app issue reporter)

Signet runs an in-app crash detector that, on next launch after an
uncaught exception, surfaces a dialog offering to file a GitHub
Issue against the pre-filled `crash_report.yml` form. This is
useful — without stack traces from field crashes, alpha-user bug
reports are essentially unactionable — but it introduces a leak
surface: arbitrary uncaught material flowing into a string that
the user might agree to send. The full design rationale lives in
`.devloop/spikes/log-shipping.md`; this section summarises the
properties the runtime guarantees.

**Four-layer defense.** Each layer compensates for a failure of
the previous one. No single regression breaks the leak-prevention
guarantee.

| Layer | Mechanism | What it catches | What it misses |
|---|---|---|---|
| 1. Code-side discipline | Sensitive types never embed their secret payload in `toString` / error messages. Enforced by `test/logging/leak_prevention_test.dart` (`Relationship`, `LivenessPrompt`, `PairingKeyPair`, `BackupBundle`, `LdpPackage`/`LprPackage`/`BlkPackage`, `ChallengeResponseGrid`, etc.). | Material that never enters a string in the first place. | Bugs / regressions; newly-added sensitive types added without the discipline. |
| 2. Pre-write scrubber | `lib/core/logging/log_scrubber.dart` — deny-by-default with allow-list. Mechanical patterns (hex≥16, base64url≥16, `signet:tp1:` wire, BIP-39 4-tuple and 8-tuple clusters) have a 100% pass-or-fail-CI bar. Judgment patterns (pair labels in toString dumps, user-input string literals) have ≥95% bar. | Anything that slipped past layer 1 in a regex-detectable shape. | Context-dependent edge cases (≤5% on the curated corpus). |
| 3. AES-GCM at rest | `lib/core/logging/crashlog_cipher.dart` — AES-256-GCM with 12-byte nonce + 16-byte tag. Key under `crashlog.aead_key.v1` in `flutter_secure_storage` (Android Keystore / iOS Keychain). Lazy-generated on first crash. | The ~5% the judgment scrubber misses, while the file sits on disk. | In-process attackers running with our keys; nothing post-decryption. |
| 4. OS sandbox + FDE | Android app-private storage; iOS sandbox; full-disk encryption when the device is locked. | Other apps reading our private storage; lost-device-pre-unlock. | Forensic-level adversary with root + screen-lock bypass (§4 limit). |

**Test bars (`.devloop/spikes/log-shipping.md`, "Pass thresholds"
table):**

- **Mechanical redacts: 100%, build-failing.** Any single miss on
  hex≥16, base64url≥16, `signet:tp1:` wire, or BIP-39 4/8-tuple
  clusters fails CI. Adding a new transport-package version or
  secret-pattern shape requires matching scrubber-test entries in
  the same commit.
- **Judgment redacts: ≥95%** on a 20-label curated corpus. Slip
  rate is hedged by layer 3.
- **Framework allow-pass: ≥95%** so legit stack frames stay
  readable. False redactions are UX papercuts, not security
  regressions.
- **Real-trace shape preserved: 100%.** A scrubbed trace must
  remain identifiable as a stack trace; otherwise the feature
  defeats its own purpose.

**Crash-storm protection.** `CrashRecorder` enforces a 24h
cooldown via the in-blob `recordedAt` timestamp — a second crash
within 24h leaves the existing sentinel in place. Prevents an
every-launch crash-loop from re-firing the dialog (which the user
would dismiss-fatigue past).

**Zero-network claim preserved.** Signet does not initiate the
GitHub upload. The "File issue" button hands off to
`url_launcher` → OS browser → user-explicit-action navigates to
github.com. From Signet's process perspective, the only
out-of-process call is to the OS browser — exactly what a user
would do manually if they typed the URL themselves. The Android
manifest does **NOT** declare the `INTERNET` permission (§3.4),
and `flutter analyze` + the CodeQL workflow would flag any
in-process network call added in future versions.

**Sentinel file location and lifecycle.** Written by
`CrashRecorder.record()` to
`<getApplicationSupportDirectory()>/crashes/last.bin`.
Read once by `CrashDetector.readPendingReport()` on next launch;
explicitly deleted via `dismissPendingReport()` after the dialog
action (file/copy/dismiss). A corrupt or non-decryptable sentinel
is silently cleaned up so a poisoned file doesn't loop.

**Worst-case scenarios:**

- *Scrubber misses a hex pattern.* Layer 3 encrypts the blob;
  recovery needs both the scrubber miss AND Keystore extraction.
- *AES-GCM cipher implementation regresses to plaintext output.*
  Layer 2 ensures the plaintext is already scrubbed; recovery
  needs both the cipher regression AND a scrubber-miss.
- *Both layer 2 and layer 3 fail.* Layer 4 (OS sandbox) blocks
  same-device other-app reads; FDE blocks lost-device-pre-unlock.
  Forensic recovery requires §4-level OS compromise.

### 3.7 Debug-log shipping (opt-in diagnostic logging)

For non-crash bugs — a verify that returns the wrong result, a
pairing that hangs without throwing — Signet offers **opt-in** debug
logging. Off by default: a user who never enables it keeps a zero
on-disk behavioral-log footprint. Design rationale lives in
`.devloop/spikes/debug-log-export.md`; this section summarises the
runtime guarantees.

**Retention is opt-in and bounded.** Logging records only while the
user turns it on in Settings. The session is held encrypted at
`<getApplicationSupportDirectory()>/debug/session.bin` (AES-256-GCM,
key `debuglog.aead_key.v1` — distinct from the crash key so resetting
one never wipes the other), auto-stops and erases after 24h, and is
byte-capped at 2 MB (oldest-first prune). A persistent on-screen
banner means it is never silently on. An always-on in-memory
breadcrumb ring (never persisted on its own) is folded into a crash
report if one fires.

**Write-time discipline, not write-time scrubbing.** Unlike the crash
path (whose trace is arbitrary, so it is scrubbed before write), the
session log is structured by construction: the logging API accepts an
enumerated `BreadcrumbEvent` plus a relationship's **opaque id**, with
no path that accepts a label or a free-form string. No secret or
contact name enters the file in the first place, so the at-rest file
is relationship-id-pseudonymous. Running `LogScrubber` at write time
would shred those ids (they are 32-hex) and is therefore deliberately
omitted; the public-facing scrub runs at export.

**Export scrubber (the public-facing leak surface).** Debug logs go
to a public GitHub issue, the OS share sheet, or the clipboard, so
before anything leaves the device `DebugLogExportScrubber`
(`lib/core/logging/debug_log_export_scrubber.dart`) runs a four-step
pipeline whose order is load-bearing:

| Step | Action | Why this position |
|---|---|---|
| 1. map ids | each 32-hex `Relationship.id` → stable `<peer-N>` | before the secret scrub, else the hex id is redacted and `<peer-N>` correlation is lost |
| 2. secret scrub | `LogScrubber.scrub` (the §3.6 layer-2 module) | before the label sweep, else a label substitution fragments a secret below threshold |
| 3. label sweep | each known label → its same `<peer-N>` | on already-secret-free text, so a BIP-39-word / `tp1`-ish / base64-substring label cannot break secret detection |
| 4. PII sweep | email + phone | defense in depth |

A relationship's id and label collapse to one stable `<peer-N>`
token, so a maintainer can follow one contact through the log without
learning who it is. The label matcher uses escaped-literal matching
(labels are free text and routinely contain regex metacharacters),
word-boundary guards (`Mom's` redacts but `MomCare` does not),
whitespace-flex, and NFC + case-insensitive matching. `LabelPolicy`
rejects, at contact creation, any label that is itself
`signet:tp1:`-shaped or pure ≥16-hex, keeping every label on the
pseudonymization path.

**Residual.** A colloquial / partial / accent-stripped contact name
the user hand-types (e.g. `Jose` for a `José` contact) is not caught
by the exact-match backstop. Primary defense is the write-time
discipline (no label ever enters the log automatically); additionally
the export sheet warns the user not to type contact names into the
free-text issue description, which is a separate field that is **not**
scrubbed.

**Zero-network preserved.** As in §3.6, the "File a GitHub issue"
path hands off to the OS browser via `url_launcher`; no in-process
network call, no `INTERNET` permission.

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
9. **Crash-log shipping pipeline (§3.6).** Audit the four-layer
   defense:
   - `LogScrubber` deny-by-default against a custom adversarial
     corpus (not just the bundled tests). Mechanical patterns
     should be exhaustive on hex / base64url / `signet:tp1:` /
     BIP-39 cluster shapes.
   - `CrashlogCipher` AES-256-GCM at-rest: nonce uniqueness across
     writes, auth-tag rejection on bit-flips, key lifecycle in
     `flutter_secure_storage` (re-install behaviour, key absence on
     a fresh install).
   - `CrashReportUrlBuilder` 7000-char budget, defensive 75% shrink
     on tight budgets, decoded form-field round-trip.
   - Confirm the `AndroidManifest.xml` still does NOT declare
     `INTERNET` after the log-shipping feature ships — the OS-browser
     handoff via `url_launcher` is the only network path, and it
     runs out-of-process.
10. **Debug-log shipping pipeline (§3.7).** Audit the opt-in
   `DebugSession` + `DebugLogExportScrubber`:
   - Export-scrubber order (id-map → secret-scrub → label-sweep →
     PII) against an adversarial corpus. A label that is a
     base64 / BIP-39 / `signet:tp1:` substring of a secret on the
     same line must not let the secret leak; every known label
     (incl. regex-metacharacter, possessive, whitespace-split, and
     Unicode forms) must collapse to its `<peer-N>` token.
   - `DebugSession` at-rest: the distinct `debuglog.aead_key.v1` key,
     24h auto-expiry, 2 MB oldest-first prune, no plaintext id/secret
     leak, and that the structured logging API admits no label or
     free-form path (the write-time discipline the at-rest model
     depends on).
   - Confirm `AndroidManifest.xml` still does NOT declare `INTERNET`.

## 9. Document freshness

This document is maintained alongside the code. Any phase that adds
or changes a cryptographic primitive, a platform-trust assumption, or
a wire format must update this doc in the same commit range.

Changelog summary (most recent first):

- 2026-06-12 · Phase 8 — opt-in debug logging added. A₁₀ extended to
  cover the debug `session.bin` artifact (present only while opt-in
  logging is active). New §3.7 covers the opt-in retention model, the
  write-time-discipline at-rest guarantee (structured events + opaque
  ids, no write-time `LogScrubber`), and the export scrubber's
  four-step pipeline (id-map → secret-scrub → label-sweep → PII) with
  `<peer-N>` pseudonymization. Audit scope item #10 added. See
  `.devloop/spikes/debug-log-export.md`.
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
