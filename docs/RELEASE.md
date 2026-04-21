# Signet release playbook

End-to-end instructions for producing a signed, distributable Signet
release. Most of this is owner-action — I (the app) cannot sign an
APK on your behalf, generate a keystore on your machine, or upload
anything to a store. This document is the runbook for you to do
those things.

Prerequisites: familiarity with `keytool`, GitHub repo admin access,
the scaffolding in Phase 9.15 (`android/key.properties.example` +
the signingConfigs in `android/app/build.gradle.kts`) and Phase 12.4
(`.github/workflows/release.yml`).

---

## 1. One-time: generate your production keystore

Run this once per app identity (bundle id). The output file is the
root-of-trust for every future release; losing it means you can
never push an update that installs over existing installs.

```sh
# Choose a safe place OUTSIDE the repo. The repo is gitignored against
# `*.jks` and `*.keystore`, but a keystore in your source tree is one
# errant `git add -f` away from disaster.
mkdir -p ~/keystores && cd ~/keystores

keytool -genkey -v \
  -keystore signet-release.jks \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -alias signet
```

Prompts:

- **Key password** (`-keypass`): pick a long random passphrase.
- **Keystore password** (`-storepass`): same or different; `keytool`
  defaults them to equal when you accept the "use keystore password"
  prompt.
- **Distinguished name fields** (CN, OU, O, L, ST, C): can be
  anything meaningful to you. Play Store does not require specific
  values for these.

Write down the passwords in a password manager + a physical location.
Nothing we do below can recover them.

### Back up the keystore

Three copies, two different media, one off-site. Minimum:

1. **Primary**: the `~/keystores/signet-release.jks` file on your
   working machine. Confirm it's on an encrypted-at-rest filesystem
   (FileVault / LUKS / BitLocker).
2. **Offline**: copy to a USB drive or SD card stored somewhere
   physically separate.
3. **Off-site**: a safety deposit box, a trusted-family-member's
   safe, or an encrypted cold-storage backup.

**Do not upload the keystore to a cloud service** (Google Drive,
iCloud, Dropbox). Those are inconsistent with Signet's threat model
on principle; they're also exactly where an attacker would look
first if they compromised your credentials.

### Verify the keystore

```sh
keytool -list -v -keystore ~/keystores/signet-release.jks
```

Should print the certificate fingerprint, alias, validity dates,
owner DN, etc. **Record the SHA-256 fingerprint** — you'll use it to
verify that a given APK was signed by this keystore and not a
substitute.

## 2. Per-machine: set up local production builds

If you want to produce signed APKs on your laptop outside of CI
(useful for debugging release-mode behavior, testing upgrade paths
between old + new signed versions, etc.):

```sh
cd <signet-repo-root>
cp android/key.properties.example android/key.properties
```

Edit `android/key.properties` with your absolute path + passwords:

```properties
storeFile=/home/you/keystores/signet-release.jks
storePassword=your-store-password
keyAlias=signet
keyPassword=your-key-password
```

`android/key.properties` is gitignored — it will never be committed.
The `build.gradle.kts` wiring from Phase 9.15 reads this file at
build time.

```sh
# AAB — Play Console upload artifact.
flutter build appbundle --release
# Artifact: build/app/outputs/bundle/release/app-release.aab
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab

# APK — F-Droid fingerprint source + direct sideload.
flutter build apk --release
# Artifact: build/app/outputs/flutter-apk/app-release.apk
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
# Both SHA-256 fingerprints should match what you recorded in § 1.
```

If either fingerprint says `CN=Android Debug`, your `key.properties`
is not wired correctly — most commonly a typo in the path or a
permissions issue on the `.jks` file.

## 3. One-time: configure GitHub Secrets for the release workflow

The `.github/workflows/release.yml` pipeline (Phase 12.4) expects
four secrets. Set them at:

**GitHub → your repo → Settings → Secrets and variables → Actions →
New repository secret**

| Secret name | Value |
|-------------|-------|
| `ANDROID_KEYSTORE_BASE64` | Output of `base64 -w0 ~/keystores/signet-release.jks`. One long string; paste it entirely. |
| `ANDROID_KEYSTORE_PASSWORD` | The `-storepass` you used in § 1. |
| `ANDROID_KEY_ALIAS` | `signet` (or whatever `-alias` you chose). |
| `ANDROID_KEY_PASSWORD` | The `-keypass` you used in § 1. |

The base64 encoding:

```sh
base64 -w0 ~/keystores/signet-release.jks
# Copy the output — one long line, no line wraps — and paste it
# into the GitHub Secrets dialog. The `-w0` matters; without it you
# get wrapped lines that the workflow would need to pre-process.
```

Once the four secrets are set, you can delete the base64 output from
your terminal scrollback. The secret lives in GitHub from this point
on.

## 4. Per-release: tagging and shipping

Signet releases use semantic version tags matching the
`.github/workflows/release.yml` trigger: `v<major>.<minor>.<patch>`
with an optional pre-release suffix like `-alpha.1`, `-beta.2`,
`-rc.1`.

### Prepare the release commit

1. Make sure `main` is fully green in CI.
2. Bump `version:` in `pubspec.yaml`. Example: `version: 0.2.0+1`.
   (The `+N` is the Android `versionCode`; bump it by at least 1
   on every release, monotonically.)
