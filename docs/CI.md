# CI / CD

Signet's build pipeline is four GitHub Actions workflows under
`.github/workflows/`. All jobs run on GitHub-hosted runners; no
self-hosted infrastructure.

## Workflows

### `ci.yml` — analyze + test

**Triggers:** every push to `main`, every pull request, manual dispatch.

**Does:** `flutter analyze` + `flutter test --coverage`. Uploads
`coverage/lcov.info` as a 14-day artifact. Fails on any analyzer
info/warning/error or any failing test.

**Cost:** ~3–5 minutes per run, Linux runner (1× multiplier). Runs on
every PR — keep it cheap.

### `android-build.yml` — unsigned release AAB + APK

**Triggers:** push to `main`, version tags (`v*.*.*`), manual dispatch.

**Does:** `flutter build appbundle --release` + `flutter build apk --release`
with the default debug-signing fallback (see `android/app/build.gradle.kts`).
Uploads both artifacts + SHA-256 checksums as a 30-day artifact. Both formats
are produced because the release channels need different things:
AAB is required for Play Console (new-app submissions since Aug 2021),
APK is used by F-Droid + direct sideload + the owner's on-device smoke test.

**Cost:** ~8–12 minutes per run (first run is slower due to Gradle +
NDK downloads; subsequent runs hit the cache). Linux runner.

**Intentionally debug-signed** so we can run this on every main-branch
push without exposing production signing secrets. Signed artifacts
only fire on version tags via `release.yml`.

### `ios-build.yml` — iOS unsigned compile-check

**Triggers:** push to `main`, version tags, manual dispatch.

**Does:** `flutter build ios --release --no-codesign` on a `macos-latest`
runner. Uploads the resulting `Runner.app.zip` + SHA-256 as a 30-day
artifact. Does NOT produce an IPA (that needs Apple Developer
credentials + provisioning profile setup).

**Cost:** ~15–25 minutes per run on macOS (10× multiplier on the
runner-minute bill). Intentionally does NOT run on every PR to
conserve minutes — only `main` pushes and tags.

**Does NOT run TestFlight uploads.** Signed iOS distribution is a
post-v1.0 concern; this workflow exists to prove the iOS toolchain
compiles our source.

### `release.yml` — tagged release with signed AAB + APK

**Triggers:** version tags matching `v<major>.<minor>.<patch>` or
`v<major>.<minor>.<patch>-<prerelease>` (e.g. `v0.2.0-alpha.1`).

**Does:**
1. **Android signed build** — decodes the production keystore from
   `ANDROID_KEYSTORE_BASE64`, writes `android/key.properties` pointing
   at it, runs `flutter build appbundle --release` + `flutter build
   apk --release`. Verifies BOTH outputs were NOT signed with the
   Android debug key (safety check runs against the AAB and the APK
   independently). Wipes the keystore + `key.properties` from the
   workspace in an `always()` step before the runner terminates.
2. **iOS unsigned build** — same as `ios-build.yml`.
3. **Publish** — creates / updates a GitHub Release at the tag with
   both artifacts attached, auto-generated body (SHA-256s + verification
   command + tag message), marked as prerelease if the tag contains
   a hyphen (`-alpha`, `-beta`, `-rc`).

## Required secrets (release.yml)

Set these in **Settings → Secrets and variables → Actions** on GitHub:

| Secret | Value |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 ~/keystores/signet-release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | The `-storepass` from `keytool`. |
| `ANDROID_KEY_ALIAS` | The `-alias` from `keytool` (e.g. `signet`). |
| `ANDROID_KEY_PASSWORD` | The `-keypass` (often same as storepass). |

See `docs/RELEASE.md` (Phase 12.16, to come) for the full keystore
generation and release-tagging playbook.

## Bumping the Flutter version

All four workflows share a pinned Flutter version via an `env` block at
the top. To upgrade:

1. Upgrade locally: `flutter upgrade` → run tests → push a commit.
2. Edit `env.FLUTTER_VERSION` in each of the four workflows to match
   the output of `flutter --version`.
3. The first CI run after the bump will rebuild the Flutter cache from
   scratch; subsequent runs hit the new cache.

The four workflows are intentionally not merged into a single shared
config because GitHub Actions doesn't have a clean include mechanism
for non-reusable-workflow deduplication, and each workflow's trigger
semantics is different enough that sharing would leak concerns.

## What CI does NOT do (yet)

- **iOS signed IPA** — needs Apple Developer credentials, provisioning
  profiles, `EXPORT_OPTIONS.plist`. Post-v1.0.
- **TestFlight upload** — same.
- **Play Store internal-track upload** — lands when Task 12.18 scaffolds
  the listing metadata.
- **F-Droid reproducible build** — lands when Task 12.15 sets up the
  Dockerfile + reproducible-build script.
- **Codecov / Coveralls integration** — we upload coverage as an
  artifact only. The project stance is no external-service network
  dependencies in the build path.
