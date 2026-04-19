# Signet — known limitations

Consolidated "what Signet does not do" — every intentional gap in the
current implementation, every deferred-to-a-later-version item, every
"we chose not to address this" design call, in one document.

For the corresponding "what Signet *does* defend against" see
`docs/THREAT_MODEL.md`. For per-release status on roadmap items, see
`README.md` § Development roadmap.

Each limitation carries four fields:

- **Scope:** what it is in one line.
- **Why:** the reason it's not addressed.
- **User mitigation:** what the user should do / know to compensate.
- **Status:** in a future version / deferred / out of scope forever.

---

## Platform coverage

### L-PLAT-1 · iOS screenshot behavior is weaker than Android

- **Scope:** Android's `WindowManager.LayoutParams.FLAG_SECURE`
  blocks screenshots, screen recording, and the recent-apps thumbnail
  at the OS level. iOS has no equivalent flag. Signet's iOS fallback
  is to swap in a blurred `UIVisualEffectView` on
  `applicationWillResignActive` (see `ios/Runner/AppDelegate.swift`).
- **Why:** iOS deliberately does not expose a system-wide screen-
  capture block to user-space apps; this is a platform policy, not
  a Signet oversight.
- **User mitigation:** the blur-overlay covers app-switcher
  snapshots and most screen-recording paths on recent iOS. It does
  not cover an active AirPlay / HDMI mirror session. On iOS,
  verify-screen-visible calls should not be made on casted or
  mirrored displays.
- **Status:** accepted limitation of the iOS platform. See
  `docs/IOS_STORAGE_AUDIT.md` and `docs/IOS_VALIDATION.md`.

### L-PLAT-2 · iOS Keychain database is not auditable without jailbreak

- **Scope:** the Android storage-hygiene audit (Phase 3.4) directly
  inspected the app-sandbox filesystem with `adb run-as`. iOS does
  not expose equivalent filesystem access to its Keychain items
  (`keychain-2.db`); only Apple's `securityd` daemon reads it, and
  only user-space Keychain APIs query it.
- **Why:** Apple platform policy.
- **User mitigation:** we compensate by (a) exercising the sentinel
  harness on iOS (round-trip + sandbox-filesystem grep), and (b)
  documenting what's unverifiable (see `docs/IOS_STORAGE_AUDIT.md`).
  This is equivalent to the trust model every other iOS app operates
  under.
- **Status:** accepted.

### L-PLAT-3 · StrongBox is best-effort

- **Scope:** Android API 28+ devices may advertise StrongBox but some
  OEMs (especially budget devices) disable it. Signet requests
  StrongBox and silently falls back to TEE-backed Keystore. No
  StrongBox-presence attestation or user notification.
- **Why:** no user-friendly way to expose the distinction without
  intimidating the grandma-test demographic.
- **User mitigation:** none at the user level. An advanced user can
  check via `adb shell dumpsys keystore` on their own device.
- **Status:** StrongBox attestation deferred to v1.0. See
  `docs/THREAT_MODEL.md` § 4.

### L-PLAT-4 · iOS Keychain items are included in iCloud Keychain by default

- **Scope:** `flutter_secure_storage` on iOS defaults to
  `kSecAttrAccessibleAfterFirstUnlock`, not
  `...ThisDeviceOnly`. Secrets therefore sync to iCloud Keychain and
  are included in iTunes encrypted backups unless the user has
  disabled those features globally.
- **Why:** the `*ThisDeviceOnly` variant blocks Apple's automatic
  device-to-device migration; the v0.2 trade-off was to accept the
  backup inclusion in exchange for migration-friendliness. The
  backup path is end-to-end encrypted between Apple devices, which
  is better than plaintext but still transits Apple infrastructure.
- **User mitigation:** users who care can disable iCloud Keychain
  at the OS level. Or use Signet's native `BackupBundle`
  export/import (Phase 11.8/11.9) which is the canonical offline path.
- **Status:** open question for v1.0. See
  `docs/IOS_STORAGE_AUDIT.md` § "Open questions."

## Social-layer / user-behavior

### L-SOC-1 · Paired with the wrong person

- **Scope:** if the user completes in-person pairing with an
  attacker (pretending to be a family member, for example), Signet
  has no way to detect it. Both devices will see matching pair-time
  phrases because they're both deriving from the same shared
  secret — which is what both attackers and legitimate peers produce.
- **Why:** identity at pair time is established by the users'
  real-world recognition of each other's faces / voices /
  biographical facts. Signet is not an identity-verification system
  for that moment; it's a retention mechanism for the trust decision
  the users make at that moment.
- **User mitigation:** do initial pairing with someone you can
  visually identify as the real person.
- **Status:** out of scope forever.

### L-SOC-2 · Shoulder-surfing

- **Scope:** an attacker standing behind the user can visually read
  the rotating 4-word code or the pair-time phrase during a
  verification.
- **Why:** no cryptographic defense against visual observation of
  screen content.
- **User mitigation:** screen-privacy film, physical posture, don't
  verify in public.
- **Status:** out of scope forever. Documented at
  `docs/THREAT_MODEL.md` § 2.8.