3. Update `CHANGELOG.md` (create if missing — each release gets a
   section).
4. Commit + push to main.

### Tag + push

```sh
git tag -a v0.2.0 -m "Signet v0.2.0

Highlights:
- Multi-peer + role-asymmetric rotating code
- Long-distance pair + lost-phone recovery
- Liveness prompts
- Challenge-response printable card
"

git push origin v0.2.0
```

Annotated tags (`-a`) are required — the release workflow reads the
tag's commit message and embeds it into the GitHub Release body.

### Watch the release workflow run

GitHub → Actions → "Release" workflow. On a clean run it:

1. Builds a signed release **AAB** + **APK** on `ubuntu-latest` (reads
   your four secrets + decodes the keystore at build time + wipes it
   from the workspace at the end of the job). Both formats are needed:
   AAB goes to Play Console (required for new apps since Aug 2021),
   APK goes to F-Droid + direct sideload + the owner's smoke test.
2. Verifies BOTH artifacts are **not** debug-signed (explicit check
   in the workflow — it fails the build if either signature says
   `CN=Android Debug`).
3. Builds an unsigned iOS `.app.zip` on `macos-latest`.
4. Publishes a GitHub Release at the tag with all three artifacts +
   SHA-256 checksum files + the tag's annotated-message body.

### Verify the published artifacts

Before you tell anyone to download them:

```sh
# Download each artifact + checksum from the GitHub Release page.
sha256sum -c signet-v0.2.0.aab.sha256
sha256sum -c signet-v0.2.0.apk.sha256
# Expected: "signet-v0.2.0.<ext>: OK" for each.

# Confirm both signatures match your keystore fingerprint.
keytool -printcert -jarfile signet-v0.2.0.aab | grep 'SHA256:'
keytool -printcert -jarfile signet-v0.2.0.apk | grep 'SHA256:'
# Both should match the fingerprint you recorded in § 1.
```

If any check fails, **do not distribute**. Investigate the CI run
logs. Common cause: a typo in `ANDROID_KEY_PASSWORD` results in the
fallback debug-signing path, which the workflow's explicit check
catches — but only if the check is actually running (i.e. you didn't
modify `release.yml` to skip it).

### Which artifact goes where

| Channel | Upload |
|---------|--------|
| Play Console (Internal testing → Create new release) | `signet-vX.Y.Z.aab` |
| F-Droid (`AllowedAPKSigningKeys` in `metadata/dev.digitalgrease.signet.yml`) | fingerprint from `signet-vX.Y.Z.apk` |
| Direct sideload (test device, non-Play user) | `signet-vX.Y.Z.apk` |
| iOS TestFlight | not via this artifact — archive + upload from Xcode (see `docs/IOS_VALIDATION.md`) |

## 5. What if the keystore is compromised

Worst-case scenario: your production keystore file leaks (laptop
stolen and disk wasn't encrypted, USB backup found). An attacker
can now sign APKs that install over your user's existing installs.

### If you enrolled in Play App Signing

Play App Signing separates the **upload key** (what you hold) from
the **app signing key** (what Google holds, never leaves their
infrastructure). If only the upload key leaked, you can:

1. Generate a new upload key (rerun § 1 with a different filename).
2. Open a "Upload key reset" request in Google Play Console.
3. Upload the new public key.
4. Google signs future releases with the same app signing key, but
   only accepts uploads signed with the new upload key.

No user action required; installed apps keep working.

### If you did NOT enroll in Play App Signing

The production keystore is the app signing key. Recovery is
**impossible**. You must:

1. Publish a security advisory to your users (assume the attacker
   could push malicious updates from now on).
2. Publish a new app at a new package name (`dev.digitalgrease.signet2` or similar).
3. Ask every user to uninstall the compromised app and install
   the new one. They will lose every paired relationship unless
   they did a `BackupBundle` export (Phase 11.8).

This is why Play App Signing is strongly recommended for any app
with non-trivial installed base.

### If distributing via F-Droid

F-Droid signs apps with its own key, so a keystore leak doesn't
compromise the F-Droid channel's installs. But users who
sideloaded the Play APK would still be vulnerable.

## 6. Post-release checklist

- [ ] GitHub Release visible at
      `https://github.com/digital-grease/signet/releases/tag/vX.Y.Z`.
- [ ] `sha256sum -c *.sha256` checks pass against both artifacts.
- [ ] `keytool -printcert` SHA-256 fingerprint matches the reference
      from § 1.
- [ ] CHANGELOG.md entry for the release is merged into main.
- [ ] Status in README.md updated if any pre-release → full-release
      promotion happened.
- [ ] If v0.2-alpha, announce in the channels you've chosen (issue
      tracker, whatever community). Be clear it's alpha.
- [ ] If v1.0, coordinate with any external auditor's sign-off.

## 7. Related docs

- `docs/CI.md` — the four GitHub Actions workflows including
  `release.yml`.
- `docs/REPRODUCIBLE_BUILD.md` — how a third party can build the
  APK from source and compare bits.
- `docs/THREAT_MODEL.md` — why signing matters + what it defends
  against + what it doesn't.
- `docs/LIMITATIONS.md` § L-BUILD-* — the build/distribution gaps
  this playbook doesn't close.

---

## Changelog

- 2026-04-19 · initial playbook (Phase 12.16).
