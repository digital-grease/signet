"""LLM reviewer panel for zh-1 (spike Revision 3, plan Task 2.4).

  uv run review.py batches <reviewer> [--top N] [--size S]
      Write out/review/<reviewer>/round-K/batch-NN.tsv (K is the next round):
      the top N candidates
      (default 2560, 2048 plus 25%) that <reviewer> has not decided yet and
      was not sent in an earlier round, in
      batches of S rows (default 320), each with a few known-bad seed rows
      mixed in. Give each batch, with review/PROMPT.md, to the reviewer, and
      save its answer next to it as batch-NN.answer.tsv.

  uv run review.py merge
      Read every unmerged answer file, check coverage and seed recall, record
      each reviewer's decisions in review/decisions.tsv (checked in), append
      every reject to denylist.tsv, and rename the answers *.merged.tsv. Then rerun generate.py: rejected words
      free their sounds, new words enter the top N, and batches gives each
      reviewer only those.

Any reviewer's reject wins. A word is final only when every reviewer in
REVIEWERS has kept it.
"""

import argparse
import csv
import random
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out" / "review"
DECISIONS = HERE / "review" / "decisions.tsv"
DENYLIST = HERE / "denylist.tsv"

# Every word must be kept by all of these before it can be frozen. Spike
# Revision 3 asked for a non-Claude model run by the owner; the owner
# deferred that pass (2026-10-25) and a different Claude model (Sonnet)
# reviews instead. OPTIONAL reviewers can still be merged, and any reject
# from them still wins.
REVIEWERS = ("claude-a", "claude-b", "sonnet")
OPTIONAL = ("owner-model",)

REASONS = {"abstract", "conversational", "alarming", "verify", "political", "vulgar", "name",
           "reading", "regional", "rare", "confusable", "other"}

# Known-bad rows mixed into every batch to check each reviewer. None of them
# can be a candidate (the generator's gates already exclude them).
SEEDS = ["骗子", "谢谢", "配合", "完了", "死亡", "小偷", "妈妈", "没有", "觉得", "混蛋",
         "警察", "转账", "抢劫", "毒品", "尸体", "欠债", "癌症", "监狱", "政府", "宗教"]
COLS = ["simplified", "tw", "pinyin", "zhuyin", "concreteness", "cd", "flags"]


def read_tsv(path: Path) -> list:
    with path.open(encoding="utf-8") as f:
        return [r for r in csv.DictReader(f, delimiter="\t")]


def decided() -> dict:
    """(reviewer, word) -> (decision, reason, note)."""
    if not DECISIONS.exists():
        return {}
    return {(r["reviewer"], r["word"]): (r["decision"], r["reason"], r["note"])
            for r in read_tsv(DECISIONS)}


_SOURCES = {}


def seed_row(word: str) -> dict:
    """A seed filled in from the same sources as real rows, so nothing but
    the word itself gives it away."""
    import opencc
    from pypinyin import Style, lazy_pinyin

    import data

    if not _SOURCES:
        _SOURCES.update(sub=data.load_subtlex(), conc=data.load_concreteness(),
                        chewing=data.load_chewing())
    tw = opencc.OpenCC("s2tw").convert(word)
    zhuyin = sorted(_SOURCES["chewing"].get(tw, ({""}, 0))[0])[0]
    return {"simplified": word, "tw": tw,
            "pinyin": " ".join(lazy_pinyin(word, style=Style.TONE)), "zhuyin": zhuyin,
            "concreteness": _SOURCES["conc"].get(word, ""),
            "cd": _SOURCES["sub"].get(word, (0, ""))[1], "flags": ""}


