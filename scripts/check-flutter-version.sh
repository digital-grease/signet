#!/usr/bin/env bash
# Fail if the workflows disagree on the pinned Flutter version.
#
# The source of truth is the `flutter-version: 'X.Y.Z'` literal in
# .github/workflows/release.yml, read with the exact sed F-Droid's prebuild
# uses (metadata/dev.digitalgrease.signet.yml); it must yield one line.
# Every workflow's `FLUTTER_VERSION:` env value and every quoted
# `flutter-version:` literal must equal it. Renovate does not manage these,
# so a manual bump that misses one fails here instead of drifting.
#
# Usage: scripts/check-flutter-version.sh   (from the repo root)
set -euo pipefail

workflows=.github/workflows
pinned=$(sed -n -E "s/.*flutter-version:\ '(.*)'/\1/p" "$workflows/release.yml")
if [ "$(printf '%s\n' "$pinned" | grep -c .)" -ne 1 ]; then
  echo "::error::F-Droid's sed must yield exactly one Flutter version from release.yml, got: ${pinned:-nothing}" >&2
  exit 1
fi

fail=0
while IFS=: read -r file line value; do
  if [ "$value" != "$pinned" ]; then
    echo "::error file=$file,line=$line::Flutter $value, expected $pinned (release.yml)" >&2
    fail=1
  fi
done < <(
  grep -n -H -E "^\s*FLUTTER_VERSION:\s*\S+" "$workflows"/*.yml |
    sed -E "s/^([^:]+):([0-9]+):\s*FLUTTER_VERSION:\s*'?([^' ]+)'?.*/\1:\2:\3/"
  grep -n -H -E "flutter-version:\s*'[^']+'" "$workflows"/*.yml |
    sed -E "s/^([^:]+):([0-9]+):.*flutter-version:\s*'([^']+)'.*/\1:\2:\3/"
)

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "Flutter version consistent across workflows: $pinned"
