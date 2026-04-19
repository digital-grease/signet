# Screenshot specification

Play Store accepts **2 to 8 screenshots per size class**. Signet's
preferred set below; generate at Play's recommended resolutions
whenever the real theme + icon land.

## Resolutions

- **Phone** (required): 1080 × 1920 (9:16 portrait), or 1920 × 1080
  (16:9 landscape) if you want landscape for the CR-grid shot.
- **7-inch tablet** (optional): 1200 × 1920 or 1920 × 1200.
- **10-inch tablet** (optional): 1600 × 2560 or 2560 × 1600.

## Preferred shot list (phone, portrait)

1. **Home (paired list)** — two or three relationship rows, PAIR
   FAB visible, OFFLINE-FREE chip top-right. Shows the app's
   resting state. Suggested mock data: "Mom", "Jake (brother)", "Sarah (work)".

2. **Verify (✅)** — the VERIFIED banner, the four typed words filled
   into the slots, FLAG_SECURE amber badge visible, AIRPLANE ribbon
   at the bottom. The hero image for the whole product.

3. **Verify (❌ with "WHAT SHOULD I DO?")** — the NOT-VERIFIED
   banner expanded with the bottom-sheet guidance visible ("Hang
   up. Call them back..."). The honest-about-failure shot.

4. **Pair QR exchange** — one side showing the QR, the other
   phone-in-frame holding the camera up. Captures the in-person
   pairing moment.

5. **Long-distance transport-out** — the share-and-wait pane with
   the encrypted package text visible + PAKE words numbered +
   amber warning about channel hygiene. Captures the journalist /
   activist use case.

6. **Backup export** — the QR + PAKE card. Shows recovery awareness
   + the treat-like-a-safe-combo warning.

7. **Challenge-response grid** — the on-device 8×8 grid viewer +
   the tap-to-highlight dialog open, showing a cell's 3-word answer
   in big mono. Captures the paper-fallback mode.

8. **Liveness challenge** — the large prompt ("Touch your left ear
   and say 'orbit'") with the countdown visible + the pass/fail
   buttons. Captures the video-call-puppet defense.

## Feature graphic (1024 × 500)

Single panel. Left third: stylized Signet wordmark. Right two-thirds:
abstract render of two phones face-to-face with a QR between them
or a verify banner. The feature graphic is the first thing seen on
the app's Play listing; it needs to read "security tool, not
consumer app" at a glance.

## Per-locale

English-only at v0.2 alpha. Add locales when translations exist.

## Not yet produced

Actual screenshot PNGs live under this directory (phone/, 7in/,
10in/). They are **not yet captured** — waiting for:

1. The real app icon (`docs/ICONS_AND_LAUNCH.md`).
2. A completed UI design pass (user indicated the current theme
   needs iteration in session).
3. A physical emulator or device run.

Shot capture is owner-action; `flutter screenshot` + manual framing
in `screenshot_frame` tooling is the usual path.
