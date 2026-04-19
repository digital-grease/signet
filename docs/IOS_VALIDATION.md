# iOS manual validation

Owner-action checklist for verifying Signet on an iOS simulator or
physical device. Runs against whatever ref is in your working tree.
Gates the first iOS release.

Nothing in CI can catch UX regressions or plugin-specific iOS
behaviors (camera permission prompts on first denial, Keychain item
persistence across cold starts, blur-overlay timing during app-switcher
snapshots). That's what this checklist is for.

## Preconditions

- macOS host with Xcode (latest stable) installed.
- Flutter `3.41.6` stable — matches `env.FLUTTER_VERSION` in the CI
  workflows.
- An iOS 15+ simulator booted, or a physical device registered with
  your Apple Developer account (free-tier dev cert is fine for
  simulator runs; paid membership needed for device install).
- `cd` into the repo root.

## Phase 0 — compile + boot

```sh
flutter pub get
cd ios && pod install && cd ..
flutter run -d <simulator-or-device-id>
```

✅ App launches past the splash screen and lands on the onboarding flow
(first-run) or the home screen (subsequent runs).

❌ If the build fails at `pod install`, try `cd ios && pod repo update
&& pod install`. If it fails at the Xcode build step, open the
`Runner.xcworkspace` in Xcode and resolve the surfaced issue before
retrying.

## Phase 1 — onboarding + home

- [ ] First-run onboarding renders: three slides, `CONTINUE` cycles
      through, `SKIP` / `DONE` exits to home.
- [ ] Home empty state renders the bordered QR icon + "Nothing paired
      yet." + `PAIR CONTACT` / `SEND A PACKAGE` / `I HAVE A PACKAGE`
      / `RESTORE FROM BACKUP` buttons.
- [ ] AppBar title reads `SIGNET` in the operator letter-spaced style.
- [ ] Overflow menu → "Show intro again" routes back to onboarding.

## Phase 2 — camera permission

- [ ] Tap `PAIR CONTACT` → label screen → exchange screen → `Scan
      their QR`.
- [ ] iOS prompts for Camera permission. Prompt text matches
      `NSCameraUsageDescription` from `Info.plist`: "Signet needs the
      camera only to scan pairing QR codes. Signet does not record
      video or photos, and never sends camera data over the network."
- [ ] Grant → camera viewfinder opens.
- [ ] Repeat with DENY on first prompt → `_PermissionDeniedPane` shows
      up with the iOS-specific settings path: "Settings → Signet →
      Camera".

## Phase 3 — pair + verify (two simulators / two devices)

Easiest with the paste-exchange dev flag — launch both with
`--dart-define=SIGNET_DEBUG_PAIRING=true`. One command per simulator.

- [ ] Start pair flow on device A; paste A's string into B; B pastes
      their string back; both land on `Confirm` with matching 4-word
      phrases.
- [ ] Tap `It matches` on both; both commit to storage.
- [ ] Both route to `/pair/complete/:id` post-commit.
- [ ] Navigate to Verify on one device; type the other device's 4
      current rotating words → `VERIFIED` banner.

## Phase 4 — SecureScreen blur overlay (iOS-specific)

This is the Swift-side work from Phase 12.8. Test flow:

- [ ] On the Verify screen, press the iOS home-bar or task-switcher
      gesture.
- [ ] App-switcher preview shows a **blurred** view (not the
      actual Verify UI with the words visible).
- [ ] Return to the app → overlay clears; Verify UI restored
      unchanged.
- [ ] Repeat on the Show-binding-phrase screen, the CR-grid viewer,
      the backup-export screen, and the liveness screen. All
      `SecureScreen`-wrapped screens should produce blurred
      previews.
- [ ] Test screen recording (Control Center → Screen Recording).
      Start a recording while on Verify screen; stop; play back.
      Behavior varies by iOS version — on recent iOS, the recording
      should show the blurred overlay during the Verify-screen
      portion. On older iOS, recording may capture the actual UI
      (iOS's own limitation); acknowledged gap per
      `docs/IOS_STORAGE_AUDIT.md`.

## Phase 5 — Keychain sentinel scan

Per `docs/IOS_STORAGE_AUDIT.md`:

```sh
flutter run -t lib/dev/secure_store_harness_main.dart -d <simulator-id>
# Wait for "SENTINEL WRITTEN AND ROUND-TRIPPED" in the app.

# In a second terminal:
simctl_path=$(xcrun simctl get_app_container booted dev.digitalgrease.signet data)
grep -r "SIGNET_SENTINEL_LABEL_PLAINTEXT" "$simctl_path" && echo "FAIL: label leaked"
grep -r "SIGNET_SHARED_SECRET_SENTINEL_32" "$simctl_path" && echo "FAIL: secret leaked"
grep -r "U0lHTkVUX1NIQVJFRF9TRUNSRVRfU0VOVElORUxfMzI=" "$simctl_path" && echo "FAIL: base64 secret leaked"
grep -r "deadbeefcafefeed" "$simctl_path" && echo "FAIL: id leaked"
```

- [ ] All four greps return no matches.

## Phase 6 — rotation / retention behaviors

- [ ] Close the app fully (swipe up from app-switcher), reopen.
      Relationship persists. Verify still works.
- [ ] Reboot the simulator. Relationship persists post-reboot.
- [ ] Delete the app. Verify on reinstall the relationship does NOT
      come back (sandbox-scoped Keychain; no iCloud sync in the
      default plugin configuration — see `docs/IOS_STORAGE_AUDIT.md`
      for the open question around `*ThisDeviceOnly` accessibility).

## Phase 7 — share-sheet + file-picker smoke tests

Backup export flow:

- [ ] Home → peer long-press → Back up to paper → backup screen
      renders QR + PAKE words + share buttons.
- [ ] `Copy package` → paste into Notes app → the wire text pastes
      cleanly.
- [ ] `Share package` → iOS share sheet opens → save to Files app;
      confirm the file is created and contains both the wire line
      and the 8 PAKE words on separate lines.

Backup import flow:

- [ ] Home → `Restore from backup` → import screen.
- [ ] `Load from file` → Files-app picker opens → select the file
      saved above → wire + PAKE fields populate.
- [ ] `UNLOCK BACKUP` → preview pane → `COMMIT IMPORT` → relationship
      lands on Home.

## Phase 8 — printing

CR grid print flow:

- [ ] Home → peer long-press → Challenge-response grid → tap the
      printer icon in the AppBar → iOS print preview opens with the
      one-page card laid out correctly (header, axis legends, 8×8
      table, footer).
- [ ] `Save to PDF` from the print dialog → PDF lands in Files app.
- [ ] Open the PDF in Preview on a Mac; confirm the grid's cell
      contents match what the on-device viewer shows for the same
      pair.

## Reporting

After running all phases, write findings into
`docs/IOS_VALIDATION_RUN_<date>.md` as a run log. At minimum:

- Device / simulator model + iOS version.
- Flutter + Dart versions (`flutter --version`).
- Any failed checklist items + reproduction steps.
- Any unexpected behavior not on this checklist.

If all phases pass, the run log is a three-line "all green on <device>
on <date>" and commits alongside the release tag.
