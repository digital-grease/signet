# Signet privacy policy

**Effective date:** 2026-04-19
**Version:** 1.0

This is the user-facing privacy policy for the Signet app. It's
written in plain English and kept short. The short version is:
**Signet collects nothing. Signet sends nothing. Signet has no
server.** The long version below elaborates what that means in
practice — what data exists on your device, what data the operating
system might expose to its own vendors, and what data Signet
explicitly does not touch.

If you want to understand *why* Signet is built this way, read
`docs/THREAT_MODEL.md` alongside this policy.

---

## What Signet collects

**Nothing.**

Signet does not:

- Send any network request of any kind. The Android app does not
  request the `INTERNET` permission. On iOS, no code path in the app
  invokes networking APIs.
- Record analytics, usage data, crash reports, screen recordings,
  performance traces, or anything else about how you use the app.
- Register a user account. There is no sign-up, no email, no phone
  number, no user ID of any kind.
- Maintain a server on your behalf. There is no Signet backend.
  There is no Signet admin console. Nothing to subpoena. Nothing to
  hack.
- Share data with advertising networks, attribution providers, or
  marketing partners. There are no such partners.

**Verify for yourself**: Signet is open source. Search the source
for `http`, `https`, `socket`, `package:http`, `dart:io.HttpClient`
and similar — you will find none of them invoked. Inspect
`android/app/src/main/AndroidManifest.xml`: the `INTERNET`
permission is explicitly absent.

## What is stored on your device

Signet stores the following **on your device only**, in hardware-
backed secure storage:

- A list of paired contacts. For each contact: your chosen label
  ("Mom", "Jake"), a random 128-bit local identifier, the date you
  paired, a role byte derived from the pairing handshake, a
  per-relationship silent-haptics preference, and the cryptographic
  shared secret established during pairing.

On Android, this is kept in the Android Keystore, wrapped via
RSA-OAEP over an AES-GCM storage cipher, StrongBox-backed when the
device supports it. On iOS, it's kept in the Keychain as a generic
password item accessible only after the device has been unlocked.

Signet also stores one non-sensitive flag:

- Whether you have completed the first-run onboarding walkthrough.
  (Plain SharedPreferences on Android / NSUserDefaults on iOS.)

Neither the secrets nor the onboarding flag leave your device
through any Signet code path.

## What the operating system may collect

These are data flows Signet does not control — they are the
operating system's behavior, not the app's.

### Android

- If you install from the Google Play Store, Google records that
  install (counted on the Play Console). That install record is
  visible to the developer (as an aggregate number) and to Google.
- The Android OS writes app-install events to its own device logs,
  which may be included in full-device backups.
- Android's Accessibility Services — if you have any enabled —
  can observe screen content of any app. Signet blocks this on
  sensitive screens via `FLAG_SECURE`, but an accessibility
  service that runs before `FLAG_SECURE` is applied (e.g. during
  screen transitions) could in principle see UI state.

### iOS

- Apple records App Store installs similarly.
- iCloud Keychain is enabled by default on most iPhones. Signet's
  current iOS storage configuration accepts the Apple-default
  `kSecAttrAccessibleAfterFirstUnlock`, which means paired-contact
  data **is** included in iCloud Keychain + iTunes encrypted
  backups. See the
  [iOS storage audit](./IOS_STORAGE_AUDIT.md) for why
  we haven't tightened this to `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
  in v0.2.
  - You can disable iCloud Keychain system-wide: **Settings →
    [your name] → iCloud → Passwords and Keychain → off**.

### Both platforms

- If you use the "Share backup" or "Print challenge-response grid"
  features, the OS share-sheet / print dialog shows you a list of
  destination apps. **The destinations you choose may themselves
  be networked services** (Google Drive, iCloud Drive, Gmail,
  etc.). Signet hands the backup text or PDF to the destination
  you picked and the destination takes it from there. Where that
  content ends up is between you and the destination app.

Signet warns you about this in-app (the backup export screen's
"STORE THESE SEPARATELY" callout), but the choice is yours and the
responsibility is yours.

## What Signet specifically does NOT do

Stated for clarity, in case any of these are surprising:

- **No automatic crash reporting.** Nothing reports automatically
  to Firebase Crashlytics / Sentry / any other service. If Signet
  crashes, the stack trace is captured locally, encrypted at rest
  with AES-256-GCM under a key in your device's secure enclave, and
  stays on your device until you act. On the next launch the app
  will offer to open a pre-filled GitHub issue with the trace; you
  see and can edit everything before you submit. If you decline,
  nothing leaves the device.
- **No remote kill switch.** Signet cannot disable itself on your
  device. We couldn't push a kill even if we wanted to — there's
  no server connection to push over.
- **No remote config.** App behavior is what was compiled into the
  APK. No feature flags are fetched at runtime.
- **No A/B tests.** The app you have is the app everyone with the
  same version has.
- **No ads.** There is no ad-serving infrastructure in the app,
  and there is no plan to add any.
- **No emergency contact sharing.** If you mark a pair as "family"
  for example (which isn't a current feature), we would not use
  that information to contact that pair on your behalf under any
  circumstance.

## Third-party Dart/Flutter packages

Signet is built on several open-source packages. We verify at build
time that none of them make network calls in the paths Signet
exercises, but we cannot audit every byte of every dependency on
your behalf. The packages used are listed in `pubspec.yaml`. Our
threat model (`docs/THREAT_MODEL.md` § 4) documents which package
behaviors we trust.

If you are the sort of user who verifies package provenance
independently, our commitment is that we pin specific versions of
each dep (no floating `any` or `^x.y` without a committed lockfile)
and call out dep changes in our changelog.

## Changes to this policy

If this policy changes, the `version` at the top and the
`Effective date` update. Historical versions remain in git history
at `PRIVACY.md`.

A change that would move Signet toward collecting anything about
its users is not something that will quietly happen in a point
release — it would be a breaking-posture change, announced clearly,
and accompanied by a major version bump. At the current author's
discretion, such a change is unlikely to the point of "never."

## Contact

Signet is open source. If you want to understand any of this
better, file an issue at
[https://github.com/digital-grease/signet/issues](https://github.com/digital-grease/signet/issues).

There is no email address for this policy. There is no mailing
address. We do not have a compliance officer, a data protection
officer, or a dedicated privacy contact — because we have no data
to protect in the first place.

## Legal status

This policy is written in plain English and is not a substitute
for legal counsel. If you are a regulator or counsel examining
Signet's posture against a legal regime (GDPR, CCPA, etc.), the
short answer is: we don't process personal data. We don't collect
it. We don't store it on any system we control. We don't share it.
The legal frameworks that regulate how data is collected, stored,
and shared have nothing to operate on.

If that's not what your regulator needs to hear, get in touch via
the GitHub issue tracker and we'll work it out in public.
