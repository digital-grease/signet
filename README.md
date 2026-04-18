# Signet

Cryptographic multi-factor authentication for **human relationships**, not accounts.

When someone who sounds like your mother calls in a panic asking for bail money, Signet lets you verify it's actually her. Each paired contact generates a rotating 4-word phrase that only the real person's phone can produce; you ask her to read her phrase aloud and type what you hear. Works over any channel — voice call, video call, text, email, in person.

The threat: voice and video deepfakes targeting families for financial fraud; vishing attacks that use scraped biographical data to impersonate people you know. The defense: a shared secret that was seeded device-to-device in person, and that no amount of AI voice cloning can recover.

## Status

**v0.1 alpha. Android-only. Not yet shipped to any app store.** See [Development roadmap](#development-roadmap) for what's missing.

Built on Flutter for future cross-platform support; iOS is generated but not tested in this release.

## How it works

Two phones pair in person by exchanging QR codes containing ephemeral X25519 public keys. Each device derives the same shared secret via Diffie–Hellman. Both devices then display an identical 4-word confirmation phrase derived from that secret — a visual check that the pairing wasn't intercepted. Once confirmed, the shared secret lives in the Android Keystore (hardware-backed when available) and is used to generate a **rotating 4 BIP-39 words every 30 seconds** (HKDF-SHA-256, domain-separated from the pair-time phrase, ±1 window tolerance for clock drift).

To verify a caller later: open Signet, tap the contact, ask them to read their 4 current words aloud. Type what you hear into the 4-slot input (BIP-39 autocomplete: two letters narrows to a chip you can tap). ✅ green banner = verified, ❌ red banner = not verified. On ❌ the input clears and you can retry immediately.

### Why words, not digits?

The original design called for an 8-digit TOTP code, but 8 digits don't survive a stressed voice channel — "74" vs. "47" under a bad connection is how grandma gets scammed. BIP-39 was specifically designed to transfer high-entropy secrets cleanly over voice (4 words ≈ 44 bits vs. ~27 for 8 digits, and the words are phonetically distinct by construction). Using the same wordlist we already embed for pair-time verification gives Signet a coherent visual/verbal language and makes the ±1 window tolerance do real work via a binary ✅/❌ instead of eyeball-comparing two 8-digit strings.

### Why the two sides see *different* words

A naïve rotating-code design would give both paired devices the same 4 words each window — but then an attacker can say *"grandma, before we talk, read me your words so I know it's really you,"* parrot them back, and pass the verify. Signet binds each rotating code to a direction: at pair time each device independently derives a role (`a` or `b`) from the byte-lexicographic ordering of the two X25519 public keys. The HKDF info string is role-suffixed, so the A→B words and the B→A words for any given window are different. "Show my 4 words" renders your role; the verify input checks against the *other* role. Reflecting the verifier's own displayed words back fails immediately. See `lib/core/crypto/pair_role.dart` and the reflection-attack test in `test/crypto/totp_words_test.dart`.

### Properties

- **No server, no cloud, no account.** The app literally has no `INTERNET` permission in its manifest. There is no backend to subpoena, compromise, or shut down.
- **No telemetry, no analytics, no ads.** This is a trust product. Not now, not ever.
- **Hardware-backed secrets.** Shared secrets are held in Android Keystore behind AES-GCM, StrongBox-backed on devices that support it.
- **Offline by construction.** Airplane mode does not affect any flow.
- **RFC-validated crypto.** X25519 against [RFC 7748 §6.1](https://www.rfc-editor.org/rfc/rfc7748#section-6.1); 8-digit RFC-6238 TOTP against [RFC 6238 Appendix B](https://www.rfc-editor.org/rfc/rfc6238#appendix-B) (SHA-256 variant, retained as a reference implementation); HKDF-SHA-256 via the audited [`cryptography`](https://pub.dev/packages/cryptography) package. BIP-39 wordlist embedded in-tree. All reference vectors pass.

## Building

### Requirements

- Flutter stable channel (3.41+)
- Android toolchain: SDK Platform 34+, Command-line Tools, and licenses accepted
- An Android 9+ device or emulator (the minimum SDK is API 28 — StrongBox availability)

Check your environment:

```sh
flutter doctor
```

The Android toolchain row must be `[✓]`. Chrome / web / iOS / macOS rows can be ignored — Signet does not target those platforms at present.

### Build and run

```sh
git clone <this-repo>
cd signet
flutter pub get
flutter run -d <device-or-emulator-id>
```

First build downloads the Android Gradle Plugin and the NDK; subsequent builds are fast.

### Release build

```sh
flutter build apk --release
```

The APK lands at `build/app/outputs/flutter-apk/app-release.apk`. v0.1 is signed with the debug key; production signing is v1.0 work.

## Testing

```sh
flutter test            # all unit and widget tests
flutter analyze         # static analysis against strict lints
```

The test suite is ~80 tests across crypto, storage, pairing state, and widget layers. The crypto modules are pure-Dart pure functions validated against RFC reference vectors and are safe to port elsewhere.

On-device integration testing (full two-phone pair + verify roundtrip) is manual in v0.1 and lives in the [pre-release checklist](#pre-release-manual-qa).

## Project layout

```
lib/
├── main.dart              # entrypoint
├── app.dart               # MaterialApp + go_router
├── core/
│   ├── crypto/            # pure-Dart TOTP, X25519 ECDH, 4-word phrase, BIP-39 wordlist
│   ├── storage/           # flutter_secure_storage wrapper (single-slot for v0.1)
│   ├── models/            # Relationship metadata (no secret on model)
│   └── providers.dart     # Riverpod wiring
├── features/
│   ├── home/              # home screen — empty or paired
│   ├── pairing/           # start / exchange (show+scan) / confirm
│   └── verify/            # type-and-verify input + show-my-words fallback
└── shared/widgets/        # BigButton, CodeDisplay
```

## Security notes

### What this defends against

- Real-time voice deepfakes (ElevenLabs-class synthesis)
- Real-time video deepfakes in calls
- Pre-recorded deepfake voicemails
- Vishing using socially-engineered biographical knowledge
- Compromised messaging accounts where the attacker has chat history but not the paired device
- SIM swaps (the secret is device-local, not phone-number-bound)

### What it does not defend against

- Physical device compromise (attacker has the unlocked phone)
- Shoulder surfing (attacker visually captures the code on screen)
- Coercion of the real person (they produce a valid code under duress)
- A paired attacker — if you paired with the wrong person to start, Signet has no way to know

### Storage

The v0.1 secure storage configuration uses the plugin's standard `AndroidOptions`:

- Master AES key wrapped via RSA/ECB/OAEPwithSHA-256andMGF1Padding in Android Keystore
- Stored data encrypted via AES/GCM/NoPadding
- `resetOnError: false` — transient failures surface rather than silently wiping a user's pairing
- StrongBox is requested; the plugin falls back to TEE-backed Keystore on devices that lack it

The stronger `AndroidOptions.biometric()` path (AES-GCM for both key wrap and data, StrongBox-preferred) is deferred because `flutter_secure_storage` v10.0.0 has a first-run algorithm-migration bug under that constructor. Both paths are hardware-backed; the security difference is negligible at the threat-model level of this app.

### QR payload

Pairing QR codes use the wire format `signet:p1:<base64url(public_key)>`, where the body is the 32-byte X25519 public key with no base64 padding. The `signet:p1:` prefix prevents a stray URL or other QR from being parsed as a pairing payload.

## Development roadmap

Ordered roughly by shipping impact.

### v0.1 (this release)

- In-person QR pairing (two scans, symmetric flow)
- 4-BIP-39-words type-and-verify with ±1 window tolerance + show-my-own-words fallback
- Hardware-backed secure storage
- One relationship per device

### v0.2

- Multiple paired contacts
- Challenge-response wordlist mode (for when the other party can speak but not produce a code)
- Out-of-band pairing (send an encrypted pairing package via Signal / iMessage / email with a spoken password)

### v0.3

- Liveness prompts for video calls (hold up N fingers, say today's day)
- Printed-paper recovery pairing
- Same-device encrypted backup/restore

### v1.0

- Duress codes (pending an abuse-analysis pass)
- External security audit
- Reproducible builds
- iOS parity
- Play Store / App Store release

## Known limitations in v0.1

- **Android only.** iOS builds but is untested.
- **One relationship per device.** Intentional for shipping simplicity; multi-contact is v0.2.
- **StrongBox best-effort.** Some OEMs disable StrongBox even on API 28+ devices; detection / explicit attestation is v1.0 work.
- **No on-device verification step.** v0.1 shows the code and leaves comparison to the humans. A future version may add "type what they said" for an explicit match UI.
- **No duress codes.** Deferred pending misuse analysis.
- **Debug-signed release builds.** Do not ship to anyone.
- **Scanner has no explicit "permission permanently denied" recovery.** The in-app message is friendly but does not offer a deep link to system settings.

## Pre-release manual QA

Before any real-world distribution, validate on physical hardware:

1. **Full two-device pair + verify roundtrip.** Use two Android 9+ phones. Both should derive identical 4-word pair-time phrases; on the Verify screen, typing one phone's current 4 rotating words into the other's 4-slot input should produce a ✅ banner.
2. **Inspect `/data/data/dev.signet.app/shared_prefs/`** after pairing. Confirm the shared secret never appears in plaintext.
3. **Accessibility:** complete the pair flow using only TalkBack (screen reader).
4. **Large text:** set the system font size to max; re-walk the paired state, Verify screen, and Pair-confirm screen (these were not reachable during v0.1 emulator-only QA).
5. **Clock drift:** on two paired phones, set one clock ±30s. The displayed codes on both should still match via the verifier's ±1-window tolerance.
6. **Offline:** enable airplane mode on both phones; the full pair + verify loop should work unchanged.
7. **Uninstall:** after unpair-and-uninstall, confirm no app data survives in `/data/data/dev.signet.app/`.

## Contributing

Signet is solo-maintained alpha software. Issues and PRs are welcome, but please understand that the threat model and UX constraints (the "grandma test" in particular) are design constraints, not suggestions — PRs that add network calls, analytics, or account systems will not be merged under any circumstances.

## License

GPL-3.0. See [LICENSE](LICENSE).

This is user-sovereign software. The license reflects that.
