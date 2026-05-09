# F-Droid metadata

Two pieces live here, serving two different roles:

```
metadata/
├── README.md                         this file
└── dev.digitalgrease.signet.yml      build recipe (mirror of fdroiddata MR)
```

The localized listing content (description, screenshots, changelogs)
moved to `fastlane/metadata/android/en-US/` in v0.3.1. F-Droid
auto-imports from that path on every release tag — no further manual
syncing required.

## What goes where

### `metadata/dev.digitalgrease.signet.yml`

The build recipe + listing-level metadata (Categories, License,
SourceCode URL, AllowedAPKSigningKeys, Builds[], AutoUpdateMode, ...)
that ends up at `metadata/dev.digitalgrease.signet.yml` inside the
fdroiddata repo. We keep it here as a canonical reference so the
fdroiddata MR is a mechanical copy-paste.

### `fastlane/metadata/android/en-US/`

Fastlane-format localized listing — `title.txt`, `short_description.txt`,
`full_description.txt`, `changelogs/<versionCode>.txt`, and
`images/{icon,featureGraphic}.png` + `images/phoneScreenshots/*.png`.

F-Droid's `fdroid update` job auto-detects this path on each release
tag and pulls the contents into the F-Droid client metadata. **Do not
duplicate this content into fdroiddata** — that path is for apps
without upstream Fastlane metadata; we have it.

Note: F-Droid's auto-import re-maps Fastlane filenames to its own
internal layout: `full_description.txt` → `description.txt`,
`short_description.txt` → `summary.txt`. That's an F-Droid-side
concern; we just maintain the Fastlane-canonical names here.

## How to submit (or update) the F-Droid listing

Prerequisites: a `vX.Y.Z` git tag exists, the GitHub Actions
`release.yml` has produced a signed APK, and you've verified its
SHA-256 fingerprint matches what's pasted into `AllowedAPKSigningKeys`
in `dev.digitalgrease.signet.yml`.

### First-time inclusion (one-time)

1. Fork https://gitlab.com/fdroid/fdroiddata.
2. Branch off `upstream/master`.
3. Copy `metadata/dev.digitalgrease.signet.yml` to
   `metadata/dev.digitalgrease.signet.yml` in your fork.
4. (Optional smoke) Run `fdroid lint dev.digitalgrease.signet`
   and `fdroid build dev.digitalgrease.signet:<versionCode>`
   locally if you have the toolchain.
5. Push and open an MR.
6. After review, merge.

### Subsequent releases

Once your app is in fdroiddata with `AutoUpdateMode: Version` and
`UpdateCheckMode: Tags`, **no further fdroiddata MRs are needed for
content updates**. F-Droid's daily `checkupdates` job:

1. Detects new tags on `digital-grease/signet`.
2. Reads `pubspec.yaml` at the tag, extracts versionName + versionCode
   via `UpdateCheckData`.
3. Auto-creates a new Builds[] entry on `fdroiddata/master`.
4. Auto-imports `fastlane/metadata/android/en-US/` for the listing.

## Differences from the Play Store listing

F-Droid and Play Store listings are maintained separately:

- **Play Store copy** lives in `distribution/play-store/`.
- **F-Droid copy** lives in `fastlane/metadata/android/en-US/`.
- They MAY differ — for example, F-Droid copy avoids "deepfake-resistant"
  marketing language until store-listing review clears (Phase 3.4 gate).
- F-Droid does not use the Play data-safety form or content rating;
  F-Droid infers from source + the `AntiFeatures:` field in the YAML.