### L-SOC-3 · Coercion / duress

- **Scope:** the paired user, under physical coercion, can produce
  a verification code that a coerced-verifier has no way to
  distinguish from a legitimate one.
- **Why:** duress-aware codes (dual-secret: one normal, one that
  verifies ✅ to the verifier but flags the log silently) are
  implementable. Not shipped in v0.2 because misuse analysis isn't
  complete — duress features can be used to fabricate false
  coercion claims, which has real harm potential.
- **User mitigation:** none at v0.2.
- **Status:** gated on abuse-analysis spike. v1.0 candidate if
  cleared. See `docs/THREAT_MODEL.md` § 2.9.

### L-SOC-4 · Paper-card leak for challenge-response

- **Scope:** Phase 11's printable challenge-response grid is a secret
  artifact. Anyone who finds it can pass challenge-response queries
  for that pair.
- **Why:** the grid derives from the shared secret via HKDF; if the
  grid is visible, its entries are fully known. Challenge-response
  is a fallback *mode*, not a separate secret.
- **User mitigation:** treat the card like a safe combination
  (stated explicitly on the printed card). If lost, unpair and
  re-pair in person. The rotating-word verify still defends primary
  calls even if the card is compromised.
- **Status:** documented downgrade. See
  `.devloop/spikes/challenge-response.md`.

### L-SOC-5 · Same-channel compromise for long-distance pair / recovery

- **Scope:** the transport package (LDP + LPR) requires the user to
  ship the encrypted package and the 8-word PAKE secret via two
  *different* channels. A user who sends both over the same channel
  gives an eavesdropper both artifacts.
- **Why:** the security of the unlock depends on the channels'
  independence. We can't enforce that from inside the app.
- **User mitigation:** UI copy explicitly instructs "send the 8
  words on a DIFFERENT channel than the package. Never over an
  unverified voice call." User decides.
- **Status:** documented in-copy. Out of scope to enforce.

## Device-physical

### L-DEV-1 · Physical capture of an unlocked device

- **Scope:** an attacker holding the user's unlocked paired device
  can verify on behalf of the user; view the rotating code; unpair;
  re-pair; do anything the legitimate user could.
- **Why:** once past the device's lock screen, Signet extends no
  additional user-presence or re-auth checks. Re-auth per verify
  would hurt the grandma-test UX unacceptably.
- **User mitigation:** device-level screen lock + biometrics is the
  defense. Signet is a *retention* mechanism, not a *presence*
  mechanism.
- **Status:** accepted. Biometric-gated per-verify re-auth is a
  v1.0 candidate for journalist-mode but not for default.

### L-DEV-2 · Clock drift beyond ±1 window

- **Scope:** the rotating 4-word code verifies over a ±1 window
  (±30s) tolerance. Devices with system clocks off by more than 30
  seconds will fail to verify against each other.
- **Why:** larger tolerance windows expand the attack surface for
  replayed codes; smaller windows break real-world users with
  mildly-skewed clocks. The ±1 window is the industry-standard
  trade-off (RFC 6238 recommends).
- **User mitigation:** enable network-time sync at the OS level
  (usually on by default). Signet has no clock-sync feature of its
  own because that would require a network call (out of posture).
- **Status:** accepted. See `test/crypto/totp_words_test.dart` for
  boundary tests.

## Cryptographic + protocol

### L-CRYPTO-1 · Quantum-capable adversary

- **Scope:** Signet's X25519 handshake is vulnerable to Shor's
  algorithm on a sufficiently large quantum computer (CRQC).
  Recorded pair-time traffic today could, in principle, be
  decrypted by a CRQC in the future.
- **Why:** no shippable post-quantum Dart implementations for
  Curve25519's PQ replacements (ML-KEM etc.) at time of writing.
  Also: Signet's X25519 is usually exchanged in-person via QR, not
  over a network an adversary could record at scale.
- **User mitigation:** none at user level. Symmetric primitives
  (HMAC, HKDF, AES-256-GCM) are PQ-resistant already, so the
  rotating-word verify's per-window secret flow is safe.
- **Status:** forward-investigation item. See
  `.devloop/backlog.md` § "Post-quantum cryptography — ROI
  investigation."

### L-CRYPTO-2 · No full PAKE for the transport package

- **Scope:** long-distance pairing's PAKE uses AEAD-on-HKDF with an
  8-word BIP-39 secret (88 bits). A full PAKE (OPAQUE, CPace,
  SPAKE2+) would resist offline dictionary attack at lower bit
  counts.
- **Why:** no mature Dart PAKE implementation; FFI to a C PAKE is
  multi-week + its own audit surface.
- **User mitigation:** 8 words buys ~9.8M years at 10¹²
  attempts/sec. Feasibly secure for every current adversary class
  including state-level. See `.devloop/spikes/transport-package.md`
  § "Option comparison."
- **Status:** wire version `signet:tp1:` is Option B (HKDF + 8
  words); a future `signet:tp2:` could be Option C (Argon2id + 6
  words) or full PAKE. Clean upgrade path.

### L-CRYPTO-3 · No AES-256-GCM KAT vectors in-tree

