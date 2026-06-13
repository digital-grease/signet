# Changelog

All notable changes to Signet will appear in this file. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) loosely;
versioning follows [Semantic Versioning](https://semver.org/) — pre-1.0
the surface is allowed to change between minor releases.

## [0.3.6] — 2026-06-12

Opt-in debug logging: capture and export a scrubbed activity log to
help us fix non-crash bugs, with your contacts' names replaced by
anonymous tags before anything leaves your phone.

### Added
- **Opt-in debug logging.** Off by default. Turn it on in
  Settings → Debug Logging, reproduce a bug, then Export to file a
  pre-filled GitHub Issue, share, or copy. Activity is recorded to an
  AES-256-GCM file (key in the Android Keystore / iOS Keychain),
  auto-erases after 24 hours or when you tap Stop, and a Home banner
  shows whenever it's on. The log never contains your secrets or your
  contacts' names — it's scrubbed on-device before export, with
  contacts replaced by anonymous tags like `<peer-1>` so a maintainer
  can follow one contact through a log without learning who it is.
  Design + threat model in `docs/THREAT_MODEL.md` §3.7 and
  `.devloop/spikes/debug-log-export.md`.
- Crash reports now carry a short breadcrumb trail of the lead-up
  events, scrubbed alongside the trace.

### Changed
- A contact name that looks like Signet data (a `signet:tp1:` package
  or a long hex string) is rejected at pairing time, so a label can
  never be mistaken for a secret.
- `PRIVACY.md` gains a "No automatic debug logging" clause;
  `docs/THREAT_MODEL.md` adds §3.7 and audit-scope item #10.

## [0.3.5] — 2026-05-25

About-screen version fix + privacy-policy clarification.

### Fixed
- About screen now shows the actual installed version, instead of a
  hardcoded `v0.2.0-alpha` string that never got bumped through
  several releases.

### Changed
- Privacy policy updated to accurately describe the in-app
  crash-report flow added in v0.3.4 — crash data still stays on your
  phone until you tap "Send".

## [0.3.4] — 2026-05-22

In-app crash reporter (one-tap file a pre-filled GitHub Issue with a
scrubbed stack trace) + in-person pairing deadlock fix.

### Added
- **In-app crash reporter.** If the app crashes during a session, the
  next launch surfaces a modal dialog offering to file a GitHub Issue
  pre-filled with device, OS, app version, and stack trace. Three
  actions: FILE ISSUE (opens the OS browser to a pre-filled
  `crash_report.yml` form), COPY LOG (clipboard only), DISMISS. The
  trace is scrubbed on-device before it leaves the phone:
  cryptographic material (paired shared secrets, the rotating 4-word
  verify code, transport-package wires `signet:tp1:...`, BIP-39 PAKE
  words, paired-contact labels) is replaced with `[redacted:N]`
  markers. AES-256-GCM at rest under a key in the Android Keystore /
  iOS Keychain. **Zero in-process network** — the "File issue" button
  hands off to the OS browser via `url_launcher`; the Android manifest
  still declares no `INTERNET` permission. The full four-layer defense
  is documented in `docs/THREAT_MODEL.md` §3.6.
- Structured GitHub Issue templates (bug / crash / feature / question /
  other) + content-aware autolabeler workflow on the repo.
- CI release-gate workflow: pubspec version-line, CHANGELOG, fastlane
  changelogs, and Play whats-new.txt changes must ship under a
  `release:`-prefixed commit subject, with version bumps and matching
  changelog files required to land together.

### Fixed
- **#1 — Pair-in-Person deadlock.** When one device scanned the
  other's QR before the originator scanned back, the receiver
  auto-advanced to the four-word verification screen, leaving the
  originator showing its QR with no way to complete the reverse scan
  (going back was treated as cancelling). Pair derivation is now
  gated on both `didShowQr` AND a recorded counterparty key; both
  devices reach verification independently after completing both
  steps. Regression coverage in `pairing_controller_test.dart`.

### Changed
- `Relationship.toString()` and `LivenessPrompt.toString()` now redact
  their sensitive fields (paired-contact label, liveness word) so the
  primary code-side discipline guarantee holds even if either
  representation slips into an error message. Enforced going forward
  by `test/logging/leak_prevention_test.dart`, which canary-injects
  every sensitive type and asserts `toString()` does not contain the
  payload.
- `TotpWords.generate` now has fixed snapshot vectors in
  `test/crypto/totp_words_test.dart` so a silent HKDF or BIP-39
  word-index regression fails the test, not just the property suite.

## [0.3.3] — 2026-05-11

F-Droid maintainer review feedback (round 3) for MR #37990. No
user-visible feature changes versus v0.3.2.

### Changed
- `.github/workflows/release.yml` line 76: inlined `flutter-version: '3.41.6'`
  literal so F-Droid's prebuild can extract the pinned version using
  the canonical regex from `fdroiddata/templates/build-flutter.yml`
  lines 32-34. Source of Flutter-version-truth is now this single
  release.yml line; F-Droid auto-detects future bumps. Comment block
  added to flag the maintenance dependency.
- F-Droid `srclibs:` flipped from `flutter@3.41.6` (hardcoded in
  fdroiddata) to `flutter@stable` + `prebuild:` extract + `git checkout`
  to force the version pinned in release.yml.

## [0.3.2] — 2026-05-09

F-Droid maintainer review feedback for MR #37990. No user-visible
feature changes; affects build outputs for F-Droid distribution only.

### Added
- **ABI-split APK builds** for F-Droid. Per-architecture APKs
  (`armeabi-v7a`, `arm64-v8a`, `x86_64`) carry distinct versionCodes
  (`pubspec-versionCode * 10 + abi-suffix`) computed via a gradle
  `applicationVariants.configureEach` override in
  `android/app/build.gradle.kts`. F-Droid users now download only
  the binary their CPU runs (~3× smaller per-user). Play continues to
  receive a universal AAB at the unmodified pubspec versionCode (the
  override only fires for outputs that carry an ABI filter).

### Changed
- Trimmed `fastlane/metadata/android/en-US/short_description.txt` to
  77 chars (was 81); F-Droid summary policy is strictly < 80 chars.
- Restructured F-Droid `Builds:` block to 3 ABI entries plus
  `VercodeOperation: ['%c * 10 + 1', '%c * 10 + 2', '%c * 10 + 3']`,
  matching the canonical Flutter-app pattern from `templates/build-flutter.yml`
  and `app.bitbag`.

## [0.3.1] — 2026-05-08

F-Droid compliance + maintenance polish. No user-visible behavior
changes; QR pairing, sharing, and file import all behave the same as
v0.3.0.

### Changed
- **QR pairing scanner**: replaced `mobile_scanner` (which bundled
  Google ML Kit Barcode Scanning + Play Services as proprietary native
  code) with `flutter_zxing` 2.3.0 (MIT, ZXing C++ via FFI). Required
  for F-Droid inclusion — F-Droid Inclusion Policy item 5 forbids
  proprietary Google libraries. APK shrinks from 73.1 MB to 64.2 MB.
- `share_plus` 11.1.0 → 12.0.2. No call-site changes (already on the
  v11+ `SharePlus.instance.share(ShareParams(...))` API). Pinned at 12
  rather than 13 because share_plus 13 requires win32 ^6.0.1 which
  conflicts with `flutter_secure_storage_windows`'s win32 ^5.5.4 lock.
- `file_picker` 10.3.10 → 11.0.2. Mechanical migration:
  `FilePicker.platform.pickFiles()` → `FilePicker.pickFiles()` (v11
  refactored to static methods).
- `flutter pub upgrade` refreshed 7 within-range pins:
  `flutter_secure_storage` 10.0.0 → 10.1.0, `go_router` 17.2.1 →
  17.2.3, `vm_service` 15.1.0 → 15.2.0, plus 4 transitives.

### Fixed
- Stripped Gradle 8.5+'s V3.1 "Dependency metadata" signing block via
  `dependenciesInfo.includeInApk = false` in `android/app/build.gradle.kts`.
  F-Droid's APK scanner flagged this block as the 158th anomaly on
  v0.3.0; Play Console accepts AABs without it.

### Internal
- Restructured F-Droid metadata to Fastlane layout
  (`fastlane/metadata/android/en-US/`). F-Droid auto-imports
  description / screenshot / changelog updates from this canonical
  path on every release tag — no further manual fdroiddata content
  MRs needed for future releases.

## [0.3.0] — 2026-04-24

First Internal Testing release. v0.3 adds the bulk-backup primitive
and tightens the video-call threat model with secret-derived liveness.

### Added
- **Bulk backup.** New transport-package payload type `0x03 BLK` carries
  every paired relationship behind one AEAD tag and one 8-word PAKE.
  `Settings → Back up all relationships` exports; the import flow
  auto-dispatches on the payload-type byte (single-LPR or bulk-BLK).
  Per-record collision resolution on import (skip / rename / overwrite).
- **Secret-derived liveness for video-mode verify.** The expected
  physical action is now derived from the shared secret via HKDF-SHA-256
  (role-asymmetric, matching the rotating words). A realtime
  voice+video deepfake without the secret drops from ~100% pass
  probability to 1/2⁴⁷ per 30s window (44 bits words + 3 bits action).
- Standalone `LivenessScreen` retired in favour of a `VIDEO CALL //`
  toggle on `VerifyScreen`. `/liveness/:id` route 301s to
  `/verify/:id?video=1` for one release.
- `WordInput` widget gains a `prefillWords` prop. `backup_import_screen`
  uses it so Load-from-file populates the PAKE word slots visibly
  instead of leaving them blank.

### Changed
- `BindingPhraseScreen` is now peer-scoped (route `/inspect/binding/:id`).
  Previously loaded `relationships.first` — a v0.1 single-peer artifact
  that produced the wrong phrase under multi-peer.
- Video-mode toggle preserves typed-but-unsubmitted words; only
  result banners get cleared on toggle.
- `_VideoModeToggle`, `_ExpectedActionRow`, `_ActionJudgmentPanel`
  wrapped in proper Semantics + liveRegion for TalkBack/VoiceOver.
- `LivenessChallenge.mint()` annotated `@Deprecated` (one-release grace
  window before removal — old callers are already migrated).

### Fixed
- `backup_import_screen` Paste-from-clipboard surfaces an explicit
  error when the clipboard is empty instead of silently no-op'ing.
- Multi-peer binding-phrase mismatch (H1 from the 2026-04-22 audit).

### Security
- HKDF info-string `signet/v2/liveness-action-from-{role}` —
  domain-separated from every other derivation in the codebase.
  Flipping the info string produces an authentication failure rather
  than a different valid output.
- Threat model in `docs/THREAT_MODEL.md` §2.3 reframed for "AI-capable,
  secret-less video attacker A₃" with the 1/2⁴⁷-per-window bound.

### Documentation
- FAQ entry "Why does video-call verify ask for a physical action?"
  added.

## [0.2.0] — 2026-03 (retro entry)

First shippable build. Internal-only — never reached an app store.

### Added
- In-person QR pairing.
- 4-word rotating verify code (BIP-39, role-asymmetric — defeats
  reflection attacks).
- Long-distance pairing via the unified transport package primitive
  (`signet:tp1:` wire format, payload types LDP + LPR).
- Lost-phone recovery: encrypted package, 8-word PAKE, paste / file
  / paper transport.
- Multi-relationship storage with a v1→v2 lazy migration on first
  open after upgrade.
- In-person rekey (`Relationship.id` and label preserved across the
  new ECDH).
- Challenge-response 8×8 grid + printable PDF card.
- Liveness prompts (prompt-only variant; secret-derived in v0.3).
- Android screenshot + screen-recording blocking on sensitive screens.
- First-run walkthrough + post-pair practice nudge.

### Security
- All crypto primitives validated against published RFC test vectors:
  X25519 (RFC 7748), HKDF-SHA-256 (RFC 5869), AES-256-GCM (RFC 5116),
  BIP-39 wordlist (BIP 39).
- Hardware-backed secrets via Android Keystore, with StrongBox
  preference where the device supports it.
- Zero network permissions, zero telemetry, zero analytics.

[0.3.0]: https://github.com/digital-grease/signet/releases/tag/v0.3.0
[0.2.0]: https://github.com/digital-grease/signet/releases/tag/v0.2.0
