# Signet

Cryptographic multi-factor authentication for **human relationships**, not accounts.

When someone who sounds like your mother calls in a panic asking for bail money, Signet lets you verify it's actually her. Each paired contact generates a rotating 8-digit code that only the real person's phone can produce. Works over any channel — voice call, video call, text, email, in person.

The threat: voice and video deepfakes targeting families for financial fraud; vishing attacks that use scraped biographical data to impersonate people you know. The defense: a shared secret that was seeded device-to-device in person, and that no amount of AI voice cloning can recover.

## Status

**v0.1 alpha. Android-only. Not yet shipped to any app store.** See [Development roadmap](#development-roadmap) for what's missing.

Built on Flutter for future cross-platform support; iOS is generated but not tested in this release.

## How it works

Two phones pair in person by exchanging QR codes containing ephemeral X25519 public keys. Each device derives the same shared secret via Diffie–Hellman. Both devices then display an identical 4-word phrase derived from that secret — a visual confirmation that the pairing wasn't intercepted. Once confirmed, the shared secret lives in the Android Keystore (hardware-backed when available) and is used to produce 8-digit RFC 6238 TOTP codes with a 30-second window.

To verify a caller later: open Signet, tap the contact, ask them to read their current code aloud, compare to yours. Match means authentic. Mismatch means hang up.

### Properties

- **No server, no cloud, no account.** The app literally has no `INTERNET` permission in its manifest. There is no backend to subpoena, compromise, or shut down.
- **No telemetry, no analytics, no ads.** This is a trust product. Not now, not ever.
- **Hardware-backed secrets.** Shared secrets are held in Android Keystore behind AES-GCM, StrongBox-backed on devices that support it.
- **Offline by construction.** Airplane mode does not affect any flow.
- **RFC-validated crypto.** TOTP against [RFC 6238 Appendix B](https://www.rfc-editor.org/rfc/rfc6238#appendix-B) (SHA-256 variant); X25519 against [RFC 7748 §6.1](https://www.rfc-editor.org/rfc/rfc7748#section-6.1). All 10 reference vectors pass.

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
│   └── verify/            # live TOTP code display
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
- TOTP-style verification display
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

1. **Full two-device pair + verify roundtrip.** Use two Android 9+ phones. Both should derive identical 4-word phrases and identical 8-digit codes.
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
