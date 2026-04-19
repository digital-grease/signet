# Reproducible build

Signet aims for bit-identical APK builds from any clean checkout of a
given git tag. This matters for three reasons:

1. **F-Droid submission** — F-Droid's build server independently
   rebuilds every app on every release. Non-reproducible builds
   cannot be submitted.
2. **Independent audit credibility** — a third-party reviewer should
   be able to compile the codebase and compare their APK's SHA-256
   to ours. Equal hashes mean they're looking at the same bits we
   shipped; divergence is a red flag.
3. **Supply-chain trust** — if an attacker tampered with our
   toolchain but not the committed source, a reproducible build
   performed on a clean machine would produce a different hash than
   our release artifact. Detection without trusting us.

**Current status** (end of Phase 12.15): infrastructure in place;
bit-identical output **not yet verified end-to-end**. The Dockerfile
pins every known-non-deterministic source; the outstanding risk
areas are Gradle metadata + dex ordering, which will surface the
first time two independent machines produce the image and compare.

## Moving parts

### `Dockerfile.reproducible`

Debian-pinned base image. Explicitly pinned:

- Debian release (`bookworm-20240926-slim`)
- Flutter version + the exact git commit (not just the channel tag —
  tags move)
- Android command-line-tools archive version
- Android platform SDK
- Android build-tools
- Android NDK
- `LANG` / `LC_ALL` / `TZ` (C + UTF-8 + UTC)

Using Debian's snapshot archive (`snapshot.debian.org`) is a
further-hardening option not yet taken; current pin is the stable
release tag, which is stable "enough" for the audit horizon but is
not a commitment the way a snapshot-date would be.

### `scripts/reproducible-build.sh`

Bash driver. Given a git ref:

1. Resolves ref → commit sha.
2. Derives `SOURCE_DATE_EPOCH` from the commit's committer timestamp.
3. Creates a fresh `git worktree` at the commit (isolates from any
   local dirty state).
4. Runs the Dockerfile's image with:
   - `--network=none` — the build must be reproducible offline; if a
     step reaches out to the network, it's a bug.
   - `SOURCE_DATE_EPOCH` bound to commit time.
   - Locale / TZ forced.
   - Version + build number hard-pinned to `0.0.0+0` (regardless of
     `pubspec.yaml`'s values, so the version field itself doesn't
     drift the output).
   - `--dart-define=SIGNET_REPRODUCIBLE=1` flag (currently unused by
     app code; reserved for any future reproducible-only conditionals).
5. Copies the resulting APK out to
   `build/reproducible/<ref>/app-release-unsigned.apk`.
6. Computes + writes a matching SHA-256 checksum file.

The output is **unsigned**. Production signing is a separate step
(see `docs/RELEASE.md` — coming in Phase 12.16).

## Running the build

```sh
# One-time: build the image.
docker build -f Dockerfile.reproducible -t signet/repro:latest .

# Each release: build from a tag.
./scripts/reproducible-build.sh v0.2.0
```

## Verifying reproducibility

The test case for "is this reproducible": two independent machines,
same ref, same image tag, compare SHA-256s.

```sh
# Machine A:
./scripts/reproducible-build.sh v0.2.0
cat build/reproducible/v0.2.0/app-release-unsigned.apk.sha256

# Machine B, different hardware / OS / time of day:
./scripts/reproducible-build.sh v0.2.0
cat build/reproducible/v0.2.0/app-release-unsigned.apk.sha256

# The two SHA-256s MUST match.
```

If they don't, the delta is a reproducibility bug — `diffoscope` on
the two APKs will locate the non-deterministic content. Known likely
culprits in the current state:

- **Dex merge order** — R8 can sort classes non-deterministically
  without the right flags. Gradle option `android.enableD8=true` +
  R8 with deterministic ordering flags will need verification.
- **ZIP entry timestamps** — addressed via `SOURCE_DATE_EPOCH` but
  not every zipping step respects it. `strip-nondeterminism` (the
  same utility F-Droid uses) is the fallback fix.
- **Asset hashing** — Flutter's asset manifest includes content
  hashes; should be deterministic given deterministic inputs but
  worth confirming.

## Known gaps (still TODO)

1. **No CI job runs this** — a future workflow
   `.github/workflows/reproducibility-check.yml` should do a
   two-runner diff to smoke-test reproducibility on every main push.
2. **No independent-mirror archive for the toolchain downloads** —
   the Dockerfile fetches Flutter + Android tools from their vendors'
   CDNs. A stricter posture would mirror these into a known-
   immutable location.
3. **iOS is not reproducible** — iOS builds involve Apple's
   closed-source codesign infrastructure on macOS. Nothing we can
   do there from a Linux repro image. Noted and accepted; F-Droid
   does not distribute iOS builds anyway.
4. **The image itself is not reproducible** — `docker build -f
   Dockerfile.reproducible` on two machines will produce slightly
   different image hashes due to apt repository mirror timing. We
   address this by distributing the **built image** alongside
   releases rather than asking every rebuilder to build the image
   from scratch. A future v1.0 improvement: use `nix` or a
   Debian snapshot-archive date.

## Verifying a release APK

For a reviewer who has a signed release APK from GitHub Releases
and wants to confirm it matches the source at the tagged commit:

```sh
# 1. Build the unsigned APK reproducibly.
./scripts/reproducible-build.sh v0.2.0

# 2. Strip the signature from the signed APK you downloaded.
#    The tool-of-choice is apksigner; on Debian:
#      apt install apksigner
#    The unsigned APK should be byte-identical to our output.
apksigner extract --in signet-v0.2.0.apk --unsigned-out signet-v0.2.0.unsigned.apk

# 3. Compare.
sha256sum signet-v0.2.0.unsigned.apk
sha256sum build/reproducible/v0.2.0/app-release-unsigned.apk
```

(`apksigner extract` isn't a real subcommand; the actual recipe is
more involved — you'd unzip the APK, remove `META-INF/*.RSA` /
`*.SF` / `MANIFEST.MF`, re-zip with `jar`/`zip` deterministically,
and compare. That pipeline belongs in a later iteration of this
doc. The intent is to sketch where the verification path lives.)

## Changelog

- 2026-04-19 · initial scaffold (Phase 12.15). Dockerfile +
  build script + this doc. **Reproducibility not yet empirically
  verified** — that's a Phase 12.15.1 follow-up, ideally on a
  different machine than the one these bits were written on.
