"""Sound keys: when two words can be heard as the same.

Tones are dropped. Each syllable maps to a SET of canonical forms, because a
merger can map one syllable two ways (hui is both hui and fei). Two words
clash when they share a key, that is, when some reading of each gives the
same form for both syllables. Spec: .devloop/spikes/chinese-words.md §2 and
Revision 3 (onset confusions in noise from Yu & Do 2023).
"""

import itertools
import re
import unicodedata

from pypinyin import Style, lazy_pinyin, pinyin

INITIALS = ("zh", "ch", "sh", "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h",
            "j", "q", "x", "r", "z", "c", "s", "y", "w")

# Southern hu+V heard as f+V (fei/hui, fan/huan, fen/hun, fu/hu).
HU_TO_F = {"u": "u", "ui": "ei", "un": "en", "ua": "a", "uan": "an", "uang": "ang", "uo": "o"}

# Northeast r -> y (ren/yin, ri/yi).
R_TO_Y = {"i": "i", "e": "e", "en": "in", "eng": "ing", "ou": "ou", "ang": "ang", "an": "an",
          "ao": "ao", "u": "v", "uan": "van", "un": "vn", "ong": "ong", "uo": "o", "ui": "vi"}

# Onsets confused in noise: the pairs that native listeners confused at
# least a third of the time at 12 dB SNR in Yu & Do 2023 (OSF raw data, 47
# listeners; recomputed in .devloop/qa-helpers/lang/zh): h>p 0.59, b>f 0.38.
# The weaker pairs there (p>t 0.22, t>p 0.21, d>g 0.18, m>n 0.17, k>t 0.17)
# are left to the listening pipeline (listen/run.py), which measures them
# over real phone codecs; as hard rules they took about 750 words out of a
# pool that cannot spare them. r>y and n>l are accent mergers above.
# Applied one step only, never chained: b>s, x>s, s>f and f>h are all 0.00
# there. Aspiration pairs (b/p, d/t, g/k) stay apart (all under 2%).
NOISE = {"h": "p", "p": "h", "b": "f", "f": "b"}


def split_initial(syl: str):
    for i in INITIALS:
        if syl.startswith(i):
            return i, syl[len(i):]
    return "", syl


def classes(syl: str) -> set:
    """Canonical forms of one toneless syllable (ü written v or ü)."""
    syl = syl.replace("ü", "v")
    i, f = split_initial(syl)
    if i in ("j", "q", "x", "y") and f.startswith("u"):
        f = "v" + f[1:]  # ju is jü
    forms = {(i, f)}

    def add(fn):
        for x in list(forms):
            y = fn(*x)
            if y:
                forms.add(y)

    add(lambda i, f: ("y", R_TO_Y.get(f, f)) if i == "r" else None)
    add(lambda i, f: (i, "i" + f[1:]) if f.startswith("v") else None)  # ü -> i (Taiwan, Hokkien)
    add(lambda i, f: ("f", HU_TO_F[f]) if i == "h" and f in HU_TO_F else None)
    add(lambda i, f: ("f", "eng") if (i, f) == ("h", "ong") else None)  # hong ~ feng
    add(lambda i, f: {("g", "uo"): ("g", "e"), ("h", "uo"): ("h", "e")}.get((i, f)))  # Southwest
    for i0, f0 in list(forms):
        for j in NOISE.get(i0, ""):
            forms.add((j, f0))

    out = set()
    for i, f in forms:
        i = {"zh": "z", "ch": "c", "sh": "s", "n": "l", "r": "l"}.get(i, i)  # southern, Taiwan
        f = re.sub(r"ing$", "in", f)
        f = re.sub(r"eng$", "en", f)
        f = re.sub(r"ang$", "an", f)
        if i not in ("j", "q", "x", "y", "l"):
            f = f.replace("v", "u")
        if i == "y" and f.startswith("i") and f not in ("i", "in", "ing"):
            f = f[1:]  # yian is spelt yan
        out.add(i + "|" + f)
    return out


def keyset(readings) -> set:
    """Keys of a set of readings (each a tuple of toneless syllables)."""
    keys = set()
    for r in readings:
        for combo in itertools.product(*[classes(s) for s in r]):
            keys.add("/".join(combo))
    return keys


def detone(pinyin_text: str) -> tuple:
    """Tone-marked pinyin ("píng guǒ") -> toneless syllables, ü kept."""
    out = []
    for syl in pinyin_text.split():
        d = unicodedata.normalize("NFD", syl)
        d = "".join(c for c in d if not ("̀" <= c <= "ͯ") or c == "̈")
        out.append(unicodedata.normalize("NFC", d).replace("ü", "ü"))
    return tuple(out)


def readings_of(forms, extra=()) -> set:
    """Every toneless reading of every written form: the phrase reading plus
    every combination of per-character heteronyms, plus [extra] readings
    (from HSK or MOE)."""
    rs = set(extra)
    for h in forms:
        rs.add(tuple(lazy_pinyin(h, style=Style.NORMAL, v_to_u=True)))
        per = [set(pinyin(c, style=Style.NORMAL, heteronym=True, v_to_u=True)[0]) for c in h]
        rs |= set(itertools.product(*per))
    n = len(next(iter(forms)))
    return {r for r in rs if len(r) == n and all(s.isalpha() for s in r)}


def inventory(chars) -> set:
    """Toneless syllables (ü as v) of every reading of every character."""
    syl = set()
    for c in chars:
        syl.update(pinyin(c, style=Style.NORMAL, heteronym=True, v_to_u=True)[0])
    return {s.replace("ü", "v") for s in syl if s.replace("ü", "v").isalpha()}


def splits(s: str, n: int, syllables: set):
    """Every way to cut s into n syllables of the inventory."""
    if n == 1:
        if s in syllables:
            yield (s,)
        return
    for k in range(1, len(s)):
        if s[:k] in syllables:
            for rest in splits(s[k:], n - 1, syllables):
                yield (s[:k],) + rest


def alt_segment_keys(std: tuple, syllables: set) -> set:
    """Keys of the other ways to split the word's Latin spelling into two or
    three syllables: "qinai" is qin|ai and also qi|nai, which merges with
    qi|lai; a three-syllable spelling may also read as two syllables, and
    the reverse."""
    s = "".join(std).replace("ü", "v")
    std_v = tuple(x.replace("ü", "v") for x in std)
    keys = set()
    for n in (2, 3):
        for cut in splits(s, n, syllables):
            if cut != std_v:
                keys |= keyset([cut])
    return keys


def prefixes(readings) -> set:
    """The first two syllables of three-syllable readings, exactly as spelt
    (toneless, ü as v, no mergers). A two-syllable entry must not be one of
    them: a listener or typist could stop at 电视 for 电视机. Mergers and
    suffixes are not applied here: mishearing through an accent AND dropping
    a syllable are two independent errors (三明治 is not at risk from 商人)."""
    return {tuple(s.replace("ü", "v") for s in r[:2]) for r in readings if len(r) == 3}


def spelt(readings) -> set:
    """Two-syllable readings exactly as spelt, to compare with prefixes()."""
    return {tuple(s.replace("ü", "v") for s in r) for r in readings if len(r) == 2}
