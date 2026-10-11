#!/usr/bin/env bash
# Signet reproducible-build runner.
#
# Builds unsigned per-ABI release APKs for a git ref inside the
# Dockerfile.reproducible image. Two independent runs (on any machine,
# with the same image) must produce byte-identical APKs.
#
# Usage:
#   scripts/reproducible-build.sh <git-ref>
#
# Examples:
#   scripts/reproducible-build.sh v0.3.7
#   scripts/reproducible-build.sh HEAD
#
# The image must exist locally; build it once with:
#   docker build -t signet/repro:latest - < Dockerfile.reproducible
#
# Two passes, each in a fresh clone of the commit:
#   1. warm:  with network, fetch pub packages, the Gradle distribution
#             and Maven dependencies into a cache directory, by running
#             the same build once.
#   2. build: with --network=none, build again from the warmed cache.
#             Only this pass's APKs are kept. A step that still needs
#             the network fails here, which is the point.
#
# The release build is left unsigned (SIGNET_UNSIGNED_RELEASE=1, read by
# android/app/build.gradle.kts), version name and code come from the
# commit's pubspec.yaml, and --split-per-abi gives the per-ABI
# versionCodes F-Droid uses (pubspec code * 10 + 1/2/3).
#
# Output: build/reproducible/<ref>/signet-<version>-<abi>-unsigned.apk,
# plus SHA256SUMS and build-info.txt.
#
# Environment:
#   SIGNET_REPRO_IMAGE  image tag (default signet/repro:latest)
#   SIGNET_REPRO_CACHE  reuse this cache directory across runs instead
#                       of a fresh one (faster; a fresh cache is the
#                       stricter check)
#   SIGNET_REPRO_MEMORY container memory cap, RAM plus swap (default 10g)

set -euo pipefail

REF="${1:-}"
if [ -z "$REF" ]; then
  echo "usage: $0 <git-ref>" >&2
  echo "  example: $0 v0.3.7" >&2
  exit 2
fi

IMAGE="${SIGNET_REPRO_IMAGE:-signet/repro:latest}"
if ! docker image inspect "$IMAGE" > /dev/null 2>&1; then
  echo "error: docker image '$IMAGE' not found." >&2
  echo "  build it with: docker build -t $IMAGE - < Dockerfile.reproducible" >&2
  exit 3
fi
IMAGE_ID="$(docker image inspect --format '{{.Id}}' "$IMAGE")"

REPO="$(git rev-parse --show-toplevel)"
# Resolve ref to a commit; its committer timestamp becomes
# SOURCE_DATE_EPOCH so every tool that stamps a time uses the same one.
SHA="$(git rev-parse --verify "${REF}^{commit}")"
EPOCH="$(git show -s --format=%ct "$SHA")"
VERSION="$(git show "$SHA:pubspec.yaml" | sed -nE 's/^version:[[:space:]]*([^+[:space:]]+).*/\1/p')"
if [ -z "$VERSION" ]; then
  echo "error: no version in pubspec.yaml at $SHA" >&2
  exit 4
fi

OUT_ROOT="$REPO/build/reproducible/${REF//\//_}"

# Stage on disk under the gitignored build/, not in $TMPDIR: /tmp is
# often a RAM-backed tmpfs, and the Gradle and pub caches plus two
# clones run to several GB. A run killed by SIGKILL skips the trap and
# leaves its stage behind; `flutter clean` removes it with build/.
mkdir -p "$REPO/build/reproducible/.stage"
STAGE="$(mktemp -d -p "$REPO/build/reproducible/.stage" signet-repro.XXXXXX)"
cleanup() {
  # Gradle marks some cache files read-only; make them removable first.
  chmod -R u+w "$STAGE" 2> /dev/null || true
  rm -rf "$STAGE"
}
trap cleanup EXIT

CACHE="${SIGNET_REPRO_CACHE:-$STAGE/cache}"
mkdir -p "$CACHE/pub" "$CACHE/gradle" "$STAGE/home"

