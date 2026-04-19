#!/usr/bin/env bash
# Signet reproducible-build runner.
#
# Runs a release APK build inside the Dockerfile.reproducible image,
# forcing a deterministic SOURCE_DATE_EPOCH + stable locale + stable
# paths. The output is an unsigned APK; the caller signs it afterwards
# with a production keystore (see docs/RELEASE.md).
#
# Usage:
#   scripts/reproducible-build.sh <git-ref>
#
# Examples:
#   scripts/reproducible-build.sh v0.2.0
#   scripts/reproducible-build.sh HEAD
#
# The image must exist locally; build it once with:
#   docker build -f Dockerfile.reproducible -t signet/repro:latest .
#
# Output goes to ./build/reproducible/<ref>/app-release-unsigned.apk
# plus a SHA-256 checksum file alongside. Two independent runs with
# the same ref should produce byte-identical APKs + matching
# checksums.

set -euo pipefail

REF="${1:-}"
if [ -z "$REF" ]; then
  echo "usage: $0 <git-ref>" >&2
  echo "  example: $0 v0.2.0" >&2
  exit 2
fi

IMAGE="${SIGNET_REPRO_IMAGE:-signet/repro:latest}"
if ! docker image inspect "$IMAGE" > /dev/null 2>&1; then
  echo "error: docker image '$IMAGE' not found." >&2
  echo "  build it with: docker build -f Dockerfile.reproducible -t $IMAGE ." >&2
  exit 3
fi

# Resolve ref → commit sha. Use SHA's committer timestamp as
# SOURCE_DATE_EPOCH so all downstream tools stamp a consistent value.
SHA="$(git rev-parse --verify "${REF}^{commit}")"
EPOCH="$(git show -s --format=%ct "$SHA")"
SHORT="$(git rev-parse --short=12 "$SHA")"

OUT_ROOT="$(pwd)/build/reproducible/${REF//\//_}"
mkdir -p "$OUT_ROOT"

echo "-- Signet reproducible build --"
echo "  ref:     $REF"
echo "  commit:  $SHA"
echo "  epoch:   $EPOCH"
echo "  image:   $IMAGE"
echo "  outdir:  $OUT_ROOT"

# Fresh worktree at the target ref, isolated from local dirty state.
STAGE="$(mktemp -d -t signet-repro.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT

git worktree add --detach "$STAGE" "$SHA"

docker run --rm \
  --network=none \
  -u "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -e SOURCE_DATE_EPOCH="$EPOCH" \
  -e LANG=C.UTF-8 \
  -e LC_ALL=C.UTF-8 \
  -e TZ=UTC \
  -v "$STAGE":/build \
  -w /build \
  "$IMAGE" \
  sh -c '
    set -e
    flutter pub get
    # --no-daemon defeats Gradle state persistence across runs.
    # --release gives us the optimised build path.
    # The build.gradle.kts fallback path signs with the debug key when
    # android/key.properties is absent (which it is inside the
    # container). Production signing is applied outside.
    flutter build apk --release \
      --no-pub \
      --build-name=0.0.0 \
      --build-number=0 \
      --dart-define=SIGNET_REPRODUCIBLE=1
  '

APK_SRC="$STAGE/build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK_SRC" ]; then
  echo "error: build did not produce app-release.apk" >&2
  exit 4
fi

APK_DST="$OUT_ROOT/app-release-unsigned.apk"
cp "$APK_SRC" "$APK_DST"
sha256sum "$APK_DST" | awk -v name="$(basename "$APK_DST")" '{ print $1, " ", name }' \
  > "$APK_DST.sha256"

# Discard the worktree; we already copied the artifact.
git worktree remove --force "$STAGE"

echo
echo "-- Build complete --"
echo "  apk:      $APK_DST"
echo "  sha256:   $(awk '{print $1}' "$APK_DST.sha256")"
echo
echo "To verify reproducibility: rerun this command on another machine"
echo "with the same image tag + same ref, and compare the SHA-256s."
