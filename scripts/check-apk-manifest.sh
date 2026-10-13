#!/usr/bin/env bash
# Assert privacy-critical properties of a built APK.
#
#   - android:allowBackup and android:fullBackupContent are false on
#     <application>, and android:dataExtractionRules points at a rules file
#     that excludes every backup domain from both cloud backup and
#     device-to-device transfer, with no <include>. No app data (secrets,
#     crash or debug files) may reach Google cloud backup or a D2D copy
#     (PRIVACY.md: no cloud, ever).
#   - android.permission.INTERNET is never requested (offline by
#     construction), and every requested permission is on an allowlist:
#     CAMERA, plus androidx's own DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION.
#     A library that merges in anything else (audio, storage, network
#     state) fails the check until it is removed in AndroidManifest.xml.
#   - No <uses-feature> is required: Signet must install on devices
#     without a camera (long-distance pairing and restore need none).
#
# Usage: scripts/check-apk-manifest.sh path/to/app.apk
# Needs aapt2 from the Android SDK build-tools ($ANDROID_HOME or
# $ANDROID_SDK_ROOT). Run it on release APKs: debug builds add INTERNET for
# the Flutter tool and are expected to fail.
set -euo pipefail

apk="${1:?usage: $0 path/to/app.apk}"
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
aapt2=$(ls -d "$sdk"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1 || true)
if [ -z "$aapt2" ]; then
  echo "::error::aapt2 not found under \$ANDROID_HOME/build-tools/" >&2
  exit 1
fi

fail=0
err() {
  echo "::error::$1 ($apk)" >&2
  fail=1
}

manifest=$("$aapt2" dump xmltree --file AndroidManifest.xml "$apk")
# Attributes of the <application> element only: from its E: line up to the
# first child element.
application=$(awk '
  /^ *E: application / { inapp = 1; next }
  inapp && /^ *E: / { exit }
  inapp { print }
' <<<"$manifest")

grep -qE 'android:allowBackup\([^)]*\)=false' <<<"$application" ||
  err "android:allowBackup is not false on <application>"
grep -qE 'android:fullBackupContent\([^)]*\)=false' <<<"$application" ||
  err "android:fullBackupContent is not false on <application>"
grep -qE 'android:dataExtractionRules\(' <<<"$application" ||
  err "android:dataExtractionRules is missing on <application>"
if grep -q 'android.permission.INTERNET' <<<"$manifest"; then
  err "android.permission.INTERNET is requested"
fi

# Permission allowlist (plan Task 7.1). aapt2 runs in a plain command
# substitution so a failure aborts (set -e) instead of yielding an empty,
# passing list; CAMERA must be found, so a parse that matches nothing fails.
package=$("$aapt2" dump packagename "$apk")
allowed="android.permission.CAMERA ${package}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"
permissions=$("$aapt2" dump permissions "$apk")
requested=$(sed -nE "s/^uses-permission(-sdk-23)?: name='([^']+)'.*/\2/p" <<<"$permissions")
grep -qx 'android.permission.CAMERA' <<<"$requested" ||
  err "android.permission.CAMERA not found (aapt2 output not parsed?)"
while read -r perm; do
  [ -n "$perm" ] || continue
  case " $allowed " in
    *" $perm "*) ;;
    *) err "permission not on the allowlist: $perm" ;;
  esac
done <<<"$requested"

# No required feature. badging resolves the manifest rules for us:
# optional features print as `uses-feature-not-required`, a feature with
# no android:required (default true) or required="true" as `uses-feature`,
# a glEsVersion requirement as `uses-gl-es`, and features a permission
# implies (when not declared optional) as `uses-implied-feature`. Every
# app gets an implied android.hardware.faketouch, which is allowed.
badging=$("$aapt2" dump badging "$apk")
grep -q "uses-feature-not-required: name='android.hardware.camera'" <<<"$badging" ||
  err "android.hardware.camera not declared optional (aapt2 output not parsed?)"
while read -r line; do
  [ -n "$line" ] || continue
  case "$line" in
    *"name='android.hardware.faketouch'"*) ;;
    *) err "a feature is required: $line" ;;
  esac
done < <(grep -E "^ *(uses-feature|uses-implied-feature|uses-gl-es):" <<<"$badging" | sed 's/^ *//' || true)

# Resolve the (possibly obfuscated) path of the rules XML and check it.
rules_path=$("$aapt2" dump resources "$apk" |
  awk '/ xml\/data_extraction_rules$/ { found = 1; next }
       found && /\(file\)/ { print $3; exit }' || true)
if [ -z "$rules_path" ]; then
  err "xml/data_extraction_rules resource not found"
else
  rules=$("$aapt2" dump xmltree --file "$rules_path" "$apk")
  if grep -q 'E: include' <<<"$rules"; then
    err "data_extraction_rules contains an <include>"
  fi
  domains="root file database sharedpref external device_root device_file device_database device_sharedpref"
  for section in cloud-backup device-transfer; do
    block=$(awk -v s="E: $section " '
      index($0, s) { insec = 1; depth = match($0, /E:/); next }
      insec && /E: / && match($0, /E:/) <= depth { exit }
      insec { print }
    ' <<<"$rules")
    [ -n "$block" ] || { err "data_extraction_rules has no <$section>"; continue; }
    for d in $domains; do
      grep -A1 "domain=\"$d\"" <<<"$block" | grep -q 'path="\."' ||
        err "<$section> does not exclude domain \"$d\" with path=\".\""
    done
  done
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "Manifest OK: backup off (allowBackup, fullBackupContent, all domains excluded from cloud + D2D), no INTERNET, permissions on the allowlist, no required features ($apk)"
