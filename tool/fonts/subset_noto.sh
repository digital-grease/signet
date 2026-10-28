#!/usr/bin/env bash
# Builds the Latin subset of Noto Sans embedded in the printed challenge
# grid card (lib/features/inspect/cr_grid_pdf.dart, v0.5.0 plan Task 1.7).
# The PDF's built-in Helvetica covers only U+0000-00FF, which lacks the
# French typographic apostrophe (U+2019) and oe (U+0153).
#
# Source: Noto Sans version 2.015 (name table), from notofonts/
# latin-greek-cyrillic (https://github.com/notofonts/latin-greek-cyrillic),
# as packaged by Arch Linux noto-fonts 1:2026.10.01-1; the sha256 values
# below pin the exact files. SIL Open Font License 1.1, no Reserved Font
# Name (assets/fonts/OFL.txt); the output is a modified version under the
# same licence and keeps the font's own copyright and licence name fields.
#
# Built with fonttools 4.67.0 (checked below; other versions may produce
# different bytes). The output is byte-identical across runs.
#
# Usage: tool/fonts/subset_noto.sh [source-dir]
set -euo pipefail

src="${1:-/usr/share/fonts/noto}"
want_fonttools=4.67.0
have=$(python3 -c 'import fontTools; print(fontTools.version)')
if [[ "$have" != "$want_fonttools" ]]; then
  echo "fonttools $want_fonttools needed, found $have" >&2
  exit 1
fi
out="$(dirname "$0")/../../assets/fonts"

declare -A sha=(
  [NotoSans-Regular.ttf]=478c558ea716033cd60c03438f628dfa75694dcf6b5f6d505a2f05fd2b4f3823
  [NotoSans-Bold.ttf]=1df075a380fc7cb898acf64c1f7b3b4dd780de3caa860178bf929de35817a913
)

# Latin (Basic, Latin-1, Extended-A and -B, Extended Additional for
# Vietnamese), IPA and spacing modifiers (Hawaiian ʻ), combining marks,
# Greek and Cyrillic (names on the card), General Punctuation (quotes,
# dashes, ellipsis, narrow no-break space), euro, trademark, arrows, minus,
# and the replacement character for a damaged label. The card text and the
# word lists need only the first two ranges; the rest is for contact
# names.
unicodes="U+0020-007E,U+00A0-036F,U+0370-03FF,U+0400-04FF,U+1E00-1EFF,U+2000-206F,U+20AC,U+2122,U+2190-2193,U+2212,U+FFFD"

for name in NotoSans-Regular.ttf NotoSans-Bold.ttf; do
  echo "${sha[$name]}  $src/$name" | sha256sum --check --quiet
  pyftsubset "$src/$name" \
    --unicodes="$unicodes" \
    --layout-features='' \
    --name-IDs='*' \
    --no-hinting \
    --output-file="$out/${name%.ttf}-Latin.ttf"
done
sha256sum "$out"/NotoSans-*-Latin.ttf
