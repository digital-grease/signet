# App icons + launch screens

**Status at end of Phase 12.10**: placeholder icons (default Flutter
blue "F") are still in place. Launch screens are default Flutter
single-color storyboards.

The icon set exists at the right sizes in the right locations; what's
missing is a real Signet design. This file documents the regeneration
flow so swapping in the real icon is a one-command operation whenever
the design lands.

## Current state

### iOS

- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` — 16 PNG files at
  the sizes iOS expects (20×20 @1x/2x/3x, 29×29 @1x/2x/3x, 40×40
  @1x/2x/3x, 60×60 @2x/3x, 76×76 @1x/2x, 83.5×83.5 @2x, 1024×1024 @1x).
  Contents are the default Flutter placeholder.
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/` — 3 PNGs (@1x,
  @2x, @3x). Default Flutter placeholder.
- `ios/Runner/Base.lproj/LaunchScreen.storyboard` — storyboard that
  references the LaunchImage asset. Unchanged from scaffolding.

### Android

- `android/app/src/main/res/mipmap-*/ic_launcher.png` — default green
  Android robot at 5 densities. Unchanged from scaffolding.
- `android/app/src/main/res/drawable/launch_background.xml` — default
  splash background. Unchanged.

## Regeneration flow (when a real icon lands)

Recommended tooling: the [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons)
package. One source PNG (ideally 1024×1024 transparent-background for
iOS; Android adaptive icons prefer a layered SVG or foreground +
background PNG pair), one command, all asset sizes generated.

### One-time setup

Add to `pubspec.yaml` under `dev_dependencies`:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.4  # or latest
```

Add the icon config (either inline in pubspec or as
`flutter_launcher_icons.yaml`):

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/signet-source-1024.png"
  # Adaptive icon for Android 8+:
  adaptive_icon_background: "#0A0C10"  # matches the Signet operator theme dark surface
  adaptive_icon_foreground: "assets/icon/signet-source-foreground.png"
  # Remove alpha channel for the iOS App Store — Apple rejects icons with transparency.
  remove_alpha_ios: true
```

Place your source PNG(s) at the paths above.

### Regenerate

```sh
flutter pub get
dart run flutter_launcher_icons
```

That rewrites every PNG under `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
and `android/app/src/main/res/mipmap-*/` with the correctly-sized
rendering of your source image.

### Launch screen (splash)

For a matching splash, use
[`flutter_native_splash`](https://pub.dev/packages/flutter_native_splash):

```yaml
dev_dependencies:
  flutter_native_splash: ^2.4.7

flutter_native_splash:
  color: "#0A0C10"  # match operator-theme dark surface
  image: "assets/icon/signet-source-foreground.png"
  android_12:
    image: "assets/icon/signet-source-foreground.png"
    color: "#0A0C10"
```

Then:

```sh
dart run flutter_native_splash:create
```

This rewrites the iOS LaunchScreen storyboard + asset set and the
Android drawable + values-night resources in one pass.

## Design constraints for the real icon

When the Signet icon is designed, keep these in mind:

- **No transparency for iOS** — Apple rejects App Store submissions
  with alpha channels on the App Store icon. The 1024×1024 source
  must be fully opaque; round corners are applied by the system,
  not by the source.
- **Android adaptive icons** — the background and foreground layers
  are separate assets. The background is clipped to any shape the
  launcher chooses (circle, square, squircle); keep critical visual
  content inside the central 66% of the foreground.
- **Operator theme palette** — the app's in-UI accent is the mint
  `#14B886`. If the icon uses the same, the app launcher and splash
  will read cohesive. But don't overcommit: the icon is the one
  place where "this looks like a security tool, not a friendly
  consumer app" lands at first glance, so staying close to
  charcoal + mint is probably the right call.
- **Legibility at 20×20** — at the smallest size (iPhone notification
  tray), any letter/wordmark will be illegible. Plan for a symbol.

## Why this is still a placeholder in v0.2

Designing a real icon is a user-judgement task and wasn't in the
Phase 12 engineering scope. The app as-shipped with default
placeholders compiles, runs, and passes CI — it's just recognizably
not-yet-branded. Pre-App-Store-submission, this file gets revisited
and the above regen flow produces the final asset sets.

**This file is a release-gate item**: do not submit Signet to any app
store with the default Flutter icons in place. Reviewers will either
reject the submission outright or (worse) approve it and then the
icon will be the first trust signal a user sees — they'll see a
generic Flutter "F" and assume Signet is an unfinished toy.
