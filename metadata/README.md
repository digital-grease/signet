# F-Droid metadata

Canonical source for the Signet F-Droid listing. This directory
mirrors what a PR against
[`fdroiddata`](https://gitlab.com/fdroid/fdroiddata) would contain
under `metadata/dev.digitalgrease.signet.yml` + `metadata/dev.digitalgrease.signet/...`.

Maintaining the files here (rather than only in an fdroiddata fork)
means the listing content + the build recipe live next to the source
they describe, and PR updates against fdroiddata are mechanical
copy-pastes.

## Directory layout (mirrors F-Droid's required structure)

```
metadata/
├── README.md                         this file
├── dev.digitalgrease.signet.yml                build recipe + listing metadata
└── dev.digitalgrease.signet/
    └── en-US/
        ├── short_description.txt     80 chars max
        ├── full_description.txt      4000 chars max
        ├── changelogs/
        │   └── 20000.txt             one file per versionCode
        └── images/
            ├── icon.png              TBD when real icon lands
            ├── featureGraphic.png    TBD
            └── phoneScreenshots/     TBD — shot list in distribution/play-store/screenshots/README.md
```

## How to submit to F-Droid

Prerequisites: you've pushed a `v0.2.0` git tag, the GitHub Actions
`release.yml` has produced a signed APK, and you've verified its
SHA-256 fingerprint matches what you pasted into
`AllowedAPKSigningKeys` in `dev.digitalgrease.signet.yml`.

1. Fork https://gitlab.com/fdroid/fdroiddata.
2. Copy `metadata/dev.digitalgrease.signet.yml` to `metadata/dev.digitalgrease.signet.yml`
   in your fork.
3. Copy `metadata/dev.digitalgrease.signet/` to `metadata/dev.digitalgrease.signet/` in
   your fork.
4. (Optional — lands when available) Copy icon + feature graphic +
   phoneScreenshots PNGs into the corresponding `images/` path.
5. Test the build locally if you have F-Droid's build toolchain:
   ```sh
   fdroid build --stop --verbose dev.digitalgrease.signet
   ```
   If this succeeds, the F-Droid buildserver will most likely also
   succeed. If it fails, inspect the error; usually it's a mismatch
   between `srclibs` Flutter version and what we pinned in
   `Dockerfile.reproducible`.
6. Open a merge request against fdroiddata. The F-Droid team's CI
   runs a linter and a build probe; iterate on review feedback.

## Image assets TBD

Icon + feature graphic + screenshots are TBD until:

1. The real Signet icon design lands — currently placeholder; see
   `docs/ICONS_AND_LAUNCH.md`.
2. A visual design pass on the theme completes — user indicated
   the current theme needs iteration.

Once both land, capture screenshots from an emulator / device via
the matrix in `distribution/play-store/screenshots/README.md` and
copy the PNGs into `metadata/dev.digitalgrease.signet/en-US/images/`.

## Differences from the Play Store listing

F-Droid and Play Store listings are maintained separately and
follow different conventions:

- **Shorter descriptions** on F-Droid — `full_description.txt` here
  is trimmed from `distribution/play-store/long-description.txt`.
- **No data-safety form** — F-Droid infers from source code + the
  `AntiFeatures` field.
- **No content rating** — F-Droid doesn't have one.
- **Reproducibility enforced** — F-Droid's buildserver rebuilds and
  compares. See `docs/REPRODUCIBLE_BUILD.md`.

When either listing is updated (new version, copy tweak, new
screenshot), update BOTH directories to keep them in sync.
