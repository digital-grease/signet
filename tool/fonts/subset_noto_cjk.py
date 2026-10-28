#!/usr/bin/env python3
"""Builds the Chinese subsets of Noto Sans CJK embedded in the printed
challenge grid card (lib/features/inspect/cr_grid_pdf.dart, v0.5.0 plan
Task 3.6, decision D5).

Each subset holds the characters of every zh-1 word (simplified forms in
the SC faces, Taiwan traditional forms in the TC faces), the Chinese card
strings of app_zh.arb and app_zh_Hant.arb, the characters of the commonest
family names for a contact (妈妈, 爷爷, 外婆), and CJK punctuation. Latin
text on the card stays in the Noto Sans Latin subset (subset_noto.sh);
these fonts are its fallback. Any other name the fonts cannot print is
drawn as an image (CrGridPdf).

The pdf package reads only TrueType outlines and the source fonts are CFF,
so the outlines are converted to quadratic curves (cu2qu, 1 unit of error
on a 1000-unit em, invisible at card sizes) and the vertical-layout and
OpenType layout tables, which the card never uses, are dropped.

Source: Noto Sans CJK version 2.004 (name table), from notofonts/noto-cjk
(https://github.com/notofonts/noto-cjk), as packaged by Arch Linux
noto-fonts-cjk 20240730-1; the sha256 values below pin the exact files.
SIL Open Font License 1.1 (assets/fonts/OFL.txt); its Reserved Font Name
"Source" is not used here. The output is a modified version under the same
licence and keeps the font's own copyright and licence name fields.

Built with fonttools 4.67.0 (checked below; other versions may produce
different bytes). The output is byte-identical across runs for the same
word list and card strings; rerun after changing either (the coverage test
in test/features/cr_grid_pdf_test.dart fails until then).

Usage: tool/fonts/subset_noto_cjk.py [source-dir]
"""

import hashlib
import json
import re
import sys
from pathlib import Path

import fontTools
from fontTools import subset
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont, newTable

WANT_FONTTOOLS = "4.67.0"

SHA256 = {
    "NotoSansCJK-Regular.ttc":
        "b76b0433203017ca80401b2ee0dd69350349871c4b19d504c34dbdd80541690a",
    "NotoSansCJK-Bold.ttc":
        "faa5f3656a78b2e2d450d27fe8382c778bc2b6bb5ea29c986664a6a435056ceb",
}

# Faces in the collections: 2 is Noto Sans CJK SC, 3 is Noto Sans CJK TC.
FACES = {"sc": 2, "tc": 3}

# Card strings (keys of the ARB catalogs) the PDF prints.
CARD_KEYS = [
    "crPdfDocTitle",
    "crPdfCardTitle",
    "crPdfWarningTitle",
    "crPdfWarningBody",
    "crPdfRowsHeader",
    "crPdfColumnsHeader",
    "crPdfFooter",
]

# Characters of the names people commonly give family contacts, in both
# scripts, so a card for 妈妈 or 外婆 prints the name as text.
CONTACT_NAMES = (
    "爸妈媽爷爺奶姥婆公外祖孙孫儿兒女子哥姐弟妹叔姨舅姑伯婶嬸嫂"
    "父母亲親老小大宝寶贝貝先生太夫妻家人"
)

# CJK Symbols and Punctuation (、。「」 and the ideographic space), and the
# fullwidth forms (，：（）！？ and fullwidth digits and letters).
PUNCTUATION = list(range(0x3000, 0x3040)) + list(range(0xFF01, 0xFF5F))

ROOT = Path(__file__).resolve().parent.parent.parent


def zh1_forms():
    """The simplified and Taiwan traditional forms of every zh-1 word."""
    text = (ROOT / "lib/core/crypto/zh_wordlist.dart").read_text("utf-8")
    pairs = re.findall(r"ZhWord\('([^']*)', '([^']*)'", text)
    if len(pairs) != 2048:
        sys.exit(f"expected 2048 zh-1 entries, found {len(pairs)}")
    return [s for s, _ in pairs], [t for _, t in pairs]


def card_text(arb):
    data = json.loads((ROOT / "lib/l10n" / arb).read_text("utf-8"))
    return "".join(data[k] for k in CARD_KEYS)


def is_wide(ch):
    """Characters the Latin subset does not cover: Han and CJK forms."""
    return ord(ch) >= 0x2E80


def to_truetype(font):
    """Replaces the CFF outlines of [font] with TrueType ones."""
    order = font.getGlyphOrder()
    glyph_set = font.getGlyphSet()
    glyf = newTable("glyf")
    glyf.glyphOrder = order
    glyf.glyphs = {}
    for name in order:
        pen = TTGlyphPen(glyph_set)
        glyph_set[name].draw(Cu2QuPen(pen, 1.0, reverse_direction=True))
        glyf.glyphs[name] = pen.glyph()
    font["loca"] = newTable("loca")
    font["glyf"] = glyf
    del font["CFF "]
    maxp = newTable("maxp")
    maxp.tableVersion = 0x00010000
    maxp.numGlyphs = len(order)
    for field in (
        "maxPoints maxContours maxCompositePoints maxCompositeContours "
        "maxTwilightPoints maxStorage maxFunctionDefs maxInstructionDefs "
        "maxStackElements maxSizeOfInstructions maxComponentElements "
        "maxComponentDepth"
    ).split():
        setattr(maxp, field, 0)
    maxp.maxZones = 1
    font["maxp"] = maxp
    font["head"].glyphDataFormat = 0
    font["post"].formatType = 3.0
    font.sfntVersion = "\x00\x01\x00\x00"


def build(src, out, weight, face, chars):
    font = TTFont(
        src / f"NotoSansCJK-{weight}.ttc",
        fontNumber=FACES[face],
        recalcTimestamp=False,
    )
    options = subset.Options()
    options.layout_features = []
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.hinting = False
    options.notdef_outline = True
    options.drop_tables += ["vhea", "vmtx", "VORG", "BASE", "GSUB", "GPOS"]
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=sorted({ord(c) for c in chars} | set(PUNCTUATION)))
    subsetter.subset(font)
    to_truetype(font)
    path = out / f"NotoSansCJK{face}-{weight}-Card.ttf"
    font.save(path)
    return path


def main():
    if fontTools.version != WANT_FONTTOOLS:
        sys.exit(f"fonttools {WANT_FONTTOOLS} needed, found {fontTools.version}")
    src = Path(sys.argv[1] if len(sys.argv) > 1 else "/usr/share/fonts/noto-cjk")
    out = ROOT / "assets/fonts"
    for name, want in SHA256.items():
        have = hashlib.sha256((src / name).read_bytes()).hexdigest()
        if have != want:
            sys.exit(f"{name}: sha256 {have}, expected {want}")

    simplified, traditional = zh1_forms()
    chars = {
        "sc": {c for w in simplified for c in w}
        | set(card_text("app_zh.arb"))
        | set(CONTACT_NAMES),
        "tc": {c for w in traditional for c in w}
        | set(card_text("app_zh_Hant.arb"))
        | set(CONTACT_NAMES),
    }
    for face in ("sc", "tc"):
        wide = sorted(c for c in chars[face] if is_wide(c))
        for weight in ("Regular", "Bold"):
            path = build(src, out, weight, face, wide)
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            print(f"{digest}  {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
