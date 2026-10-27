"""Generate zh-1 candidates: every word that passes the gates and sounds
different from every word ranked above it.

Usage: uv run generate.py   (after uv run fetch.py)

Writes out/candidates.tsv (in rank order; any prefix is mutually distinct),
out/rejected.tsv (word, gate, detail) and out/summary.txt. Words in
denylist.tsv are removed before selection, which frees their sound keys for
lower-ranked words: rerun after every review pass.

Spec: .devloop/spikes/chinese-words.md Revision 3. Nothing produced here
ships until Task 2.5 freezes the list; MOE data is read only to check, never
copied.
"""

import collections
import csv
import math
import re
import sys
from pathlib import Path

import opencc
from pypinyin import Style, lazy_pinyin

import data
import sound

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"

MAX_HSK_LEVEL = 9
# Words outside HSK join the pool when they are MOE 簡編本 headwords and occur
# at least this often in SUBTLEX-CH (33.5 M tokens; 10 is about 0.3 per
# million). Two-character words alone cannot fill the list once reviewers
# have removed abstract, conversational and alarming words (owner decision
# 2026-10-25), so three-character nouns join too.
SUBTLEX_MIN_COUNT = 1
# Three-character words are rarer in subtitles (a film says 车 more than
# 摩托车), so any occurrence counts; MOE membership is the familiarity gate.
SUBTLEX_MIN_COUNT_3 = 1
# A word is kept only if every HSK part-of-speech tag is one of these. For
# words outside HSK, SUBTLEX-CH tags must put this share of tokens in them.
ALLOWED_POS = {"n", "v", "vn", "a", "an", "t", "s", "f", "b", "nz"}
# Words outside HSK must be nouns: the syllabus already holds the common
# verbs and adjectives, and film subtitles add many crude or violent ones.
NOUN_POS = {"n", "nz", "s"}
SUBTLEX_POS_SHARE = 0.9
# Rank tiers by part of speech: concrete things first, then descriptions and
# places, then actions and time words (现在, 今天), which sound like ordinary
# talk over the phone. The greedy selection gives a sound to the
# higher-ranked word, so this decides who wins each clash.
POS_TIERS = (NOUN_POS, {"a", "an", "b", "f"} | NOUN_POS)
# Illustrative character deny-list (alarm, money, crime, death or illness,
# politics, religion). Reviewers extend it through denylist.tsv.
DENY_CHARS = set("死亡病毒杀炸骗警罪枪战血伤债贷款钱账税股党政宗教神佛鬼癌灾害危险凶偷抢盗赌狱"
                 "案判刑尸葬哭痛疾残暴恐敌兵军革命权票")
# Conversation fillers and vocatives: over the phone they sound like talk,
# not like a code, and "Mom" is the very name a scammer claims.
DISCOURSE = set("没有 可以 知道 还是 觉得 谢谢 不错 真的 起来 下来 出来 过去 上来 回来 妈妈 爸爸 "
                "叔叔 阿姨 宝贝 孩子 宝宝 哥哥 姐姐 弟弟 妹妹 爷爷 奶奶".split())

# Words that name a target of the video-call liveness actions (look up at
# the ceiling, down at the floor, over a shoulder; touch the nose, forehead,
# left or right ear: lib/core/crypto/liveness_challenge.dart). On the verify
# screen the words are heard while WATCH FOR shows the action, so a word like
# 耳朵 or 天花板 could be taken for the action. Update with LivenessAction.
LIVENESS = re.compile(r"鼻|额|耳|肩|天花板|地板|地面|抬头|低头|左手|右手")

S2T = [opencc.OpenCC(c) for c in ("s2t", "s2tw", "s2hk")]
S2TW = opencc.OpenCC("s2tw")
S2TWP = opencc.OpenCC("s2twp")
TW2S = opencc.OpenCC("tw2s")


def load_denylist() -> dict:
    out = {}
    path = HERE / "denylist.tsv"
    with path.open(encoding="utf-8") as f:
        for row in csv.reader(f, delimiter="\t"):
            if row and not row[0].startswith("#") and row[0] != "word":
                out[row[0]] = row
    return out


def load_flags() -> list:
    """(text, category) rows of flags.tsv."""
    out = []
    with (HERE / "flags.tsv").open(encoding="utf-8") as f:
        for row in csv.reader(f, delimiter="\t"):
            if row and not row[0].startswith("#") and row[0] != "text":
                out.append((row[0], row[1]))
    return out


def load_kept() -> set:
    """Words with at least one review decision, all of them keep."""
    path = HERE / "review" / "decisions.tsv"
    if not path.exists():
        return set()
    by = collections.defaultdict(set)
    with path.open(encoding="utf-8") as f:
        for r in csv.DictReader(f, delimiter="\t"):
            by[r["word"]].add(r["decision"])
    return {w for w, d in by.items() if d == {"keep"}}


def mainland_pinyin(h: str) -> str:
    return data.norm_pinyin(" ".join(lazy_pinyin(h, style=Style.TONE)))


