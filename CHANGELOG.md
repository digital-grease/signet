# Changelog

All notable changes to Signet will appear in this file. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) loosely;
versioning follows [Semantic Versioning](https://semver.org/) — pre-1.0
the surface is allowed to change between minor releases.

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
