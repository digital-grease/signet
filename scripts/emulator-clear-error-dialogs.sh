#!/usr/bin/env bash
# Make sure no system error dialog holds window focus on the CI emulator.
#
# A cold-booted google_apis emulator can ANR the launcher during boot
# ("Input dispatching timed out"), and the "isn't responding" dialog then
# keeps window focus for the whole run. The app under test still draws and
# takes taps, but Android 10+ denies clipboard access to an app without
# focus, so the secure_clipboard tests fail with a misleading `plain`
# result (seen on API 34: "Denying clipboard access ... application is not
# in focus").
#
# Stops new error dialogs, dismisses any already showing, and fails if one
# still has focus afterwards.
#
# Usage: scripts/emulator-clear-error-dialogs.sh   (adb on PATH, one device)
set -euo pipefail

# `dumpsys window displays`, not plain `dumpsys window`: the full dump
# starts with a saved copy of the state at the last ANR, whose stale
# mCurrentFocus would be read first.
focused() {
  adb shell dumpsys window displays | grep -m1 -E 'mCurrentFocus=' || true
}

adb shell settings put global hide_error_dialogs 1

for _ in 1 2 3 4 5; do
  focus=$(focused)
  if ! printf '%s' "$focus" | grep -q -E 'Application (Not Responding|Error)'; then
    echo "Focus: ${focus:-none reported}"
    exit 0
  fi
  echo "Dismissing: $focus"
  adb shell am broadcast -a android.intent.action.CLOSE_SYSTEM_DIALOGS >/dev/null
  adb shell input keyevent KEYCODE_BACK
  sleep 2
done

echo "::error::A system error dialog still has window focus: $(focused)" >&2
exit 1