def batches(reviewer: str, top: int, size: int) -> None:
    all_cands = read_tsv(HERE / "out" / "candidates.tsv")
    bad_seeds = {c["simplified"] for c in all_cands} & set(SEEDS)
    if bad_seeds:
        sys.exit(f"seeds that are candidates (pick others): {sorted(bad_seeds)}")
    cands = all_cands[:top]
    done = decided()
    # Words already sent to this reviewer in an earlier round, answered or
    # not, are not sent again (an owner-run reviewer may still be working).
    sent = {r["simplified"] for f in (OUT / reviewer).glob("round-*/batch-*.tsv")
            if ".answer" not in f.name and ".merged" not in f.name for r in read_tsv(f)}
    todo = [c for c in cands if (reviewer, c["simplified"]) not in done and c["simplified"] not in sent]
    rounds = sorted(int(p.name.split("-")[1]) for p in (OUT / reviewer).glob("round-*")) if (OUT / reviewer).exists() else []
    folder = OUT / reviewer / f"round-{(rounds[-1] + 1) if rounds else 1}"
    folder.mkdir(parents=True)
    rng = random.Random(f"{reviewer}-{len(done)}")
    n = 0
    for n, start in enumerate(range(0, len(todo), size), 1):
        rows = todo[start:start + size]
        for seed in rng.sample(SEEDS, 3):
            rows.insert(rng.randrange(len(rows) + 1), seed_row(seed))
        with (folder / f"batch-{n:02d}.tsv").open("w", encoding="utf-8", newline="") as f:
            w = csv.DictWriter(f, COLS, delimiter="\t", lineterminator="\n", extrasaction="ignore")
            w.writeheader()
            w.writerows(rows)
    print(f"{reviewer}: {len(todo)} words to review in {n} batches under {folder}")


def merge() -> int:
    done = decided()
    new, problems = [], []
    seed_hits, seed_total = {}, {}
    answers = sorted(OUT.glob("*/round-*/batch-*.answer.tsv"))
    for answer in answers:
        reviewer = answer.parent.parent.name
        if reviewer not in REVIEWERS + OPTIONAL:
            problems.append(f"{answer}: unknown reviewer {reviewer}")
            continue
        asked = [r["simplified"] for r in read_tsv(answer.with_name(answer.name.replace(".answer", "")))]
        got = {}
        for r in read_tsv(answer):
            word, decision = (r.get("word") or "").strip(), (r.get("decision") or "").strip()
            reason = (r.get("reason") or "").strip()
            if decision not in ("keep", "reject") or (decision == "reject" and reason not in REASONS):
                problems.append(f"{answer}: bad row {r}")
                continue
            got[word] = (decision, reason, (r.get("note") or "").strip())
        missing = [w for w in asked if w not in got]
        if missing:
            problems.append(f"{answer}: {len(missing)} rows missing, e.g. {missing[:5]}")
            continue
        for w in asked:
            if w in SEEDS:
                seed_total[reviewer] = seed_total.get(reviewer, 0) + 1
                seed_hits[reviewer] = seed_hits.get(reviewer, 0) + (got[w][0] == "reject")
            elif (reviewer, w) not in done:
                done[(reviewer, w)] = got[w]
                new.append((reviewer, w) + got[w])
    for reviewer in sorted(seed_total):
        recall = seed_hits[reviewer] / seed_total[reviewer]
        print(f"{reviewer}: seed recall {seed_hits[reviewer]}/{seed_total[reviewer]} ({recall:.0%})")
        if recall < 0.9:
            problems.append(f"{reviewer}: seed recall under 90%; do not trust this reviewer's keeps")
    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 1

    DECISIONS.parent.mkdir(exist_ok=True)
    rows = sorted(((r, w) + v for (r, w), v in done.items()), key=lambda x: (x[1], x[0]))
    with DECISIONS.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t", lineterminator="\n")
        w.writerow(["reviewer", "word", "decision", "reason", "note"])
        w.writerows(rows)
    denied = {r[0] for r in csv.reader(DENYLIST.open(encoding="utf-8"), delimiter="\t") if r}
    with DENYLIST.open("a", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t", lineterminator="\n")
        for reviewer, word, decision, reason, note in new:
            if decision == "reject" and word not in denied:
                w.writerow([word, reviewer, reason, note])
                denied.add(word)
    for answer in answers:
        answer.rename(answer.with_name(answer.name.replace(".answer.tsv", ".merged.tsv")))
    rejects = sum(1 for x in new if x[2] == "reject")
    print(f"merged {len(new)} new decisions ({rejects} rejects); rerun generate.py")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("batches")
    b.add_argument("reviewer", choices=REVIEWERS + OPTIONAL)
    b.add_argument("--top", type=int, default=2560)
    b.add_argument("--size", type=int, default=320)
    sub.add_parser("merge")
    args = ap.parse_args()
    if args.cmd == "batches":
        batches(args.reviewer, args.top, args.size)
        return 0
    return merge()


if __name__ == "__main__":
    sys.exit(main())