def main() -> int:
    hsk, sub, sub_pos = data.load_hsk(), data.load_subtlex(), data.load_subtlex_pos()
    moe, chewing, mcb, occ = data.load_moe(), data.load_chewing(), data.load_mcb(), data.load_mcb_occ()
    conc = data.load_concreteness()
    revised = data.load_moe("moe-revised.zip")
    kept_by_review = load_kept()
    vulgar, flag_rows = data.load_ldnoobw(), load_flags()
    deny = load_denylist()
    rejected = []

    def reject(h, gate, detail=""):
        rejected.append((h, gate, detail))

    # Pool: HSK 1-9 two-character words, then MOE headwords outside HSK that
    # are frequent enough in SUBTLEX-CH (converted to simplified).
    def han(w):
        return data.HAN2.match(w) or data.HAN3.match(w)

    pool = {h: "hsk" for h, e in hsk.items() if han(h) and e["level"] <= MAX_HSK_LEVEL
            and (len(h) == 2 or (e["pos"] and e["pos"] <= NOUN_POS))}
    for t in list(moe) + [t for t in revised if t not in moe]:
        if han(t):
            h = TW2S.convert(t)
            if h not in hsk and sub.get(h, (0, 0))[0] >= (SUBTLEX_MIN_COUNT if len(h) == 2 else SUBTLEX_MIN_COUNT_3):
                pool.setdefault(h, "moe+subtlex" if t in moe else "moe-revised+subtlex")

    cands = []
    for h, origin in pool.items():
        tw = S2TW.convert(h)
        if origin == "hsk":
            if not hsk[h]["pos"] or not hsk[h]["pos"] <= ALLOWED_POS:
                reject(h, "pos", ",".join(sorted(hsk[h]["pos"])))
                continue
        else:
            tags = sub_pos.get(h)
            total = sum(tags.values()) if tags else 0
            ok = sum(n for tag, n in tags.items() if tag in NOUN_POS) if tags else 0
            if not total or ok / total < SUBTLEX_POS_SHARE:
                reject(h, "pos", ",".join(f"{t}:{n}" for t, n in (tags or {}).most_common(3)))
                continue
        if set(h) & DENY_CHARS:
            reject(h, "deny-char")
            continue
        if h in DISCOURSE:
            reject(h, "discourse")
            continue
        if LIVENESS.search(h):
            reject(h, "liveness")
            continue
        if h in deny:
            reject(h, "denylist", "|".join(deny[h][1:]))
            continue
        if TW2S.convert(tw) != h:
            reject(h, "script-roundtrip", tw)
            continue
        if S2TWP.convert(h) != tw:
            reject(h, "regional-vocab", S2TWP.convert(h))
            continue
        # Taiwan gates. MOE must know the word (Taiwan-common) with exactly
        # one reading, and that reading must equal the Mainland one, so one
        # pinyin serves both and Taiwan users are never shown a reading they
        # would not say (垃圾 lājī vs lèsè).
        # 簡編本 first (Taiwan-common, chosen by frequency); the larger 修訂本
        # only for words outside it, where reviewers screen out rare ones.
        readings = moe.get(tw) or revised.get(tw)
        if not readings:
            reject(h, "not-in-moe", tw)
            continue
        if len({r for r in readings}) != 1:
            reject(h, "moe-several-readings", " / ".join(p for _, p in readings))
            continue
        moe_zhuyin, moe_pinyin = readings[0]
        mp = mainland_pinyin(h)
        if mp != moe_pinyin:
            reject(h, "reading-differs", f"{mp} vs MOE {moe_pinyin}")
            continue
        if origin == "hsk" and hsk[h]["pinyin"] != {mp}:
            reject(h, "hsk-several-readings", " / ".join(sorted(hsk[h]["pinyin"])))
            continue
        # Zhuyin that ships comes from an open input-method table, only when
        # that table has the one MOE reading and nothing else.
        zhuyin, zsrc = None, None
        for name, table in (("chewing", {k: v[0] for k, v in chewing.items()}), ("mcb", mcb)):
            if table.get(tw) == {moe_zhuyin}:
                zhuyin, zsrc = moe_zhuyin, name
                break
        # A word in neither phrase table (no other reading to conflict with)
        # takes each character's reading from libchewing, provided every one
        # is listed for that character and together they spell the MOE reading.
        if not zhuyin and tw not in chewing and tw not in mcb:
            syllables = moe_zhuyin.split(" ")
            if len(syllables) == len(tw) and all(s in chewing.get(c, (set(), 0))[0] for c, s in zip(tw, syllables)):
                zhuyin, zsrc = moe_zhuyin, "chewing-chars"
        if not zhuyin:
            reject(h, "zhuyin-source", f"chewing={sorted(chewing.get(tw, (set(), 0))[0])} mcb={sorted(mcb.get(tw, set()))} moe={moe_zhuyin}")
            continue
        count, cd = sub.get(h, (0, 0.0))
        pos = hsk[h]["pos"] if origin == "hsk" else NOUN_POS
        tier = next((i for i, t in enumerate(POS_TIERS) if pos <= t), len(POS_TIERS))
        flags = sorted({cat for text, cat in flag_rows if text in h}
                       | ({"vulgar"} if any(v in h for v in vulgar if len(v) >= 2) or h in vulgar else set()))
        cands.append({
            "flags": ",".join(flags), "tier": tier, "chars": len(h), "concreteness": conc.get(h, ""),
            "simplified": h, "tw": tw, "forms": {h} | {c.convert(h) for c in S2T},
            "pinyin": mp, "zhuyin": zhuyin, "zhuyin_source": zsrc, "origin": origin,
            "hsk": hsk[h]["level"] if origin == "hsk" else "", "subtlex": count, "cd": cd,
            "chewing_freq": chewing.get(tw, (set(), 0))[1], "mcb_occ": occ.get(tw, 0),
        })

    # Within a tier, rank by familiarity (log contextual diversity: the share
    # of films a word occurs in) minus a penalty for abstractness (Xu & Li
    # 2020, 1 concrete to 5 abstract; unrated words count as 3). One step of
    # abstractness costs as much as a 10x drop in contextual diversity.
    def score(c):
        a = c["concreteness"] if c["concreteness"] != "" else 3.0
        return math.log10(c["cd"] + 0.01) - (a - 1)
    # Words every reviewer so far has kept come first, so a new, unreviewed
    # word can never take their sound.
    cands.sort(key=lambda c: (c["simplified"] not in kept_by_review, c["tier"], -score(c), c["simplified"]))

    syllables = sound.inventory({ch for c in cands for f in c["forms"] for ch in f})
    # used: full keys of chosen words. alt_used: keys of other syllable splits
    # of chosen words' spellings. prefix_used / two_used: exact spellings of
    # chosen three-character words' first two syllables, and of chosen
    # two-character words.
    used, alt_used, prefix_used, two_used, chosen = {}, set(), {}, {}, []
    chosen_words, sub_used = set(), {}  # words chosen; 2-char subsequences of chosen 3-char words
    for c in cands:
        readings = sound.readings_of(c["forms"], {sound.detone(c["pinyin"])})
        keys = sound.keyset(readings)
        alt = sound.alt_segment_keys(sound.detone(c["pinyin"]), syllables)
        pre, two = sound.prefixes(readings), sound.spelt(readings)
        hit = (keys & used.keys()) or (keys & alt_used) or {k for k in alt if k in used}
        if hit:
            k = next(iter(hit))
            reject(c["simplified"], "sound", f"{k} ~ {used.get(k, '(split)')}")
            continue
        clash = (two & prefix_used.keys()) or (pre & two_used.keys())
        # A three-character word that is a two-character entry plus one
        # character (电扇 / 电风扇) invites typing one for the other.
        h = c["simplified"]
        shorter = {h[:i] + h[i + 1:] for i in range(len(h))} if len(h) == 3 else set()
        dup = (shorter & chosen_words) or ({h} & sub_used.keys())
        if dup:
            w = next(iter(dup))
            reject(h, "near-duplicate", f"{h} ~ {sub_used.get(w, w)}")
            continue
        if clash:
            k = next(iter(clash))
            reject(c["simplified"], "prefix", f"{'/'.join(k)} ~ {prefix_used.get(k) or two_used.get(k)}")
            continue
        for k in keys:
            used[k] = c["simplified"]
        for k in pre:
            prefix_used[k] = c["simplified"]
        for k in two:
            two_used[k] = c["simplified"]
        chosen_words.add(h)
        for w in shorter:
            sub_used[w] = h
        alt_used |= alt
        chosen.append(c)

    OUT.mkdir(exist_ok=True)
    cols = ["rank", "simplified", "tw", "pinyin", "zhuyin", "zhuyin_source", "origin", "hsk",
            "tier", "chars", "concreteness", "subtlex", "cd", "chewing_freq", "mcb_occ", "flags", "other_forms"]
    with (OUT / "candidates.tsv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t", lineterminator="\n")
        w.writerow(cols)
        for i, c in enumerate(chosen, 1):
            other = " ".join(sorted(c["forms"] - {c["simplified"], c["tw"]}))
            w.writerow([i] + [c[k] for k in cols[1:-1]] + [other])
    with (OUT / "rejected.tsv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t", lineterminator="\n")
        w.writerow(["word", "gate", "detail"])
        w.writerows(sorted(rejected, key=lambda r: (r[1], r[0])))

    gates = collections.Counter(g for _, g, _ in rejected)
    origins = collections.Counter(f'{c["origin"]}/{c["chars"]}' for c in chosen)
    lines = [f"pool {len(pool)} (hsk {sum(1 for o in pool.values() if o == 'hsk')}, moe+subtlex {sum(1 for o in pool.values() if o != 'hsk')})",
             f"passed gates {len(cands)}", f"eligible (mutually distinct) {len(chosen)}: {dict(origins)}",
             "eligible by tier (0 nouns, 1 adjectives and places, 2 verbs and time words): "
             + str(dict(sorted(collections.Counter(c["tier"] for c in chosen).items()))),
             "rejections: " + ", ".join(f"{g} {n}" for g, n in gates.most_common())]
    (OUT / "summary.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    return 0 if len(chosen) >= 2048 else 1


if __name__ == "__main__":
    sys.exit(main())
