"""Loaders for the pinned sources in .cache/ (run fetch.py first).

Every loader returns plain dicts keyed by the word as the source writes it:
simplified for HSK and SUBTLEX-CH, Taiwan traditional for MOE, libchewing and
McBopomofo.
"""

import collections
import io
import json
import re
import subprocess
import unicodedata
import zipfile
from pathlib import Path

CACHE = Path(__file__).resolve().parent / ".cache"
HAN2 = re.compile(r"^[一-鿿]{2}$")
HAN3 = re.compile(r"^[一-鿿]{3}$")


def norm_zhuyin(s: str) -> str:
    """One canonical spelling of a Zhuyin reading: syllables split by a single
    ASCII space, the neutral-tone dot after the syllable (MOE writes it
    before, libchewing after), no first-tone mark."""
    out = []
    for syl in s.replace("　", " ").split():
        if syl.startswith("˙"):
            syl = syl[1:] + "˙"
        out.append(syl.replace("ˉ", ""))
    return " ".join(out)


def norm_pinyin(s: str) -> str:
    """Tone-marked pinyin, NFC, lower case, syllables split by one space."""
    return " ".join(unicodedata.normalize("NFC", s).lower().split())


def load_hsk() -> dict:
    """simplified -> {level, pos, frequency, pinyin}. Level is the HSK 3.0
    (GF0025-2021, "new-N") level; words without one are skipped. pinyin is
    the set of readings HSK lists across the word's forms."""
    out = {}
    for e in json.loads((CACHE / "hsk-complete.json").read_text(encoding="utf-8")):
        levels = [int(x.split("-")[1]) for x in e["level"] if x.startswith("new-")]
        if not levels:
            continue
        out[e["simplified"]] = {
            "level": min(levels),
            "pos": set(e["pos"]),
            "frequency": e["frequency"],
            "pinyin": {norm_pinyin(f["transcriptions"]["pinyin"]) for f in e["forms"]},
        }
    return out


def _subtlex_lines(member: str, archive: str):
    with zipfile.ZipFile(CACHE / archive) as z:
        text = z.read(member).decode("gb18030")
    return text.splitlines()


def load_subtlex() -> dict:
    """simplified -> (count, contextual diversity in % of films)."""
    out = {}
    for i, line in enumerate(_subtlex_lines("SUBTLEX-CH-WF", "subtlexchwf.zip")):
        p = line.split("\t")
        if i >= 3 and len(p) >= 6 and p[1].isdigit():
            out[p[0]] = (int(p[1]), float(p[5]))
    return out


def load_subtlex_pos() -> dict:
    """simplified -> Counter(part-of-speech tag -> count), from the tagged
    SUBTLEX-CH file (a lemma line, then one "@ @ form tag count" line per
    tag)."""
    out = collections.defaultdict(collections.Counter)
    for line in _subtlex_lines("SUBTLEX-CH-WF_PoS", "subtlexchwfpos.zip"):
        p = line.split("\t")
        if len(p) >= 5 and p[0] == "@" and p[4].strip().isdigit():
            out[p[2]][p[3]] += int(p[4])
    return out


def load_moe(archive: str = "moe-concised.zip") -> dict:
    """Taiwan traditional -> list of (zhuyin, pinyin) readings: one per MOE
    entry row (a word read two ways has two rows), plus each row's variant
    reading (又音, 語音, 讀音) when present. Build time only: the MOE licence
    forbids shipping changed readings, so nothing from here is copied into
    the list."""
    import openpyxl

    with zipfile.ZipFile(CACHE / archive) as z:
        name = next(n for n in z.namelist() if n.endswith(".xlsx"))
        wb = openpyxl.load_workbook(io.BytesIO(z.read(name)), read_only=True)
    rows = wb.worksheets[0].iter_rows(values_only=True)
    header = next(rows)
    col = {h.split(" ")[0]: i for i, h in enumerate(header) if h}
    out = collections.defaultdict(list)
    for r in rows:
        word = r[col["字詞名"]]
        if not isinstance(word, str):
            continue
        out[word].append((norm_zhuyin(r[col["注音一式"]] or ""), norm_pinyin(r[col["漢語拼音"]] or "")))
        vz, vp = r[col["變體注音"]], r[col["變體漢語拼音"]]
        if isinstance(vz, str) and vz.strip():
            out[word].append((norm_zhuyin(vz), norm_pinyin(vp or "")))
    return dict(out)


def load_chewing() -> dict:
    """Taiwan traditional -> (set of Zhuyin readings, max frequency)."""
    out = {}
    for line in (CACHE / "chewing-tsi.csv").read_text(encoding="utf-8").splitlines():
        if line.startswith("#"):
            continue
        p = line.split(",")
        if len(p) >= 3:
            readings, freq = out.get(p[0], (set(), 0))
            readings.add(norm_zhuyin(p[2]))
            out[p[0]] = (readings, max(freq, int(p[1])))
    return out


def load_mcb() -> dict:
    """Taiwan traditional -> set of Zhuyin readings (McBopomofo)."""
    out = collections.defaultdict(set)
    for line in (CACHE / "mcb-BPMFMappings.txt").read_text(encoding="utf-8").splitlines():
        p = line.split(" ", 1)
        if len(p) == 2:
            out[p[0]].add(norm_zhuyin(p[1]))
    return dict(out)


def load_mcb_occ() -> dict:
    """Taiwan traditional -> occurrence count (McBopomofo phrase.occ)."""
    out = {}
    for line in (CACHE / "mcb-phrase.occ").read_text(encoding="utf-8").splitlines():
        p = line.split(" ")
        if len(p) == 2 and p[1].isdigit():
            out[p[0]] = int(p[1])
    return out


def load_concreteness() -> dict:
    """simplified -> mean concreteness rating, 1 (concrete) to 5 (abstract),
    Xu & Li 2020. The archive is RAR; bsdtar (libarchive) reads it."""
    import openpyxl

    name = "Concretenss Ratings of 9877 Two Character Chinese Words.xlsx"  # sic
    raw = subprocess.run(["bsdtar", "-xOf", str(CACHE / "xu-li-2020-s001.rar"), name],
                         capture_output=True, check=True).stdout
    wb = openpyxl.load_workbook(io.BytesIO(raw), read_only=True)
    rows = wb.worksheets[0].iter_rows(values_only=True)
    next(rows)
    return {r[1]: float(r[2]) for r in rows if isinstance(r[1], str) and r[2] is not None}


def load_ldnoobw() -> set:
    """Vulgar and obscene words and phrases (LDNOOBW zh), simplified."""
    text = (CACHE / "ldnoobw-zh.txt").read_text(encoding="utf-8")
    return {w.strip() for w in text.splitlines() if w.strip()}