# Gradle reads $GRADLE_USER_HOME/gradle.properties before the project's,
# so these heaps replace android/gradle.properties' -Xmx8G (sized for an
# IDE) without touching the source. Heap sizes do not reach the APK.
# Together with the container cap below, a hungry build is killed
# inside Docker instead of pushing the host into its OOM killer.
cat > "$CACHE/gradle/gradle.properties" <<'EOF'
org.gradle.jvmargs=-Xmx3g -XX:MaxMetaspaceSize=1g
kotlin.daemon.jvmargs=-Xmx2g
EOF
MEMORY="${SIGNET_REPRO_MEMORY:-10g}"

echo "-- Signet reproducible build --"
echo "  ref:      $REF"
echo "  commit:   $SHA"
echo "  version:  $VERSION"
echo "  epoch:    $EPOCH"
echo "  image:    $IMAGE ($IMAGE_ID)"
echo "  cache:    $CACHE"
echo "  outdir:   $OUT_ROOT"

# A self-contained clone (its own .git, no pointers back to this
# checkout), so the build sees exactly the commit and nothing local.
fresh_clone() {
  git clone -q --no-checkout "$REPO" "$1"
  git -C "$1" -c advice.detachedHead=false checkout -q --detach "$SHA"
}

# run_pass <name> <network-flag> <src-dir> <script>
run_pass() {
  local name="$1" network="$2" src="$3" script="$4"
  echo
  echo "-- pass: $name --"
  # shellcheck disable=SC2086 # $network is empty or one flag.
  docker run --rm \
    $network \
    --memory "$MEMORY" --memory-swap "$MEMORY" \
    -u "$(id -u):$(id -g)" \
    -e HOME=/home/builder \
    -e PUB_CACHE=/cache/pub \
    -e GRADLE_USER_HOME=/cache/gradle \
    -e GRADLE_OPTS=-Dorg.gradle.daemon=false \
    -e SOURCE_DATE_EPOCH="$EPOCH" \
    -e SIGNET_UNSIGNED_RELEASE=1 \
    -e LANG=C.UTF-8 \
    -e LC_ALL=C.UTF-8 \
    -e TZ=UTC \
    -v "$STAGE/home":/home/builder \
    -v "$CACHE":/cache \
    -v "$src":/build \
    -w /build \
    "$IMAGE" \
    bash -euo pipefail -c "flutter config --no-analytics --no-cli-animations > /dev/null; $script"
}

fresh_clone "$STAGE/warm"
run_pass warm "" "$STAGE/warm" \
  'flutter pub get && flutter build apk --release --split-per-abi'

fresh_clone "$STAGE/src"
# `flutter build` has no --offline, and --no-pub would also skip the
# release-mode plugin regeneration (the dev-only integration_test plugin
# stays registered and javac fails). Instead resolve offline first and
# let the build's own pub step see an up-to-date resolution and skip.
# Flutter's check needs pubspec.yaml older than pubspec.lock, which a
# fresh checkout does not guarantee; mtimes do not reach the APK.
run_pass build --network=none "$STAGE/src" \
  'touch pubspec.lock && flutter pub get --offline && flutter build apk --release --split-per-abi'

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT"
for abi in armeabi-v7a arm64-v8a x86_64; do
  src_apk="$STAGE/src/build/app/outputs/flutter-apk/app-$abi-release.apk"
  if [ ! -f "$src_apk" ]; then
    echo "error: the build did not produce app-$abi-release.apk" >&2
    exit 5
  fi
  cp "$src_apk" "$OUT_ROOT/signet-$VERSION-$abi-unsigned.apk"
done
(cd "$OUT_ROOT" && sha256sum -- *.apk > SHA256SUMS)
{
  echo "ref:     $REF"
  echo "commit:  $SHA"
  echo "version: $VERSION"
  echo "epoch:   $EPOCH"
  echo "image:   $IMAGE_ID"
} > "$OUT_ROOT/build-info.txt"

echo
echo "-- Build complete --"
cat "$OUT_ROOT/SHA256SUMS"
echo
echo "To verify reproducibility, run this again (ideally on another"
echo "machine, with the same image) and compare SHA256SUMS."
