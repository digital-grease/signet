# iOS storage audit — flutter_secure_storage on Keychain

Mirror of the Android plaintext-leak audit (see Phase 3.4 in
`.devloop/archive/plan-2026-04-16-v0.1.md` and the sentinel harness
at `lib/dev/secure_store_harness_main.dart`). This doc records what
we've verified about Signet's shared-secret storage on iOS, and — as
importantly — what we **cannot** verify without Apple-entitled
developer tooling.

## What `flutter_secure_storage` does on iOS

The package's iOS implementation writes each secret as a Keychain item
with:

- **Class**: `kSecClassGenericPassword`
- **Service**: default (derived from the app's bundle id; the package
  does not expose a configurable service in the option surface we use)
- **Access control**: `kSecAttrAccessibleAfterFirstUnlock` by default

`kSecAttrAccessibleAfterFirstUnlock` means:

- Secrets are available to our app after the user unlocks the device
  once post-boot.
- Secrets are **not** accessible while the device is locked.
- Secrets are included in iCloud Keychain + iTunes encrypted backups
  by default (`*ThisDeviceOnly` variants exist to exclude, but the
  current plugin configuration does not set them).

**Decision deferred**: whether to override to
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly` via the plugin's iOS
options. `*ThisDeviceOnly` prevents cloud / iTunes backup inclusion —
consistent with the zero-cloud posture — but blocks an iOS-to-iOS
migration via Apple's automatic device-transfer. See "Open questions"
below.

## What we can verify

The existing `lib/dev/secure_store_harness_main.dart` harness writes a
known-plaintext sentinel (`SIGNET_SENTINEL_LABEL_PLAINTEXT`,
`SIGNET_SHARED_SECRET_SENTINEL_32`, etc.). On iOS, we can verify:

1. **Round-trip correctness**: the harness writes + reads + diffs the
   sentinel. Lives in the existing test suite; same test passes on
   iOS as on Android.
2. **Sandbox inspection from the app's own bundle**: we can enumerate
   Keychain items scoped to our app and confirm the values are stored
   as attribute payloads (encrypted at rest by the Keychain daemon),
   not as plaintext in `NSUserDefaults` / `Documents/` / `Library/`.
3. **Filesystem scan**: under a simulator, `find
   ~/Library/Developer/CoreSimulator/Devices/<DeviceId>/data/Containers/Data/Application/<AppId>`
   and grep for the sentinel strings. Any hit is a leak.

The filesystem scan is the closest analog to the Android `adb run-as`
dump from Task 3.4. It's not as complete (see below) but is meaningful.

## What we cannot verify without Apple tooling

The Keychain database itself (`keychain-2.db` on iOS) is not
user-readable from a non-jailbroken device nor via `xcrun` + standard
developer tools. Apple provides:

- `securityd` — the Keychain daemon; no inspection interface.
- `security` CLI on macOS — works on macOS keychains, NOT on iOS
  device keychains.
- Forensic tools (e.g. iExtractor) — require a jailbroken device.

So we **cannot** run the equivalent of Android's "walk the
SharedPreferences XML" inspection. We verify by:

- Confirming the plugin's source-level behavior (via code review of
  `flutter_secure_storage`'s iOS implementation).
- Confirming our sentinel harness reads back correctly.
- Confirming the app-sandbox filesystem scan finds no plaintext.
- Trusting Apple's Keychain-daemon implementation.

This is an **acknowledged gap** in our ability to attest iOS storage
hygiene with the same confidence as Android. It's not a Signet-specific
problem; it applies to every iOS app that uses the Keychain.

## Running the sentinel harness on iOS

```sh
# From repo root, with a simulator running:
flutter run -t lib/dev/secure_store_harness_main.dart -d <simulator-id>
```

After the harness reports "SENTINEL WRITTEN AND ROUND-TRIPPED":

```sh
# Locate the simulator's app sandbox:
simctl_path=$(xcrun simctl get_app_container booted dev.digitalgrease.signet data)
echo "App sandbox: $simctl_path"

# Scan for sentinel strings — any hit is a plaintext leak:
grep -r "SIGNET_SENTINEL_LABEL_PLAINTEXT" "$simctl_path" || echo "OK: no plaintext label"
grep -r "SIGNET_SHARED_SECRET_SENTINEL_32" "$simctl_path" || echo "OK: no plaintext secret"

# Base64 of the secret (in case it's stored encoded but not encrypted):
grep -r "U0lHTkVUX1NIQVJFRF9TRUNSRVRfU0VOVElORUxfMzI=" "$simctl_path" || echo "OK: no base64 secret"

# The 16-byte id hex:
grep -r "deadbeefcafefeed" "$simctl_path" || echo "OK: no id hex"
```

Expected result: all four greps return nothing; the file dump shows
the Keychain-backed items are stored in an encrypted attribute stream
inaccessible without the daemon.

This harness + scan should be re-run on every Phase-12B iOS code
change that could affect storage paths. It's not currently automated
in CI because it requires a booted simulator and simctl access (both
only available on macOS runners); the CI workflow `ios-build.yml`
proves the binary compiles, not that storage is clean.

## Open questions (unresolved at time of writing)

1. **`*ThisDeviceOnly` accessibility flag.** Should we override
   `flutter_secure_storage`'s default `AfterFirstUnlock` to
   `WhenUnlockedThisDeviceOnly`? Consistent with the zero-cloud posture
   but blocks Apple-mediated device migration. Default posture: keep
   the plugin default for v0.2; revisit for v1.0 after seeing whether
   users actually rely on Apple device-transfer for migration (or
   whether they use our LPR backup primitive, which is the
   Signet-native path).
2. **Biometric-gated access** (`kSecAccessControl` with `.biometryAny`).
   Parallel to the Android StrongBox biometrics question; see the
   `flutter_secure_storage` 10.0.0 first-run bug writeup in
   `lib/core/storage/secure_store.dart`. Not ship-blocking; reconsider
   post-v1.0 audit.
3. **Keychain sharing with future iOS extensions / Apple Watch
   companion.** Requires setting a keychain-access-group entitlement.
   Out of scope for v0.2; revisit when/if we add any such target.

## Summary

- Sentinel harness is portable to iOS and confirms round-trip + no
  sandbox-filesystem plaintext.
- We do not (and cannot, without jailbreak) verify the Keychain
  database directly. This gap is documented and accepted, consistent
  with the iOS platform's Keychain trust model.
- Switching to `*ThisDeviceOnly` accessibility is a v1.0 decision,
  not a v0.2 blocker.
