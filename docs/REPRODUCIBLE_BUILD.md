# Reproducible build

Signet aims for byte-identical APKs from any clean checkout of a given
git tag. This matters for three reasons:

1. **F-Droid** rebuilds every release from source on its own build
   server.
2. **Independent audit credibility.** A third-party reviewer should be
   able to compile the source and get the same bytes we shipped.
   Divergence is a red flag.
3. **Supply-chain trust.** If an attacker tampered with our toolchain
   but not the committed source, a rebuild on a clean machine would not
   match our release artifact. Detection without trusting us.

**Current status:** verified on one machine. On 2026-10-10 two clean
runs of the same commit (fresh cache and clones each time, final pass
offline) produced byte-identical APKs for all three ABIs. A match
across two different machines, or against F-Droid's build, is not yet
verified.

## Moving parts

### `Dockerfile.reproducible`

The build image. Pinned:

- Base image by digest: Eclipse Temurin 25 JDK on Ubuntu 24.04, the
  same JDK major CI uses (`JAVA_VERSION` in `.github/workflows/release.yml`).
- Flutter version and the exact commit it must resolve to. The build
  fails if the version tag points anywhere else.
- Android command-line tools archive, checked against the SHA-1 that
  Google's repository index publishes for it (the only digest Google
  provides for that file).
- Every SDK component by exact version: platforms 34, 35 and 36,
  build-tools 35.0.0, NDK 28.2 and 27.0, CMake 3.22.1. Each is the
  version the app or one of its plugins asks for. `sdkmanager` checks
  each download against Google's index.
- `LANG` / `LC_ALL` / `TZ` (C.UTF-8, UTC).

The Android SDK is read-only to the build user, so a build that wants a
component the image lacks fails instead of downloading one quietly.
The Flutter tool's own Dart dependencies are resolved into
`/opt/pub-cache` at image build time, readable by any uid; otherwise
the tool re-resolves them on every run, online, and the offline pass
fails.

Gradle dynamic versions (`1.2+`) cannot resolve offline and can drift
between builds. Flutter's dev-only `integration_test` plugin declares
some and `assembleRelease` still builds it, so `android/build.gradle.kts`
pins them.

Ubuntu packages (git, curl, unzip, xz) are not snapshot-pinned. They
only fetch sources and unpack archives and do not reach the APK.

Build the image without a context (it copies nothing from the repo):

```sh
docker build -t signet/repro:latest - < Dockerfile.reproducible
```

### `scripts/reproducible-build.sh`

Given a git ref:

1. Resolves the ref to a commit, takes `SOURCE_DATE_EPOCH` from the
   commit's committer time and the version from its `pubspec.yaml`.
2. **Warm pass** (network on): a fresh, self-contained clone of the
   commit, then the full release build. This fills a cache directory
   with pub packages, the Gradle distribution and Maven dependencies.
   Its APKs are thrown away.
3. **Build pass** (`--network=none`): a second fresh clone, built
   again from the warmed cache with `flutter pub get --offline`. Any
   step that still needs the network fails here. `flutter build` has
   no `--offline` and `--no-pub` would skip the release-mode plugin
   registration, so the script touches `pubspec.lock` first: Flutter
   then sees an up-to-date resolution and skips its own pub step.
4. Copies the three per-ABI APKs to
   `build/reproducible/<ref>/signet-<version>-<abi>-unsigned.apk` and
   writes `SHA256SUMS` and `build-info.txt` (commit, epoch, image id).

The build runs as your uid with `SIGNET_UNSIGNED_RELEASE=1`, which
`android/app/build.gradle.kts` reads to leave the release APK
**unsigned** (no throwaway debug key, so the bytes depend on the source
only). Version name and code are the real ones from `pubspec.yaml`,
and `--split-per-abi` gives F-Droid's versionCodes (pubspec code times
10, plus 1 for armeabi-v7a, 2 for arm64-v8a, 3 for x86_64).

By default the cache is fresh for every run and deleted afterwards.
`SIGNET_REPRO_CACHE=<dir>` reuses one across runs, which is faster but
a weaker check. The fresh cache and both clones are staged under
`build/reproducible/.stage/`, on disk rather than in `/tmp` (often a
RAM-backed tmpfs), because together they take several GB.

## Running the build

```sh
# One-time: build the image.
docker build -t signet/repro:latest - < Dockerfile.reproducible

# Each release: build from a tag.
scripts/reproducible-build.sh v0.3.7
cat build/reproducible/v0.3.7/SHA256SUMS
```

## Verifying reproducibility

Run the build twice (ideally on two machines, with the same image) and
compare `SHA256SUMS`. They must match. If they don't, `diffoscope` on
the two APKs locates the non-deterministic content. Likely culprits:

- **ZIP entry order or timestamps.** AGP normalises entry times, but a
  plugin's own packaging step may not.
- **Native libraries.** The zxing and jni CMake builds embed paths and
  build ids; the fixed `/build` path should keep them stable.
- **Dex ordering.** R8 output should be deterministic for identical
  inputs; worth confirming on the first mismatch.

## Comparing with a published release

Release APKs on GitHub are signed; ours are not. APK Signature Scheme
v2 stores the signature in a block inside the zip, so removing it is
not a matter of deleting files. To compare, either:

- use F-Droid's tooling (`fdroid` compares an unsigned rebuild against
  a signed APK by copying the signature over and verifying it), or
- unzip both APKs and compare every entry except `META-INF/*.SF`,
  `*.RSA`, `*.EC` and `MANIFEST.MF`.

A scripted version of this comparison is still to do.

## Known gaps

1. **No CI job runs this.** A future workflow should run two builds on
   separate runners and diff them on every main push.
2. **Toolchain downloads come from vendor CDNs** (Google, GitHub,
   Maven Central). A stricter posture would mirror them somewhere
   immutable.
3. **iOS is not reproducible.** iOS builds go through Apple's
   closed-source signing on macOS. Accepted; F-Droid does not
   distribute iOS builds.
4. **The image itself is not reproducible** (unpinned Ubuntu
   packages). The pinned toolchain inside it is what reaches the APK.

## Changelog

- 2026-04-19: initial scaffold (Phase 12.15). Never verified.
- 2026-10-10: repaired (v0.3.7, Task 7.3). Temurin 25 base pinned by
  digest, current SDK components, Flutter commit checked, two-pass
  build with an offline second pass, unsigned output, real version and
  per-ABI versionCodes. Two clean runs matched byte for byte on one
  machine.
