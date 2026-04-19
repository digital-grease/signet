# Play Store listing — Signet

Owner-action: the actual store listing is created in Google Play
Console (developer.play.google.com). This directory scaffolds the
copy, screenshots spec, and questionnaire answers so that the
console-filling step is mechanical rather than creative.

## Files in this directory

- `README.md` — this file.
- `short-description.txt` — 80 chars max, rendered above the
  install button.
- `long-description.txt` — 4000 chars max, the main listing body.
- `whats-new.txt` — per-release changelog snippet; 500 chars max.
- `content-rating.md` — draft answers to Play's content-rating
  questionnaire.
- `data-safety.md` — draft answers to Play's data-safety form.
- `store-listing-meta.yaml` — quick reference for the listing's
  metadata (category, contact info, privacy policy URL, etc.).
- `screenshots/README.md` — screenshot specification (sizes, which
  screens, per-locale variants). Actual PNGs TBD until the
  real app icon lands (`docs/ICONS_AND_LAUNCH.md`).

## Timing

Once an APK from the release workflow is ready AND the real app
icon has been generated:

1. Create the app entry in Play Console (bundle id
   `dev.digitalgrease.signet`, matches `android/app/build.gradle.kts`).
2. Paste `short-description.txt` into "Short description."
3. Paste `long-description.txt` into "Full description."
4. Upload screenshots per `screenshots/README.md`.
5. Fill the content-rating questionnaire with the answers in
   `content-rating.md` (or tweak as needed — they're defaults,
   not oracle).
6. Fill the data-safety form with the answers in `data-safety.md`.
7. Link the privacy policy. Use the repo-root `PRIVACY.md` directly
   via the GitHub blob URL:
   `https://github.com/digital-grease/signet/blob/main/PRIVACY.md`.
   GitHub renders markdown at that URL; no GitHub Pages needed.
   Play + App Store both accept a GitHub blob URL.
8. Upload the signed APK from the GitHub Release produced by
   `release.yml` (see `docs/RELEASE.md`).
9. Submit for review on the **internal testing** track first.
   Invite testers manually. Do NOT push to closed / open / production
   until the internal cohort has walked through `docs/IOS_VALIDATION.md`
   (there's no Android-specific equivalent yet, but the iOS checklist
   translates directly).

## What's NOT in this directory

- The actual signed APK — lives in GitHub Releases.
- The app icon — placeholder at time of writing; see
  `docs/ICONS_AND_LAUNCH.md`.
- Screenshots — need regeneration once the real theme / icon lands.
- Production launch checklist — Play Console walks you through it.