- **Scope:** the transport package depends on AES-256-GCM via the
  `cryptography` package. Our integration tests exercise round-trip
  + tag-check behavior, but no NIST SP 800-38D Known-Answer Test
  vectors are carried explicitly.
- **Why:** we rely on the upstream package's test coverage.
- **User mitigation:** n/a.
- **Status:** audit prompt — carrying a small number of KAT
  vectors would raise confidence. See `docs/TEST_VECTORS.md` §
  AES-256-GCM.

## Feature scope

### L-FEAT-1 · No camera-integrated liveness detection

- **Scope:** Signet's liveness prompt is *prompt-only* — the app
  generates a challenge ("touch your left ear and say 'orbit'"),
  the verifier watches for the response. No ML auto-detection.
- **Why:** auto-detection is a multi-month research project with
  real false-positive / false-negative risk.
- **User mitigation:** the verifier's eyes are the judge.
- **Status:** deferred to v0.3+ as a separate feature. Documented
  in `README.md` § Development roadmap.

### L-FEAT-2 · No multi-device pairing for the same human

- **Scope:** Alice has a phone and a tablet. She wants both to
  produce valid verification codes for her counterparty. Today she
  must pair each device separately (two pairings, two different
  relationships on the counterparty's side). Or use backup-import
  to clone the relationship from phone to tablet (treats them as
  the same device, which is functionally fine but not semantic).
- **Why:** multi-device-per-person requires a group-key-agreement
  protocol; out of scope for v0.2.
- **User mitigation:** use backup-import (Phase 11.9) to clone.
  Documented use case.
- **Status:** v1.0 candidate alongside MLS-based small-org features.

### L-FEAT-3 · No secret rotation on a schedule

- **Scope:** the shared secret is stable for the lifetime of the
  pairing. There is no forward secrecy; an adversary who obtains
  the secret can verify with it indefinitely.
- **Why:** forward secrecy requires continuous key rotation
  protocols (like Signal's Double Ratchet) which are designed for
  messaging channels, not identity-anchor primitives. Signet's
  rekey flow (Phase 10.6) requires both devices present; automatic
  rotation is not in scope.
- **User mitigation:** manually rekey via the per-peer long-press
  menu if a compromise is suspected.
- **Status:** manual rekey ships; automatic rotation is a v1.0
  research question.

### L-FEAT-4 · No cloud backup

- **Scope:** Signet does not and will not support cloud-based
  backup of paired relationships.
- **Why:** zero-server posture. A cloud backup, even end-to-end
  encrypted, is a subpoena target and a retention-policy target.
  Inconsistent with the project stance.
- **User mitigation:** use `BackupBundle` export (Phase 11.8) to
  local file + PAKE words, stored offline.
- **Status:** out of scope forever.

### L-FEAT-5 · No account recovery

- **Scope:** there is no Signet account. There is no recovery
  email, no recovery phone number, no "forgot my password"
  pathway.
- **Why:** see L-FEAT-4 and the zero-server posture.
- **User mitigation:** `BackupBundle` (export + PAKE) is the only
  recovery path. If a user loses their device without a backup,
  they must re-pair in person.
- **Status:** out of scope forever.

## Build + distribution

### L-BUILD-1 · Non-reproducible builds

- **Scope:** two builds of the same commit on two different
  machines will not produce byte-identical APKs in v0.2.
- **Why:** Gradle embeds build timestamps; NDK paths are baked in.
  Fixable but not fixed in v0.2.
- **User mitigation:** none; this is a build-verification concern,
  not a runtime concern.
- **Status:** deferred to v0.2.1 / v1.0. See Phase 12.15 in the
  current plan for the fix.

### L-BUILD-2 · Debug-signed release fallback

- **Scope:** without `android/key.properties`, `flutter build apk
  --release` falls back to the Android debug key.
- **Why:** so `flutter run --release` works locally without
  forcing every developer to create a production keystore.
- **User mitigation:** do not distribute APKs from a machine that
  doesn't have `android/key.properties` populated. See
  `docs/CI.md` + future `docs/RELEASE.md`.
- **Status:** intentional; documented behavior.

### L-BUILD-3 · Scanner has no deep-link to system settings on permission-denied

- **Scope:** when the user permanently denies camera access, the
  pair-scan screen shows friendly copy with the path to the system
  settings. It does not auto-open that settings page.
- **Why:** open-settings APIs differ between Android versions and
  iOS, and require a permissions-plugin dep we've avoided.
- **User mitigation:** follow the displayed path manually.
- **Status:** accepted for v0.2.

### L-BUILD-4 · Placeholder app icons + launch screens

- **Scope:** iOS + Android icon asset sets still carry Flutter
  scaffold placeholders.
- **Why:** real icon design is a user-side design decision; the
  engineering scope of Phase 12 covered the regen tooling path
  (`flutter_launcher_icons`, `flutter_native_splash`), not the
  asset design itself.
- **User mitigation:** replace the placeholder before any app-
  store submission; see `docs/ICONS_AND_LAUNCH.md`.
- **Status:** release-gate item, not a security or functional
  limitation.

---

## Changelog

- 2026-04-19 · initial consolidation (Phase 12.14).
